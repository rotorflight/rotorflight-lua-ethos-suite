-- Tiny file-backed settings helper for Lite-only preferences.
--
-- Self-cache the helper table so repeated loadfile() calls do not duplicate
-- defaults and parser helpers. Callers still load/save their own snapshots.

if package.loaded["rfsuite.lib.settings_store"] then
  return package.loaded["rfsuite.lib.settings_store"]
end

local ini = assert(loadfile("lib/ini.lua"))()
local activelookConfig = assert(loadfile("lib/activelook_config.lua"))()

local SETTINGS_DIR = "SCRIPTS:/rfsuite.user"
local SETTINGS_PATH = SETTINGS_DIR .. "/settings.ini"

local DEFAULTS = {
  general = {
    telemetry_logging = true,
    log_sample_interval = 1,
    txbatt_type = 0,
  },
  developer = {
    developer_mode = false,
    debug_logs = false,
    log_msp = false,
    memory_logs = false,
  },
  events = {
    armflags = true,
    governor = true,
    voltage = true,
    voltage_repeat_interval = 10,
    pid_profile = true,
    rate_profile = true,
    battery_profile = true,
    smartfuel = true,
    smartfuelcallout = 0,
    smartfuelrepeats = 1,
    smartfuelhaptic = false,
    temp_esc = false,
    escalertvalue = 90,
    bec_voltage = false,
    becalertvalue = 6.5,
    rx_voltage = false,
    rxalertvalue = 7.4,
    adj_f = false,
    adj_v = false,
  },
  timer = {
    timeraudioenable = false,
    elapsedalertmode = 0,
    prealerton = false,
    postalerton = false,
    prealertinterval = 10,
    prealertperiod = 30,
    postalertinterval = 10,
    postalertperiod = 30,
  },
  dashboard = {
    theme = "default",
    use_same_theme = true,
    theme_preflight = "system/default",
    theme_inflight = "system/default",
    theme_postflight = "system/default",
  },
  activelook = activelookConfig.DEFAULTS,
}

local DASHBOARD_THEMES = {
  ["aerc-n"] = true,
  aerc = true,
  claude = true,
  danielrc = true,
  default = true,
  gismo = true,
  helihud_aon_v8 = true,
  kevd = true,
  rfstatus = true,
  ["rt-rc-n"] = true,
  ["rt-rc"] = true,
  ["srb-rc"] = true,
  timer = true,
}

local function normalizeDashboardTheme(value, allowDisabled, default)
  if allowDisabled and (value == nil or value == "" or value == "nil" or value == 0 or value == "0") then
    return "nil"
  end

  if type(value) ~= "string" then value = default end
  value = tostring(value or "")
  if value == "" or value == "nil" then value = default end

  local source, folder = value:match("^([^/]+)/(.+)$")
  if source == "system" then
    if type(folder) == "string" and folder:sub(1, 1) == "@" then folder = folder:sub(2) end
    if DASHBOARD_THEMES[folder] then return "system/" .. folder end
  elseif DASHBOARD_THEMES[value] then
    return "system/" .. value
  end

  return default
end

local function dashboardThemeKey(value)
  if type(value) ~= "string" then return DEFAULTS.dashboard.theme end
  local folder = value:match("^system/(.+)$") or value
  if folder:sub(1, 1) == "@" then folder = folder:sub(2) end
  if DASHBOARD_THEMES[folder] then return folder end
  return DEFAULTS.dashboard.theme
end

local settings_store = {
  PATH = SETTINGS_PATH,
}

local function safeMkdir(path)
  if os and os.mkdir then pcall(os.mkdir, path) end
end

local function copySection(source)
  local target = {}
  if type(source) ~= "table" then return target end
  for key, value in pairs(source or {}) do
    target[key] = value
  end
  return target
end

local function copySettings(source)
  local target = {}
  if type(source) ~= "table" then return target end
  for section, values in pairs(source or {}) do
    target[section] = copySection(values)
  end
  return target
end

local function coerceBool(value, default)
  if value == nil then return default end
  if value == true or value == "true" or value == 1 or value == "1" then return true end
  if value == false or value == "false" or value == 0 or value == "0" then return false end
  return default
end

local function clampNumber(value, default, min, max)
  value = tonumber(value)
  if not value then value = default end
  if value < min then value = min end
  if value > max then value = max end
  return value
end

