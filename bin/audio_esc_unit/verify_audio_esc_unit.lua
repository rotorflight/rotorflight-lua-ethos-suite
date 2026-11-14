-- Behaviour check for the ESC temperature threshold page (#2662): on a radio set to
-- Fahrenheit the threshold is shown and typed in Fahrenheit, with a °F suffix, while
-- the value is stored in Celsius, which is what the audio task compares against.
--
-- Run it:
--     lua5.4 bin/audio_esc_unit/verify_audio_esc_unit.lua
--     lua5.4 bin/audio_esc_unit/verify_audio_esc_unit.lua --self-test
--
-- Drives the real app/pages/settings_audio_events_esc.lua and its shared helper
-- app/pages/settings_audio_events_common.lua. Only the form widgets, the header and
-- the settings store are stubbed; the stub store records what the page writes.
--
-- Against the unpatched page the Fahrenheit checks fail: it shows 60 to 300 "deg".

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SRC = ROOT .. "/src/rfsuite"
local PAGE_PATH = SRC .. "/app/pages/settings_audio_events_esc.lua"

local checks, failures = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then failures = failures + 1 end
  print(string.format("  %s  %s%s", ok and "ok  " or "FAIL", label, (not ok and detail) and ("  (" .. detail .. ")") or ""))
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local data = f:read("*a")
  f:close()
  return data
end

-- ---------------------------------------------------------------------------
-- Stubs. The settings store is one table per scenario, and the page works on it.
-- ---------------------------------------------------------------------------
local store
local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

local stubs = {
  ["lib/bus.lua"] = {publish = function() end, subscribe = function() end},
  ["app/close_key.lua"] = {shouldHandleClose = function() return false end},
  ["app/header.lua"] = {build = function() return {setSaveEnabled = function() end, focusSave = function() end} end},
  ["app/settings_save.lua"] = {},
  ["app/leave_confirm.lua"] = {args = function(a) return a end},
  ["lib/settings_store.lua"] = {
    load = function() return store end,
    save = function() return true end,
    clone = function(t) return deepcopy(t) end,
    same = function() return false end,
    temperatureUnit = function(settings) return settings.general.temperature_unit end,
  },
}

local cache = {}
package.loaded["rfsuite.lib.require"] = function(name)
  if stubs[name] then return stubs[name] end
  if cache[name] == nil then
    cache[name] = assert(loadfile(SRC .. "/" .. name))()
  end
  return cache[name]
end

-- The form: each number field is recorded, with its range, reads and writes.
local numberFields
form = {
  clear = function() end,
  addLine = function(label) return {label = label} end,
  addNumberField = function(_, _, minimum, maximum, getter, setter)
    local field = {min = minimum, max = maximum, get = getter, set = setter}
    function field:suffix(text) self.suffixText = text end
    function field:decimals(n) self.decimalsValue = n end
    function field:enable(on) self.enabled = on end
    numberFields[#numberFields + 1] = field
    return field
  end,
  addBooleanField = function(_, _, getter, setter)
    return {get = getter, set = setter, enable = function() end}
  end,
  openDialog = function() end,
}

-- Opens the page on a store with the given unit and threshold, and returns the threshold
-- field, which the page creates first among its number fields.
local function openPage(unit, storedThreshold, source)
  store = {
    general = {temperature_unit = unit},
    events = {escalertvalue = storedThreshold, temp_esc = true, temp_esc_repeats = 0, temp_esc_haptic = true},
  }
  numberFields = {}
  local page = source and (assert(load(source, "@" .. PAGE_PATH))()) or dofile(PAGE_PATH)
  page.open({})
  return numberFields[1]
end

-- ---------------------------------------------------------------------------
-- Fahrenheit: shown and typed in °F, stored in °C.
-- ---------------------------------------------------------------------------
print("Fahrenheit radio")
do
  local field = openPage(1, 90)
  check("the threshold is shown with a °F suffix", field and field.suffixText == "°F",
    "suffix=" .. tostring(field and field.suffixText))
  check("the range is 140 to 572 °F (60 to 300 °C)", field and field.min == 140 and field.max == 572,
    "range=" .. tostring(field and field.min) .. ".." .. tostring(field and field.max))
  check("the stored 90 °C is shown as 194 °F", field and field.get() == 194,
    "shown=" .. tostring(field and field.get()))

  field.set(212)
  check("typing 212 °F stores 100 °C", math.abs(store.events.escalertvalue - 100) < 1e-9,
    "stored=" .. tostring(store.events.escalertvalue))
  check("and reads back as 212 °F", field.get() == 212, "shown=" .. tostring(field.get()))

  field.set(195)
  check("a value typed in °F reads back as typed (195 °F)", field.get() == 195,
    "shown=" .. tostring(field.get()))
  check("and is stored unrounded (about 90.56 °C)", math.abs(store.events.escalertvalue - (195 - 32) / 1.8) < 1e-9,
    "stored=" .. tostring(store.events.escalertvalue))

  field.set(nil)
  check("a cleared field stores the default 90 °C", store.events.escalertvalue == 90,
    "stored=" .. tostring(store.events.escalertvalue))
end

-- ---------------------------------------------------------------------------
-- Celsius: unchanged.
-- ---------------------------------------------------------------------------
print("Celsius radio")
do
  local field = openPage(0, 90)
  check("the threshold is shown with a °C suffix", field and field.suffixText == "°C",
    "suffix=" .. tostring(field and field.suffixText))
  check("the range is 60 to 300 °C", field and field.min == 60 and field.max == 300,
    "range=" .. tostring(field and field.min) .. ".." .. tostring(field and field.max))
  check("the stored 90 °C is shown as 90", field and field.get() == 90, "shown=" .. tostring(field and field.get()))
  field.set(75)
  check("typing 75 stores 75 °C", store.events.escalertvalue == 75, "stored=" .. tostring(store.events.escalertvalue))
end

-- ---------------------------------------------------------------------------
-- self-test: without the conversion the Fahrenheit checks must go red.
-- ---------------------------------------------------------------------------
local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

if selfTest then
  print()
  print("--self-test: the Fahrenheit checks must go red without the conversion")
  local source = readFile(PAGE_PATH)
  local mutated, replacements = source:gsub("toShown = fahrenheit and celsiusToFahrenheit or nil,", "toShown = nil,", 1)
  check("self-test: the conversion was found in the page exactly once", replacements == 1,
    "replacements=" .. replacements)
  if replacements == 1 then
    local field = openPage(1, 90, mutated)
    check("self-test: without the conversion the page does not show 194 °F (the Fahrenheit check goes red)",
      field and field.get() ~= 194, "shown=" .. tostring(field and field.get()))
  end
end

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
