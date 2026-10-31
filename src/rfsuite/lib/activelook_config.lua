-- Shared ActiveLook preferences and choice helpers.

if package.loaded["rfsuite.lib.activelook_config"] then
  return package.loaded["rfsuite.lib.activelook_config"]
end

local config = {}

config.DEFAULTS = {
  enabled = false,
  inflight_fuel_icon = false,
  display_switch = "",
  low_fuel_warning = false,
  low_fuel_use_audio_limit = false,
  low_fuel_seconds = 5,
  low_fuel_repeats = 1,
  low_fuel_icon = true,
  esc_temp_warning = false,
  esc_temp_icon = true,
  esc_temp_use_audio_limit = true,
  esc_temp_limit = 90,
  esc_temp_seconds = 5,
  esc_temp_repeats = 2,
  rf_link_warning = false,
  rf_link_icon = true,
  rf_link_limit = 42,
  rf_link_percent_limit = 80,
  rf_link_seconds = 5,
  rf_link_repeats = 2,
  governor_lost_warning = false,
  governor_lost_seconds = 5,
  governor_status_overlays = false,
  governor_status_seconds = 2,
  offset_x = 0,
  offset_y = 0,
  layout_preflight = "stacked_three",
  layout_inflight = "one_top_two_bottom",
  layout_postflight = "two_top_two_bottom",
  preflight_1 = "governor",
  preflight_2 = "armed",
  preflight_3 = "flightmode",
  preflight_4 = "off",
  inflight_1 = "current",
  inflight_2 = "voltage",
  inflight_3 = "fuel",
  inflight_4 = "timer",
  postflight_1 = "current",
  postflight_2 = "voltage",
  postflight_3 = "fuel",
  postflight_4 = "timer",
}

config.SENSOR_KEYS = {
  "off",
  "flightmode",
  "timer",
  "governor",
  "armed",
  "temp_esc",
  "temp_mcu",
  "link",
  "fuel",
  "current",
  "voltage",
  "cell_voltage",
  "headspeed",
  "consumption",
  "temp_esc_max",
  "temp_mcu_max",
  "link_min",
  "link_max",
  "fuel_min",
  "fuel_max",
  "current_min",
  "current_max",
  "voltage_min",
  "voltage_max",
  "headspeed_min",
  "headspeed_max",
}

config.SENSOR_CHOICES = {
  {"Off", 1},
  {"Flight Mode", 2},
  {"Timer", 3},
  {"@i18n(telemetry.sensor_governor)@", 4},
  {"Arm Status", 5},
  {"@i18n(telemetry.sensor_esc_temp)@", 6},
  {"@i18n(telemetry.sensor_mcu_temp)@", 7},
  {"Link", 8},
  {"@i18n(sensors.smartfuel)@", 9},
  {"@i18n(telemetry.sensor_current)@", 10},
  {"@i18n(telemetry.sensor_voltage)@", 11},
  {"Cell Voltage", 12},
  {"@i18n(telemetry.sensor_headspeed)@", 13},
  {"@i18n(widgets.dashboard.consumed_mah)@", 14},
  {"Max ESC Temp", 15},
  {"Max MCU Temp", 16},
  {"Min Link", 17},
  {"Max Link", 18},
  {"@i18n(app.modules.settings.activelook_smartfuel_min)@", 19},
  {"@i18n(app.modules.settings.activelook_smartfuel_max)@", 20},
  {"Min Current", 21},
  {"Max Current", 22},
  {"Min Voltage", 23},
  {"Max Voltage", 24},
  {"Min Headspeed", 25},
  {"Max Headspeed", 26},
}

config.LAYOUT_KEYS = {
  "two_top_one_bottom",
  "two_top_two_bottom",
  "one_centered",
  "one_top_two_bottom",
  "stacked_three",
}

config.LAYOUT_CHOICES = {
  {"Two Top + One Bottom", 1},
  {"Two Top + Two Bottom", 2},
  {"Single Centered", 3},
  {"One Top + Two Bottom", 4},
  {"Stacked Large + Large + Small", 5},
}

config.LAYOUT_ACTIVE = {
  two_top_one_bottom = {true, true, true, false},
  two_top_two_bottom = {true, true, true, true},
  one_centered = {true, false, false, false},
  one_top_two_bottom = {true, false, true, true},
  stacked_three = {true, true, true, false},
}

local function buildSet(list)
  local set = {}
  for i = 1, #list do set[list[i]] = true end
  return set
end

local SENSOR_KEY_SET = buildSet(config.SENSOR_KEYS)
local LAYOUT_KEY_SET = buildSet(config.LAYOUT_KEYS)

local function clamp(value, min, max)
  if type(value) == "number" and value >= min and value <= max and value % 1 == 0 then return value end
  value = tonumber(value) or 0
  if value ~= value or value == math.huge or value == -math.huge then value = min end
  if value < min then return min end
  if value > max then return max end
  return math.floor(value + 0.5)
