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
}

local model_preferences = {}

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

local function normalize(prefs)
  prefs.general = prefs.general or {}
  prefs.general.flightcount = clampNumber(prefs.general.flightcount, DEFAULTS.general.flightcount, 0, 1000000000)
  prefs.general.lastflighttime = clampNumber(prefs.general.lastflighttime, DEFAULTS.general.lastflighttime, 0, 1000000000)
  prefs.general.totalflighttime = clampNumber(prefs.general.totalflighttime, DEFAULTS.general.totalflighttime, 0, 1000000000)
  prefs.general.batterylocalcalculation = clampNumber(prefs.general.batterylocalcalculation, DEFAULTS.general.batterylocalcalculation, 0, 1)

  prefs.battery = prefs.battery or {}
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
  local prefs = model_preferences.withDefaults(existing)
  if not ini.ini_tables_equal(existing, DEFAULTS) then
    ini.save_ini_file(path, prefs)
  end
  return prefs, path
end

function model_preferences.save(path, prefs)
  safeMkdir(ROOT_DIR)
  safeMkdir(MODELS_DIR)
  return ini.save_ini_file(path, model_preferences.withDefaults(prefs))
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
