-- Behaviour check for the Diagnostics pages that work without a flight controller (issue #2582).
--
-- Run it:
--     lua5.4 bin/diagnostics_offline/verify_diagnostics_offline.lua
--
-- The claim:
--   * Status and Info are openable with no FC connected (offline = true in the menu),
--     FBL Status is not.
--   * The Status page's API line is OK only on a live link whose MSP API version is
--     supported. Without a connection it is "-", never OK.
--
-- What it drives: the real src/rfsuite/app/tool.lua menu text (the offline flags, read
-- from source), and the real src/rfsuite/app/pages/diagnostics_rfstatus.lua, with a
-- recording form and a header stub. The Ethos colour globals are stubbed too.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
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
  if env ~= nil then return realLoadfile(path, mode, env) end
  if mode ~= nil then return realLoadfile(path, mode) end
  return realLoadfile(path)
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
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
  return ok
end

-- ---------------------------------------------------------------------------
-- 1. Menu: which Diagnostics entries open offline
-- ---------------------------------------------------------------------------
local toolSource = io.open(SUITE .. "/app/tool.lua", "r"):read("a")

local function entryLine(scriptName)
  for line in toolSource:gmatch("[^\n]+") do
    if line:find(scriptName, 1, true) then return line end
  end
  return nil
end

local function opensOffline(scriptName)
  local line = entryLine(scriptName)
  return line ~= nil and line:find("offline = true", 1, true) ~= nil
end

check("Status opens offline", opensOffline("app/pages/diagnostics_rfstatus.lua"))
check("Info opens offline", opensOffline("app/pages/diagnostics_info.lua"))
check("FBL Status stays FC-only", entryLine("app/pages/diagnostics_fblstatus.lua") ~= nil
  and not opensOffline("app/pages/diagnostics_fblstatus.lua"))
check("ELRS Telemetry stays FC-only", entryLine("app/pages/diagnostics_elrs_link.lua") ~= nil
  and not opensOffline("app/pages/diagnostics_elrs_link.lua"))

-- ---------------------------------------------------------------------------
-- 2. Status page: the API line
-- ---------------------------------------------------------------------------
GREEN = "green"
RED = "red"

local OK_TEXT = "@i18n(app.modules.rfstatus.ok)@"

local function recorder()
  return setmetatable({value_ = nil, color_ = nil}, {__index = {
    value = function(self, v) if v == nil then return self.value_ end self.value_ = v end,
    color = function(self, c) self.color_ = c end,
  }})
end

local created = {}
form = {
  clear = function() created = {} end,
  addLine = function(label) return {label = label} end,
  addStaticText = function()
    local f = recorder()
    created[#created + 1] = f
    return f
  end,
}
lcd = setmetatable({}, {__index = function() return function() end end})
system = {
  getMemoryUsage = function() return {mainStackAvailable = 4096, luaRamAvailable = 1000} end,
  getSource = function() return nil end,
}
model = {getModule = function() return nil end}

package.loaded["rfsuite.app.header"] = {build = function()
  return {focusReload = function() end, focusTool = function() end, setToolEnabled = function() end}
end}
package.loaded["rfsuite.app.close_key"] = {shouldHandleClose = function() return false end}

local page = requireModule("app/pages/diagnostics_rfstatus.lua")
local bus = requireModule("lib/bus.lua")
local opened = page.open({})

-- The API field is the one whose value is OK or "-". Fields are created in order:
-- memory, luaMemory, rfModule, mspSensor, connected, api.
local apiField = created[6]

local function publish(fields)
  local snapshot = {connected = false}
  for k, v in pairs(fields) do snapshot[k] = v end
  bus.publish("session.update", snapshot)
end

publish({connected = false, apiVersionSupported = nil})
check("no connection: the API line is not OK", apiField:value() == "-",
  "shows: " .. tostring(apiField:value()))
check("no connection: the API line is not green", apiField.color_ == RED)

publish({connected = true, apiVersionSupported = true})
check("connected, API supported: the API line is OK", apiField:value() == OK_TEXT,
  "shows: " .. tostring(apiField:value()))
check("connected, API supported: the API line is green", apiField.color_ == GREEN)

publish({connected = true, apiVersionSupported = false})
check("connected, API not supported: the API line is not OK", apiField:value() == "-",
  "shows: " .. tostring(apiField:value()))

publish({connected = false, apiVersionSupported = true})
check("link lost with a remembered API version: not OK", apiField:value() == "-",
  "shows: " .. tostring(apiField:value()))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