end

local function coerceBool(value, default)
  if value == true or value == false then return value end
  if value == nil then return default end
  if value == true or value == "true" or value == 1 or value == "1" then return true end
  if value == false or value == "false" or value == 0 or value == "0" then return false end
  return default
end

function config.keyToChoice(key)
  if type(key) == "number" then
    local idx = math.floor(key)
    if idx >= 1 and idx <= #config.SENSOR_KEYS then return idx end
  end
  for i = 1, #config.SENSOR_KEYS do
    if config.SENSOR_KEYS[i] == key then return i end
  end
  return 1
end

function config.choiceToKey(value)
  local idx = tonumber(value) or 1
  return config.SENSOR_KEYS[idx] or config.SENSOR_KEYS[1]
end

function config.layoutKeyToChoice(key)
  for i = 1, #config.LAYOUT_KEYS do
    if config.LAYOUT_KEYS[i] == key then return i end
  end
  return 1
end

function config.layoutChoiceToKey(value)
  local idx = tonumber(value) or 1
  return config.LAYOUT_KEYS[idx] or config.LAYOUT_KEYS[1]
end

function config.clampOffset(value)
  return clamp(value, -20, 20)
end

config.LOW_FUEL_SECONDS_MIN = 3
config.LOW_FUEL_SECONDS_MAX = 30

function config.clampLowFuelSeconds(value)
  value = tonumber(value)
  if not value then return config.DEFAULTS.low_fuel_seconds end
  return clamp(value, config.LOW_FUEL_SECONDS_MIN, config.LOW_FUEL_SECONDS_MAX)
end

-- Total number of times the overlay is shown, like the voice alert's "Low fuel repeats".
config.LOW_FUEL_REPEATS_MIN = 1
config.LOW_FUEL_REPEATS_MAX = 10

function config.clampLowFuelRepeats(value)
  value = tonumber(value)
  if not value then return config.DEFAULTS.low_fuel_repeats end
  return clamp(value, config.LOW_FUEL_REPEATS_MIN, config.LOW_FUEL_REPEATS_MAX)
end

function config.clampEscTempRepeats(value)
  return clamp(tonumber(value) or config.DEFAULTS.esc_temp_repeats, 0, 10)
end

function config.clampRfLinkLimit(value)
  return clamp(tonumber(value) or 42, 1, 100)
end

function config.clampRfLinkPercentLimit(value)
  return clamp(tonumber(value) or 80, 1, 100)
end

function config.clampAlertSeconds(value)
  return clamp(tonumber(value) or 5, 3, 30)
end

function config.clampEscTempLimit(value)
  return clamp(tonumber(value) or 90, 60, 300)
end

function config.clampGovernorStatusSeconds(value)
  return clamp(tonumber(value) or 2, 1, 5)
end

function config.escTempLimit(values, events)
  if values.esc_temp_use_audio_limit then
    return config.clampEscTempLimit(events and events.escalertvalue)
  end
  return config.clampEscTempLimit(values.esc_temp_limit)
end

function config.alertRepeats(values, events, kind)
  if kind == "low_fuel" then
    if values.low_fuel_use_audio_limit then
      return config.clampLowFuelRepeats(events and events.smartfuelrepeats)
    end
    return config.clampLowFuelRepeats(values.low_fuel_repeats)
  end
  if values.esc_temp_use_audio_limit then
    return clamp(tonumber(events and events.temp_esc_repeats) or 0, 0, 10)
  end
  return config.clampEscTempRepeats(values.esc_temp_repeats)
end

