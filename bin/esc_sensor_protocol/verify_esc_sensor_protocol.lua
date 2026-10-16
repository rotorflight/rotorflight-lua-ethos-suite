-- Behaviour check for Issue #2492: the ESC telemetry protocol list follows the API
-- version the board reports. RECORD is 14 before API 12.10 and 15 from it, when SRXL2
-- takes 14 (rotorflight-firmware Changes.md, MSP Changes, API 12.10).
--
-- Run it:
--     lua5.4 bin/esc_sensor_protocol/verify_esc_sensor_protocol.lua
--
-- What it drives: the real src/rfsuite/lib/msp_esc_sensor_config.lua, and the real
-- app/pages/esc_motors_telemetry.lua with stub runtime and field layout, to pin that the page
-- hands the field the list for the version the runtime holds after buildChrome(). Against
-- unpatched master there is no API-dependent list, so the checks that need one go red.

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

local escSensorConfig = requireModule("lib/msp_esc_sensor_config.lua")

-- The list the page offers for an API minor. A module without the API-dependent list
-- (unpatched master) offers its one static list, whatever the version: that is the
-- defect these checks look for.
local function offered(apiMinor)
  if type(escSensorConfig.choicesFor) == "function" then
    return escSensorConfig.choicesFor(apiMinor)
  end
  return escSensorConfig.PROTOCOL_CHOICES
end

local function valueOf(list, name)
  if not list then return nil end
  for _, entry in ipairs(list) do
    if entry[1] == name then return entry[2] end
  end
  return nil
end

local function ascending(list)
  if not list then return false end
  for i = 2, #list do
    if list[i][2] <= list[i - 1][2] then return false end
  end
  return true
end

print("API 9 (before SRXL2): RECORD is 14, no SRXL2")
do
  local list = offered(9)
  check("RECORD is offered at 14", valueOf(list, "RECORD") == 14, "RECORD = " .. tostring(valueOf(list, "RECORD")))
  check("SRXL2 is not offered", valueOf(list, "SRXL2") == nil)
end

print("API 10 (SRXL2 at 14): SRXL2 is 14 and RECORD is 15")
do
  local list = offered(10)
  check("SRXL2 is offered at 14", valueOf(list, "SRXL2") == 14, "SRXL2 = " .. tostring(valueOf(list, "SRXL2")))
  check("RECORD is offered at 15, not 14", valueOf(list, "RECORD") == 15,
    "RECORD = " .. tostring(valueOf(list, "RECORD")))
  check("values are ascending", ascending(list))
end

print("no reported API version yet: the base list only")
do
  local list = offered(nil)
  check("no SRXL2 and no RECORD are offered", list ~= nil and valueOf(list, "SRXL2") == nil
    and valueOf(list, "RECORD") == nil)
  check("the base list is still there", valueOf(list, "FrSky F.BUS") == 13)
end

-- The page itself: it must hand the field the list for the version the runtime holds when
-- the field is built. The runtime stub copies the session snapshot in buildChrome(), the way
-- the real one does through the bus replay (app/page_runtime.lua, buildChrome()). A page that
-- built the field before buildChrome() would read nil and offer the base list on every
-- board, and a page that kept the static table would offer RECORD at 14 on API 10.
local function pageProtocolList(apiMinor)
  local seen = {}
  package.loaded["rfsuite.app.page_runtime"] = {
    new = function()
      local rt = {data = {}, fields = {}}
      function rt:buildChrome() self.apiVersionMinor = apiMinor end
      function rt:loadInitial() end
      return rt
    end,
  }
  package.loaded["rfsuite.app.field_layout"] = {
    buildSingle = function(_, _, spec)
      if spec.key == "protocol" then seen.choices = spec.choices end
    end,
  }
  form = {clear = function() end}
  local page = assert(loadfile("app/pages/esc_motors_telemetry.lua"))()
  page.open({})
  return seen.choices
end

print("the page builds the list for the version the runtime holds")
do
  local on9 = pageProtocolList(9)
  check("API 9: the page offers RECORD at 14 and no SRXL2", valueOf(on9, "RECORD") == 14
    and valueOf(on9, "SRXL2") == nil, "RECORD = " .. tostring(valueOf(on9, "RECORD")))
  local on10 = pageProtocolList(10)
  check("API 10: the page offers SRXL2 at 14 and RECORD at 15", valueOf(on10, "SRXL2") == 14
    and valueOf(on10, "RECORD") == 15, "SRXL2 = " .. tostring(valueOf(on10, "SRXL2"))
    .. ", RECORD = " .. tostring(valueOf(on10, "RECORD")))
  local onNil = pageProtocolList(nil)
  check("no version: the page offers the base list only", onNil ~= nil
    and valueOf(onNil, "SRXL2") == nil and valueOf(onNil, "RECORD") == nil)
end

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