local function normalizeEvents(values)
  local events = copySection(DEFAULTS.events)
  values = type(values) == "table" and values or {}
  for key, value in pairs(values) do events[key] = value end
  events.armflags = coerceBool(events.armflags, DEFAULTS.events.armflags)
  events.governor = coerceBool(events.governor, DEFAULTS.events.governor)
  events.voltage = coerceBool(events.voltage, DEFAULTS.events.voltage)
  events.voltage_repeat_interval = clampNumber(events.voltage_repeat_interval, DEFAULTS.events.voltage_repeat_interval, 5, 120)
  events.pid_profile = coerceBool(events.pid_profile, DEFAULTS.events.pid_profile)
  events.rate_profile = coerceBool(events.rate_profile, DEFAULTS.events.rate_profile)
  events.battery_profile = coerceBool(events.battery_profile, DEFAULTS.events.battery_profile)
  events.smartfuel = coerceBool(events.smartfuel, DEFAULTS.events.smartfuel)
  events.smartfuelcallout = clampNumber(events.smartfuelcallout, DEFAULTS.events.smartfuelcallout, 0, 50)
  events.smartfuelrepeats = clampNumber(events.smartfuelrepeats, DEFAULTS.events.smartfuelrepeats, 1, 10)
  events.smartfuelhaptic = coerceBool(events.smartfuelhaptic, DEFAULTS.events.smartfuelhaptic)
  events.temp_esc = coerceBool(events.temp_esc, DEFAULTS.events.temp_esc)
  events.escalertvalue = clampNumber(events.escalertvalue, DEFAULTS.events.escalertvalue, 60, 300)
  events.bec_voltage = coerceBool(events.bec_voltage, DEFAULTS.events.bec_voltage)
  events.becalertvalue = clampNumber(events.becalertvalue, DEFAULTS.events.becalertvalue, 3.0, 15.0)
  events.rx_voltage = coerceBool(events.rx_voltage, DEFAULTS.events.rx_voltage)
  events.rxalertvalue = clampNumber(events.rxalertvalue, DEFAULTS.events.rxalertvalue, 3.0, 15.0)
  events.adj_f = coerceBool(events.adj_f, DEFAULTS.events.adj_f)
  events.adj_v = coerceBool(events.adj_v, DEFAULTS.events.adj_v)
  return events
end

local function normalizeTimer(values)
  local timer = copySection(DEFAULTS.timer)
  values = type(values) == "table" and values or {}
  for key, value in pairs(values) do timer[key] = value end
  timer.timeraudioenable = coerceBool(timer.timeraudioenable, DEFAULTS.timer.timeraudioenable)
  timer.elapsedalertmode = clampNumber(timer.elapsedalertmode, DEFAULTS.timer.elapsedalertmode, 0, 3)
  timer.prealerton = coerceBool(timer.prealerton, DEFAULTS.timer.prealerton)
  timer.postalerton = coerceBool(timer.postalerton, DEFAULTS.timer.postalerton)
  timer.prealertinterval = clampNumber(timer.prealertinterval, DEFAULTS.timer.prealertinterval, 10, 30)
  timer.prealertperiod = clampNumber(timer.prealertperiod, DEFAULTS.timer.prealertperiod, 30, 90)
  timer.postalertinterval = clampNumber(timer.postalertinterval, DEFAULTS.timer.postalertinterval, 10, 30)
  timer.postalertperiod = clampNumber(timer.postalertperiod, DEFAULTS.timer.postalertperiod, 30, 90)
  return timer
end

local function normalize(settings)
  settings.general = settings.general or {}
  settings.general.telemetry_logging = coerceBool(settings.general.telemetry_logging, DEFAULTS.general.telemetry_logging)
  settings.general.log_sample_interval = clampNumber(settings.general.log_sample_interval, DEFAULTS.general.log_sample_interval, 1, 10)
  settings.general.txbatt_type = clampNumber(settings.general.txbatt_type, DEFAULTS.general.txbatt_type, 0, 2)

  settings.developer = settings.developer or {}
  settings.developer.developer_mode = coerceBool(settings.developer.developer_mode, DEFAULTS.developer.developer_mode)
  settings.developer.debug_logs = coerceBool(settings.developer.debug_logs, DEFAULTS.developer.debug_logs)
  settings.developer.log_msp = coerceBool(settings.developer.log_msp, DEFAULTS.developer.log_msp)
  settings.developer.memory_logs = coerceBool(settings.developer.memory_logs, DEFAULTS.developer.memory_logs)

  settings.events = normalizeEvents(settings.events)
  settings.timer = normalizeTimer(settings.timer)

  settings.dashboard = settings.dashboard or {}
  local defaultTheme = normalizeDashboardTheme(settings.dashboard.theme_preflight or settings.dashboard.theme, false, DEFAULTS.dashboard.theme_preflight)
  settings.dashboard.use_same_theme = coerceBool(settings.dashboard.use_same_theme, DEFAULTS.dashboard.use_same_theme)
  settings.dashboard.theme_preflight = normalizeDashboardTheme(settings.dashboard.theme_preflight or settings.dashboard.theme, false, defaultTheme)
  settings.dashboard.theme_inflight = normalizeDashboardTheme(settings.dashboard.theme_inflight or settings.dashboard.theme_preflight or settings.dashboard.theme, false, settings.dashboard.theme_preflight)
  settings.dashboard.theme_postflight = normalizeDashboardTheme(settings.dashboard.theme_postflight or settings.dashboard.theme_preflight or settings.dashboard.theme, false, settings.dashboard.theme_preflight)
  if settings.dashboard.use_same_theme then
    settings.dashboard.theme_inflight = settings.dashboard.theme_preflight
    settings.dashboard.theme_postflight = settings.dashboard.theme_preflight
  end
  settings.dashboard.theme = dashboardThemeKey(settings.dashboard.theme_preflight)

  settings.activelook = activelookConfig.withDefaults(settings.activelook)
  return settings
