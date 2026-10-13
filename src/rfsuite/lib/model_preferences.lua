-- Per-flight-controller model preferences stored on the radio.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ini = requireModule("lib/ini.lua")
local tableClone = requireModule("lib/table_clone.lua")

local ROOT_DIR = "SCRIPTS:/rfsuite.user"
local MODELS_DIR = ROOT_DIR .. "/models"

local DEFAULTS = {
  general = {
    flightcount = 0,
    lastflighttime = 0,
    totalflighttime = 0,
    batterylocalcalculation = 1,
  },
  battery = {
    smartfuel_model_type = 0,
    smartfuel_source = 0,
    stabilize_delay = 1500,
    stable_window = 15,
    voltage_fall_limit = 5,
    fuel_drop_rate = 10,
    sag_multiplier_percent = 70,
    sag_multiplier = 0.7,
    calc_local = 0,
    alert_type = 0,
    becalertvalue = 6.5,
    rxalertvalue = 7.5,
    flighttime = 300,
  },
  -- What the flight controller calls itself (MSP_NAME), kept next to its preferences so
  -- the radio can name a model with no link up (lib/known_models.lua). Empty until a
  -- connection has delivered both the UID and the name.
  craft = {
    name = "",
  },
}

local CRAFT_NAME_MAX = 32

local model_preferences = {}

model_preferences.MODELS_DIR = MODELS_DIR

local function safeMkdir(path)
  if os and os.mkdir then pcall(os.mkdir, path) end
end

local function sanitizeId(value)
  value = tostring(value or "unknown")
  value = value:gsub("[^%w%._%-]", "_")
  if value == "" then value = "unknown" end
  return value
end

local function clampNumber(value, default, min, max)
  value = tonumber(value)
  if not value then value = default end
  if value < min then value = min end
  if value > max then value = max end
  return math.floor(value + 0.5)
end

local function clampDecimal(value, default, min, max)
  value = tonumber(value)
  if not value then value = default end
  if value < min then value = min end
  if value > max then value = max end
  return math.floor((value * 10) + 0.5) / 10
end

-- Control characters out, ends trimmed, length capped. The firmware name is raw bytes.
local function cleanName(value)
  if value == nil then return "" end
  local name = tostring(value):gsub("[%c\127]", "")
  return (name:match("^%s*(.-)%s*$")):sub(1, CRAFT_NAME_MAX)
end

-- lib/ini.lua reads "007", "0x10" and "1e3" back as numbers and "true" as a boolean, so a
-- name written bare would not survive a round trip. On disk it sits inside quotes; in
-- memory it is the plain string, and only load()/save() cross that border.
local function unquoteName(raw)
  raw = tostring(raw or "")
  local inner = raw:match('^"(.*)"$')
  if inner ~= nil then return inner end
  return raw
end

local function toDisk(prefs)
  local disk = ini.merge_ini_tables(prefs, {})
  disk.craft.name = '"' .. disk.craft.name .. '"'
  return disk
end

local function normalize(prefs)
  prefs.craft = prefs.craft or {}
  prefs.craft.name = cleanName(prefs.craft.name)

  prefs.general = prefs.general or {}
  prefs.general.flightcount = clampNumber(prefs.general.flightcount, DEFAULTS.general.flightcount, 0, 1000000000)
  prefs.general.lastflighttime = clampNumber(prefs.general.lastflighttime, DEFAULTS.general.lastflighttime, 0, 1000000000)
  prefs.general.totalflighttime = clampNumber(prefs.general.totalflighttime, DEFAULTS.general.totalflighttime, 0, 1000000000)
  prefs.general.batterylocalcalculation = clampNumber(prefs.general.batterylocalcalculation, DEFAULTS.general.batterylocalcalculation, 0, 1)

  prefs.battery = prefs.battery or {}
  prefs.battery.smartfuel_model_type = clampNumber(prefs.battery.smartfuel_model_type, DEFAULTS.battery.smartfuel_model_type, 0, 2)
  prefs.battery.flighttime = clampNumber(prefs.battery.flighttime, DEFAULTS.battery.flighttime, 0, 3600)
  prefs.battery.alert_type = clampNumber(prefs.battery.alert_type, DEFAULTS.battery.alert_type, 0, 2)
  prefs.battery.becalertvalue = clampDecimal(prefs.battery.becalertvalue, DEFAULTS.battery.becalertvalue, 3.0, 14.0)
  prefs.battery.rxalertvalue = clampDecimal(prefs.battery.rxalertvalue, DEFAULTS.battery.rxalertvalue, 3.0, 14.0)
  return prefs
end

function model_preferences.pathFor(mcuId)
  return MODELS_DIR .. "/" .. sanitizeId(mcuId) .. ".ini"
end

function model_preferences.withDefaults(prefs)
  return normalize(ini.merge_ini_tables(prefs or {}, DEFAULTS))
