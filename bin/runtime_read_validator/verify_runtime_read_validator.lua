-- Behaviour check for Issue #2494: a single-source page refuses a reply it does not
-- know, on every read, not only on the first one.
--
-- Run it:
--     lua5.4 bin/runtime_read_validator/verify_runtime_read_validator.lua
--
-- What it drives: the real src/rfsuite/app/page_runtime.lua, through its own
-- loadData() path, which is the Reload path (the first read of a visit is the page's
-- own). The codec is a stub whose read reply the scenario chooses: a reply with another
-- ESC's signature, a reply with the page's signature, and a read error.
--
-- Against unpatched master the reply with another signature loads the page, which
-- then builds the editor from it; the checks for that go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  local last = 0
  for i = 1, #path do
    local ch = path:sub(i, i)
    if ch == "/" or ch == string.char(92) then last = i end
  end
  if last == 0 then return "." end
  return path:sub(1, last - 1)
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then path = resolvePath(path) end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local function anything()
  local t = {}
  return setmetatable(t, {
    __index = function() return function() return anything() end end,
    __call = function() return anything() end,
  })
end

-- ---------------------------------------------------------------------------
-- Stubs
-- ---------------------------------------------------------------------------

lcd = anything()
lcd.getWindowSize = function() return 800, 480 end
system = anything()
form = anything()
form.clear = function() end
form.invalidate = function() end
form.openDialog = function() end
package.loaded["rfsuite.lib.memstats"] = {print = function() end}
package.loaded["rfsuite.lib.debug_log"] = anything()

local bus = requireModule("lib/bus.lua")
local reads = {}
bus.subscribe("msp.request", function(m)
  if m.kind == "codecRead" then reads[#reads + 1] = m end
end)

local pageRuntime = requireModule("app/page_runtime.lua")

-- The codec: its read message is recorded, the scenario answers it.
local SIGNATURE = 194
local codec = {
  buildReadMessage = function(onData, onError)
    return {kind = "codecRead", onData = onData, onError = onError}
  end,
  buildWriteMessage = function() return {kind = "codecWrite"} end,
}

local function validateRead(values)
  if tonumber(values and values.esc_signature) == SIGNATURE then return true end
  return false, "signature " .. tostring(values and values.esc_signature) .. " is not " .. SIGNATURE
end

local function newRuntime()
  reads = {}
  local opts = {onBack = function() end, setWakeupHandler = function() end}
  return pageRuntime.new({
    pageTitle = "ESC test",
    logTag = "runtime_read_validator",
    mspModule = codec,
    validateRead = validateRead,
    opts = opts,
    profileField = "none",
  })
end

-- Starts a reload, answers the read the way the scenario says, and runs the UI tick.
local function reloadWith(runtime, answer)
  runtime:loadData(function() end)
  local m = reads[#reads]
  if not m then return false, "no read was published" end
  answer(m)
  runtime:runPendingUiActions()
  return true, nil
end

-- ---------------------------------------------------------------------------
-- Checks
-- ---------------------------------------------------------------------------

print("reload with another ESC's signature (83) is refused")
do
  local runtime = newRuntime()
  local ok, why = reloadWith(runtime, function(m) m.onData({esc_signature = 83}) end)
  check("the reload reads the device", ok, why)
  check("the page is not loaded", runtime.loaded ~= true,
    "loaded = " .. tostring(runtime.loaded))
  check("the reply does not become the page's data",
    runtime.data == nil or runtime.data.esc_signature == nil,
    "data carries signature " .. tostring(runtime.data and runtime.data.esc_signature))
  check("the load error is reported", runtime.pendingLoadError == true,
    "pendingLoadError = " .. tostring(runtime.pendingLoadError))
end

print("reload with the page's own signature (194) loads the page")
do
  local runtime = newRuntime()
  local ok, why = reloadWith(runtime, function(m) m.onData({esc_signature = 194}) end)
  check("the reload reads the device", ok, why)
  check("the page is loaded", runtime.loaded == true, "loaded = " .. tostring(runtime.loaded))
  check("the reply is the page's data", runtime.data ~= nil and runtime.data.esc_signature == 194)
end

print("a reload that fails to read is refused as before")
do
  local runtime = newRuntime()
  local ok, why = reloadWith(runtime, function(m) m.onError("read timed out") end)
  check("the reload reads the device", ok, why)
  check("the page is not loaded", runtime.loaded ~= true)
  check("the load error is reported", runtime.pendingLoadError == true)
end

-- The scenario the issue describes: a page that is already loaded and is being
-- reloaded. The two checks above all start from a fresh runtime, where "the page
-- is not loaded" is also true before anything happens; on a loaded page the
-- refusal leaves the previous data in place and only flips `loaded`, so what has
-- to be pinned is that the stale values cannot be written back.
print("a LOADED page reloaded with a foreign signature cannot save the old data")
do
  local runtime = newRuntime()
  local ok, why = reloadWith(runtime, function(m) m.onData({esc_signature = 194, motor = 7}) end)
  check("the page is loaded before the foreign reload", ok and runtime.loaded == true, why)
  local dataBefore = runtime.data

  ok, why = reloadWith(runtime, function(m) m.onData({esc_signature = 83, motor = 999}) end)
  check("the second reload reads the device", ok, why)
  check("the page is not loaded any more", runtime.loaded ~= true)
  check("the old data is left alone, not replaced",
    runtime.data == dataBefore, "the refused reply replaced the page's data")
  runtime:markDirty()
  check("a dirty page can no longer be saved", runtime:canSave() ~= true,
    "canSave() = " .. tostring(runtime:canSave()))
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
