-- Behaviour check for issue #2656: the editor ranges of the inflight error decay limit and
-- of the governor throttle limits follow the firmware.
--
-- Run it:
--     lua5.4 bin/pid_governor_ranges/verify_pid_governor_ranges.lua
--
-- What it drives, and why:
--   * The real app/field_layout.lua builds each number field from the real codec module
--     (lib/msp_pid_profile.lua, lib/msp_governor_profile.lua), exactly as the PID and
--     governor pages do. form.addNumberField is a stub that records the min and max the
--     page would offer, so the check reads what a pilot can enter, not a source line.
--   * The firmware ranges (rotorflight-firmware src/main/cli/settings.c):
--       error_decay_limit_cyclic  0..250  (UINT8)
--       gov_max_throttle          10..100
--       gov_min_throttle          10..100
--   * Each bound is also written through the module's own encode() and read back through
--     its decode(), so the value the editor allows reaches the FC unchanged.
--   * Against unpatched master the error decay limit stops at 25 and both throttle limits
--     start at 0, and the range checks fail.

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
-- Stubs: the form records the range of every number field it is asked for.
-- ---------------------------------------------------------------------------

lcd = anything()
system = anything()
local offered = nil
form = anything()
form.addNumberField = function(_, _, min, max)
  offered = {min = min, max = max}
  return anything()
end

local fieldLayout = requireModule("app/field_layout.lua")

-- The range the editor offers for one key of one codec module.
local function editorRange(mspModule, key)
  offered = nil
  local runtime = {
    sources = {{key = "default", mspModule = mspModule}},
    dataRef = {}, controlRef = {},
    registerField = function() end,
  }
  local ok, err = pcall(fieldLayout.buildField, runtime, anything(), nil, {key = key})
  if not ok then return nil, err end
  return offered
end

-- A full field table as the FC sends it: the module's own simulator reply, decoded.
local function fixture(mspModule)
  local message = mspModule.buildReadMessage(function() end, function() end)
  return mspModule.decode(message.simulatorResponse)
end

local function roundTrip(mspModule, key, value)
  local data = fixture(mspModule)
  data[key] = value
  local back = mspModule.decode(mspModule.encode(data))
  return back and back[key]
end

local function checkField(name, mspModule, key, wantMin, wantMax)
  local range, err = editorRange(mspModule, key)
  check(name .. ": the editor offers a field", range ~= nil, err)
  if not range then return end
  check(string.format("%s: editor minimum is %d", name, wantMin), range.min == wantMin,
    "offered " .. tostring(range.min))
  check(string.format("%s: editor maximum is %d", name, wantMax), range.max == wantMax,
    "offered " .. tostring(range.max))
  for _, bound in ipairs({range.min, range.max}) do
    local back = roundTrip(mspModule, key, bound)
    check(string.format("%s: %s reaches the FC unchanged", name, tostring(bound)), back == bound,
      "read back " .. tostring(back))
  end
end

local pid = requireModule("lib/msp_pid_profile.lua")
local gov = requireModule("lib/msp_governor_profile.lua")

checkField("error_decay_limit_cyclic", pid, "error_decay_limit_cyclic", 0, 250)
checkField("governor_max_throttle", gov, "governor_max_throttle", 10, 100)
checkField("governor_min_throttle", gov, "governor_min_throttle", 10, 100)

if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end
print(string.format("\n%d checks passed", checks))
