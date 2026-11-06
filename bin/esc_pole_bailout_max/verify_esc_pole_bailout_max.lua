-- Behaviour check for issue #2657: Motor Pole Count and the Scorpion Bailout Time offer only
-- values their wire field can carry.
--
-- Run it:
--     lua5.4 bin/esc_pole_bailout_max/verify_esc_pole_bailout_max.lua
--
-- What it drives, and why:
--   * The real app/field_layout.lua builds each number field from the real codec module
--     (lib/msp_motor_config.lua, lib/msp_esc_parameters_scorpion.lua), as the motor and
--     Scorpion pages do. form.addNumberField is a stub that records the range in the units
--     the pilot sees (Bailout in whole seconds, scale 1000).
--   * Every value at the edge of that range is turned back into the stored unit the way the
--     field's setter does (field_layout numberSet: value * scale), written through the
--     module's encode() and read back through decode(). A value that changes on the way is
--     one the wire cannot carry. The write payload is read at the field's own offset: motor_poles is a U8 (rotorflight-firmware settings.c), and
--     the Scorpion bailout a u16 count of milliseconds.
--   * Against unpatched master the pole count reaches 256 (written as 0) and the bailout
--     reaches 100 s (wraps to 34.5 s); with a cap of 65535 ms the editor still offers 66 s,
--     which wraps to 0.46 s.

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

-- A full field table as the FC sends it: the module's own simulator reply, through its own reader.
local function fixture(mspModule)
  local data
  local message = mspModule.buildReadMessage(function(d) data = d end, function() end)
  local reply = {}
  for i, b in ipairs(message.simulatorResponse) do reply[i] = b end
  message.processReply(nil, reply)
  return data
end

local function payloadFor(mspModule, key, stored)
  local data = fixture(mspModule)
  data[key] = stored
  return mspModule.buildWriteMessage(data).payload
end

-- Where the field sits in the write payload: the first byte that differs between 0 and 1.
local function offsetOf(mspModule, key)
  local a, b = payloadFor(mspModule, key, 0), payloadFor(mspModule, key, 1)
  for i = 1, math.max(#a, #b) do
    if a[i] ~= b[i] then return i end
  end
end

-- A value as the pilot enters it, stored as the setter stores it (field_layout numberSet),
-- and the value the write payload carries for it (little-endian, `width` bytes).
local function roundTrip(mspModule, key, shown, width)
  local meta = mspModule.FIELD_META[key]
  local stored = math.floor(shown * (meta.scale or 1) + 0.5)
  local at = offsetOf(mspModule, key)
  local payload = payloadFor(mspModule, key, stored)
  local value = 0
  for i = width, 1, -1 do value = value * 256 + (payload[at + i - 1] or 0) end
  return stored, value
end

local function checkField(name, mspModule, key, wantMax, width)
  local range, err = editorRange(mspModule, key)
  check(name .. ": the editor offers a field", range ~= nil, err)
  if not range then return end
  check(string.format("%s: editor maximum is %d", name, wantMax), range.max == wantMax,
    "offered " .. tostring(range.max))
  for _, shown in ipairs({range.min, range.max}) do
    local stored, back = roundTrip(mspModule, key, shown, width)
    check(string.format("%s: %s as entered reaches the wire unchanged", name, tostring(shown)),
      back == stored, string.format("stored %s, read back %s", tostring(stored), tostring(back)))
  end
end

checkField("motor pole count", requireModule("lib/msp_motor_config.lua"), "motor_pole_count_0", 255, 1)
checkField("scorpion bailout (s)", requireModule("lib/msp_esc_parameters_scorpion.lua"), "bailout", 65, 2)

if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end
print(string.format("\n%d checks passed", checks))
