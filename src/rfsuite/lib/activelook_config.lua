-- Shared ActiveLook preferences and choice helpers.

if package.loaded["rfsuite.lib.activelook_config"] then
  return package.loaded["rfsuite.lib.activelook_config"]
end

local config = {}

config.DEFAULTS = {
  enabled = false,
  display_switch = "",
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
  {"Fuel", 9},
  {"@i18n(telemetry.sensor_current)@", 10},
  {"@i18n(telemetry.sensor_voltage)@", 11},
  {"Cell Voltage", 12},
  {"@i18n(telemetry.sensor_headspeed)@", 13},
  {"@i18n(widgets.dashboard.consumed_mah)@", 14},
  {"Max ESC Temp", 15},
  {"Max MCU Temp", 16},
  {"Min Link", 17},
  {"Max Link", 18},
  {"Min Fuel", 19},
  {"Max Fuel", 20},
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
  value = tonumber(value) or 0
  if value < min then return min end
  if value > max then return max end
  return math.floor(value + 0.5)
end

local function coerceBool(value, default)
  if value == nil then return default end
  if value == true or value == "true" or value == 1 or value == "1" then return true end
  if value == false or value == "false" or value == 0 or value == "0" then return false end
  return default
end

local function keyExists(list, key)
  if list == config.SENSOR_KEYS then
    return SENSOR_KEY_SET[key] == true
  elseif list == config.LAYOUT_KEYS then
    return LAYOUT_KEY_SET[key] == true
  end
  return false
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

function config.withDefaults(values)
  local out = {}
  values = values or {}
  for key, value in pairs(config.DEFAULTS) do out[key] = value end
  for key, value in pairs(values) do out[key] = value end

  out.enabled = coerceBool(out.enabled, config.DEFAULTS.enabled)
  out.offset_x = config.clampOffset(out.offset_x)
  out.offset_y = config.clampOffset(out.offset_y)
  out.display_switch = tostring(out.display_switch or "")

  for _, mode in ipairs({"preflight", "inflight", "postflight"}) do
    local layoutKey = "layout_" .. mode
    if not keyExists(config.LAYOUT_KEYS, out[layoutKey]) then
      out[layoutKey] = config.DEFAULTS[layoutKey]
    end
    for i = 1, 4 do
      local key = mode .. "_" .. i
      if not keyExists(config.SENSOR_KEYS, out[key]) then out[key] = config.DEFAULTS[key] end
    end
  end

  return out
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