end

function settings_store.withDefaults(settings)
  local merged = copySettings(DEFAULTS)
  settings = settings or {}
  for section, values in pairs(settings) do
    merged[section] = merged[section] or {}
    if type(values) == "table" then
      for key, value in pairs(values) do
        merged[section][key] = value
      end
    end
  end
  return normalize(merged)
end

function settings_store.load()
  safeMkdir(SETTINGS_DIR)
  return settings_store.withDefaults(ini.load_ini_file(SETTINGS_PATH) or {})
end

function settings_store.save(settings)
  safeMkdir(SETTINGS_DIR)
  return ini.save_ini_file(SETTINGS_PATH, settings_store.withDefaults(settings))
end

function settings_store.clone(settings)
  return copySettings(settings_store.withDefaults(settings))
end

function settings_store.same(a, b)
  a = settings_store.withDefaults(a)
  b = settings_store.withDefaults(b)
  for section, values in pairs(a) do
    for key, value in pairs(values) do
      if not b[section] or b[section][key] ~= value then return false end
    end
  end
  for section, values in pairs(b) do
    for key in pairs(values) do
      if not a[section] or a[section][key] == nil then return false end
    end
  end
  return true
end

function settings_store.loggingEnabled(settings)
  return true
end

function settings_store.loggingSampleInterval(settings)
  local general = type(settings) == "table" and settings.general or nil
  local value = type(general) == "table" and general.log_sample_interval or nil
  return clampNumber(value, DEFAULTS.general.log_sample_interval, 1, 10)
end

function settings_store.developerModeEnabled(settings)
  local developer = type(settings) == "table" and settings.developer or nil
  local value = type(developer) == "table" and developer.developer_mode or nil
  return coerceBool(value, DEFAULTS.developer.developer_mode) == true
end

function settings_store.debugLogsEnabled(settings)
  local developer = type(settings) == "table" and settings.developer or nil
  local value = type(developer) == "table" and developer.debug_logs or nil
  return coerceBool(value, DEFAULTS.developer.debug_logs) == true
end

function settings_store.mspLogsEnabled(settings)
  local developer = type(settings) == "table" and settings.developer or nil
  local value = type(developer) == "table" and developer.log_msp or nil
  return coerceBool(value, DEFAULTS.developer.log_msp) == true
end

function settings_store.memoryLogsEnabled(settings)
  local developer = type(settings) == "table" and settings.developer or nil
  local value = type(developer) == "table" and developer.memory_logs or nil
  return coerceBool(value, DEFAULTS.developer.memory_logs) == true
end

function settings_store.audioEvents(settings)
  return normalizeEvents(type(settings) == "table" and settings.events or nil)
end

function settings_store.audioTimer(settings)
  return normalizeTimer(type(settings) == "table" and settings.timer or nil)
end

function settings_store.audioSwitches(settings)
  -- The switches section has no defaults to merge. Keep this cheap because the
  -- background audio-switch task calls it from a tight Ethos scheduler slice.
  return copySection(type(settings) == "table" and settings.switches or nil)
end

function settings_store.dashboard(settings)
  settings = settings_store.withDefaults(settings)
  return copySection(settings.dashboard)
end

function settings_store.dashboardTheme(settings, theme)
  settings = settings_store.withDefaults(settings)
  return copySection(settings["dashboard." .. tostring(theme or "")])
end

function settings_store.setDashboardTheme(settings, theme, values)
  if type(settings) ~= "table" then return end
  local section = "dashboard." .. tostring(theme or "")
  settings[section] = copySection(values)
end

function settings_store.activelook(settings)
  settings = settings_store.withDefaults(settings)
  return copySection(settings.activelook)
end

package.loaded["rfsuite.lib.settings_store"] = settings_store
return settings_store