-- Mutates only a section already owned by the caller (for example a settings clone).
function config.normalize(out)
  for key, value in pairs(config.DEFAULTS) do
    local current = out[key]
    if current == nil then
      out[key] = value
    elseif current ~= value and type(value) == "string" then
      local keys = SENSOR_KEY_SET[value] and SENSOR_KEY_SET or LAYOUT_KEY_SET[value] and LAYOUT_KEY_SET
      if keys and not keys[current] then out[key] = value end
    end
  end

  if out.enabled ~= config.DEFAULTS.enabled then out.enabled = coerceBool(out.enabled, config.DEFAULTS.enabled) end
  if out.inflight_fuel_icon ~= config.DEFAULTS.inflight_fuel_icon then out.inflight_fuel_icon = coerceBool(out.inflight_fuel_icon, config.DEFAULTS.inflight_fuel_icon) end
  if out.low_fuel_warning ~= config.DEFAULTS.low_fuel_warning then out.low_fuel_warning = coerceBool(out.low_fuel_warning, config.DEFAULTS.low_fuel_warning) end
  if out.low_fuel_use_audio_limit ~= config.DEFAULTS.low_fuel_use_audio_limit then out.low_fuel_use_audio_limit = coerceBool(out.low_fuel_use_audio_limit, false) end
  if out.low_fuel_seconds ~= config.DEFAULTS.low_fuel_seconds then out.low_fuel_seconds = config.clampLowFuelSeconds(out.low_fuel_seconds) end
  if out.low_fuel_repeats ~= config.DEFAULTS.low_fuel_repeats then out.low_fuel_repeats = config.clampLowFuelRepeats(out.low_fuel_repeats) end
  if out.low_fuel_icon ~= config.DEFAULTS.low_fuel_icon then out.low_fuel_icon = coerceBool(out.low_fuel_icon, config.DEFAULTS.low_fuel_icon) end
  if out.esc_temp_warning ~= config.DEFAULTS.esc_temp_warning then out.esc_temp_warning = coerceBool(out.esc_temp_warning, false) end
  if out.esc_temp_icon ~= config.DEFAULTS.esc_temp_icon then out.esc_temp_icon = coerceBool(out.esc_temp_icon, config.DEFAULTS.esc_temp_icon) end
  if out.esc_temp_use_audio_limit ~= config.DEFAULTS.esc_temp_use_audio_limit then out.esc_temp_use_audio_limit = coerceBool(out.esc_temp_use_audio_limit, true) end
  if out.esc_temp_limit ~= config.DEFAULTS.esc_temp_limit then out.esc_temp_limit = config.clampEscTempLimit(out.esc_temp_limit) end
  if out.esc_temp_seconds ~= config.DEFAULTS.esc_temp_seconds then out.esc_temp_seconds = config.clampAlertSeconds(out.esc_temp_seconds) end
  if out.esc_temp_repeats ~= config.DEFAULTS.esc_temp_repeats then out.esc_temp_repeats = config.clampEscTempRepeats(out.esc_temp_repeats) end
  if out.rf_link_warning ~= config.DEFAULTS.rf_link_warning then out.rf_link_warning = coerceBool(out.rf_link_warning, false) end
  if out.rf_link_icon ~= config.DEFAULTS.rf_link_icon then out.rf_link_icon = coerceBool(out.rf_link_icon, config.DEFAULTS.rf_link_icon) end
  if out.rf_link_limit ~= config.DEFAULTS.rf_link_limit then out.rf_link_limit = config.clampRfLinkLimit(out.rf_link_limit) end
  if out.rf_link_percent_limit ~= config.DEFAULTS.rf_link_percent_limit then out.rf_link_percent_limit = config.clampRfLinkPercentLimit(out.rf_link_percent_limit) end
  if out.rf_link_seconds ~= config.DEFAULTS.rf_link_seconds then out.rf_link_seconds = config.clampAlertSeconds(out.rf_link_seconds) end
  if out.rf_link_repeats ~= config.DEFAULTS.rf_link_repeats then out.rf_link_repeats = config.clampLowFuelRepeats(out.rf_link_repeats) end
  if out.governor_lost_warning ~= config.DEFAULTS.governor_lost_warning then out.governor_lost_warning = coerceBool(out.governor_lost_warning, false) end
  if out.governor_lost_seconds ~= config.DEFAULTS.governor_lost_seconds then out.governor_lost_seconds = config.clampAlertSeconds(out.governor_lost_seconds) end
  if out.governor_status_overlays ~= config.DEFAULTS.governor_status_overlays then out.governor_status_overlays = coerceBool(out.governor_status_overlays, false) end
  if out.governor_status_seconds ~= config.DEFAULTS.governor_status_seconds then out.governor_status_seconds = config.clampGovernorStatusSeconds(out.governor_status_seconds) end
  if out.offset_x ~= config.DEFAULTS.offset_x then out.offset_x = config.clampOffset(out.offset_x) end
  if out.offset_y ~= config.DEFAULTS.offset_y then out.offset_y = config.clampOffset(out.offset_y) end
  if out.display_switch ~= config.DEFAULTS.display_switch then out.display_switch = tostring(out.display_switch or "") end

  return out
end

function config.withDefaults(values)
  local out = {}
  for key, value in pairs(values or {}) do out[key] = value end
  return config.normalize(out)
end

function config.layoutPreview(layoutKey)
  if layoutKey == "two_top_one_bottom" then
    return "[1]     [2]", "      [3]"
  elseif layoutKey == "two_top_two_bottom" then
    return "[1]     [2]", "[3]     [4]"
  elseif layoutKey == "one_centered" then
    return "      [1]", ""
  elseif layoutKey == "one_top_two_bottom" then
    return "      [1]", "[3]     [4]"
  elseif layoutKey == "stacked_three" then
    return "     [1/2]", "        [3]"
  end
  return "[1]     [2]", "[3]     [4]"
end

package.loaded["rfsuite.lib.activelook_config"] = config
return config