end

function model_preferences.load(mcuId)
  safeMkdir(ROOT_DIR)
  safeMkdir(MODELS_DIR)

  local path = model_preferences.pathFor(mcuId)
  local existing = ini.load_ini_file(path) or {}
  if existing.craft and existing.craft.name ~= nil then
    existing.craft.name = unquoteName(existing.craft.name)
  end
  local prefs = model_preferences.withDefaults(existing)
  if not ini.ini_tables_equal(existing, DEFAULTS) then
    ini.save_ini_file(path, toDisk(prefs))
  end
  return prefs, path
end

function model_preferences.save(path, prefs)
  safeMkdir(ROOT_DIR)
  safeMkdir(MODELS_DIR)
  return ini.save_ini_file(path, toDisk(model_preferences.withDefaults(prefs)))
end

-- Record the name the flight controller reported. Returns the prefs and whether they
-- changed, so the caller writes only when it has to. An empty name never replaces a
-- stored one: a board that answered with nothing has not been renamed to nothing.
function model_preferences.setCraftName(prefs, name)
  prefs = model_preferences.withDefaults(prefs)
  name = cleanName(name)
  if name == "" or name == prefs.craft.name then return prefs, false end
  prefs.craft.name = name
  return prefs, true
end

-- The same name read out of a table lib/ini.lua returned for a store that is not loaded
-- (lib/known_models.lua), so the quoting stays in this file.
function model_preferences.craftNameOf(raw)
  local name = cleanName(unquoteName(raw and raw.craft and raw.craft.name))
  if name ~= "" then return name end
  return nil
end

function model_preferences.clone(prefs)
  return tableClone.nested(model_preferences.withDefaults(prefs))
end

function model_preferences.stats(prefs)
  prefs = model_preferences.withDefaults(prefs)
  return {
    flightcount = prefs.general.flightcount,
    lastflighttime = prefs.general.lastflighttime,
    totalflighttime = prefs.general.totalflighttime,
  }
end

function model_preferences.setStats(prefs, stats)
  prefs = model_preferences.withDefaults(prefs)
  stats = stats or {}
  prefs.general.flightcount = clampNumber(stats.flightcount, prefs.general.flightcount, 0, 1000000000)
  prefs.general.lastflighttime = clampNumber(stats.lastflighttime, prefs.general.lastflighttime, 0, 1000000000)
  prefs.general.totalflighttime = clampNumber(stats.totalflighttime, prefs.general.totalflighttime, 0, 1000000000)
  return prefs
end

function model_preferences.timerTarget(prefs)
  prefs = model_preferences.withDefaults(prefs)
  return clampNumber(prefs.battery.flighttime, DEFAULTS.battery.flighttime, 0, 3600)
end

function model_preferences.setTimerTarget(prefs, value)
  prefs = model_preferences.withDefaults(prefs)
  prefs.battery.flighttime = clampNumber(value, prefs.battery.flighttime, 0, 3600)
  return prefs
end

function model_preferences.smartfuelModelType(prefs)
  prefs = model_preferences.withDefaults(prefs)
  return clampNumber(prefs.battery.smartfuel_model_type, DEFAULTS.battery.smartfuel_model_type, 0, 2)
end

function model_preferences.setSmartfuelModelType(prefs, value)
  prefs = model_preferences.withDefaults(prefs)
  prefs.battery.smartfuel_model_type = clampNumber(value, prefs.battery.smartfuel_model_type, 0, 2)
  return prefs
end

function model_preferences.powerAlerts(prefs)
  prefs = model_preferences.withDefaults(prefs)
  return {
    flighttime = clampNumber(prefs.battery.flighttime, DEFAULTS.battery.flighttime, 0, 3600),
    alert_type = clampNumber(prefs.battery.alert_type, DEFAULTS.battery.alert_type, 0, 2),
    becalertvalue = clampDecimal(prefs.battery.becalertvalue, DEFAULTS.battery.becalertvalue, 3.0, 14.0),
    rxalertvalue = clampDecimal(prefs.battery.rxalertvalue, DEFAULTS.battery.rxalertvalue, 3.0, 14.0),
  }
end

function model_preferences.setPowerAlerts(prefs, alerts)
  prefs = model_preferences.withDefaults(prefs)
  alerts = alerts or {}
  prefs.battery.flighttime = clampNumber(alerts.flighttime, prefs.battery.flighttime, 0, 3600)
  prefs.battery.alert_type = clampNumber(alerts.alert_type, prefs.battery.alert_type, 0, 2)
  prefs.battery.becalertvalue = clampDecimal(alerts.becalertvalue, prefs.battery.becalertvalue, 3.0, 14.0)
  prefs.battery.rxalertvalue = clampDecimal(alerts.rxalertvalue, prefs.battery.rxalertvalue, 3.0, 14.0)
  return prefs
end

return model_preferences
