-- Rotorflight ActiveLook widget.

local bus = assert(loadfile("lib/bus.lua"))()
local settingsStore = assert(loadfile("lib/settings_store.lua"))()
local activeConfig = assert(loadfile("lib/activelook_config.lua"))()
local flightmode = assert(loadfile("widgets/dashboard/flightmode.lua"))()

local os_clock = os.clock
local floor = math.floor
local format = string.format
local concat = table.concat

local REDRAW_INTERVAL = 0.05
local OUTER_PADDING = 8
local ICON_GAP = 8
local LARGE_FONT = 3
local SMALL_FONT = 2
local COMPACT_FONT = 1
local PREFLIGHT_TOP_FONT = 3
local PREFLIGHT_BOTTOM_FONT = 1
local fmtCache = {}

local FONT_PX = {
  [1] = 24,
  [2] = 38,
  [3] = 64,
  [4] = 75,
  [5] = 82,
}

local GOVERNOR_LABELS = {
  [0] = "OFF",
  [1] = "IDLE",
  [2] = "SPOOLUP",
  [3] = "RECOVERY",
  [4] = "ACTIVE",
  [5] = "THR OFF",
  [6] = "LOST HS",
  [7] = "AUTOROT",
  [8] = "BAILOUT",
  [100] = "DISABLED",
  [101] = "DISARMED",
}

local function clamp(value, min, max)
  value = tonumber(value) or 0
  if value < min then return min end
  if value > max then return max end
  return value
end

local function toNumber(value)
  if type(value) == "number" then return value end
  if type(value) ~= "string" then return nil end
  local token = value:match("([+-]?%d*%.?%d+)")
  return token and tonumber(token) or nil
end

local function formatNumber(value, decimals, suffix)
  if type(value) ~= "number" then return "-" end
  local text
  if decimals == 1 then
    text = format("%.1f", value)
  elseif decimals == 0 then
    text = tostring(floor(value + 0.5))
  elseif type(decimals) == "number" then
    local fmt = fmtCache[decimals]
    if not fmt then
      fmt = "%." .. tostring(decimals) .. "f"
      fmtCache[decimals] = fmt
    end
    text = format(fmt, value)
  else
    text = tostring(value)
  end
  if suffix and suffix ~= "" then text = text .. suffix end
  return text
end

local function formatDuration(seconds)
  seconds = toNumber(seconds)
  if type(seconds) ~= "number" or seconds < 0 then return "00:00" end
  local total = floor(seconds + 0.5)
  return format("%02d:%02d", floor(total / 60), total % 60)
end

local function temperatureUnit(settings)
  return settingsStore.temperatureUnit(settings) == 1 and 1 or 0
end

local function temperatureValue(widget, value)
  if value == nil then return nil end
  if widget and widget.temperatureUnit == 1 then return value * 1.8 + 32 end
  return value
end

local function temperatureSuffix(widget)
  return widget and widget.temperatureUnit == 1 and "°F" or "°C"
end

local function governorStateLabel(value)
  value = tonumber(value)
  if not value then return "UNKNOWN" end
  return GOVERNOR_LABELS[floor(value)] or "UNKNOWN"
end

local function estimateTextWidth(text, fontId)
  local px = FONT_PX[fontId] or 24
  return #tostring(text or "") * (px * 0.6)
end

local function stat(widget, name, kind)
  local entry = widget and widget.stats and widget.stats[name]
  return entry and entry[kind or "max"] or nil
end

local function sensor(widget, name)
  if not widget then return nil end
  if name == "voltage" then return widget.voltage end
  if name == "current" then return widget.current end
  if name == "rpm" or name == "headspeed" then return widget.rpm end
  if name == "temp_esc" then return widget.tempEsc end
  if name == "temp_mcu" then return widget.tempMcu end
  if name == "link" then return widget.linkQuality end
  if name == "fuel" or name == "smartfuel" then return widget.fuelPercent end
  if name == "consumption" or name == "smartconsumption" then return widget.consumption end
  if name == "throttle_percent" then return widget.throttlePercent end
  if name == "cell_voltage" then
    local voltage = tonumber(widget.voltage)
    local cellCount = widget.batteryConfig and tonumber(widget.batteryConfig.cellCount)
    if voltage and cellCount and cellCount > 0 then return voltage / cellCount end
  end
  return nil
end

local SENSOR_DEFS = {
  off = {label = "Off"},
  flightmode = {
    label = "Flight Mode",
    value = function(_, mode)
      if mode == "inflight" then return "FLY" end
      if mode == "postflight" then return "POST" end
      return "PRE"
    end,
  },
  timer = {label = "Timer", value = function(widget) return formatDuration(widget.timerLive or widget.timerSession or 0) end},
  governor = {
    label = "Governor",
    value = function(widget)
      return governorStateLabel(widget.governorState or widget.governorMode)
    end,
  },
  armed = {label = "Armed", value = function(widget) return widget.isArmed == true and "ARMED" or "DISARMED" end},
  fuel = {label = "Fuel", value = function(widget) return sensor(widget, "fuel") end, decimals = 0, suffix = "%"},
  consumption = {label = "Consumed mAh", value = function(widget) return sensor(widget, "consumption") end, decimals = 0, suffix = "mAh"},
  current = {label = "Current", value = function(widget) return sensor(widget, "current") end, decimals = 1, suffix = "A"},
  voltage = {label = "Voltage", value = function(widget) return sensor(widget, "voltage") end, decimals = 1, suffix = "V"},
  cell_voltage = {label = "Cell Voltage", value = function(widget) return sensor(widget, "cell_voltage") end, decimals = 2, suffix = "V"},
  headspeed = {label = "Headspeed", value = function(widget) return sensor(widget, "rpm") end, decimals = 0, suffix = ""},
  temp_esc = {label = "ESC Temp", value = function(widget) return temperatureValue(widget, sensor(widget, "temp_esc")) end, decimals = 0, temperature = true},
  temp_mcu = {label = "MCU Temp", value = function(widget) return temperatureValue(widget, sensor(widget, "temp_mcu")) end, decimals = 0, temperature = true},
  link = {label = "Link", value = function(widget) return sensor(widget, "link") end, decimals = 0, suffix = "dB"},
  fuel_min = {label = "Min Fuel", value = function(widget) return stat(widget, "fuel", "min") end, decimals = 0, suffix = "%"},
  fuel_max = {label = "Max Fuel", value = function(widget) return stat(widget, "fuel", "max") end, decimals = 0, suffix = "%"},
  current_min = {label = "Min Current", value = function(widget) return stat(widget, "current", "min") end, decimals = 1, suffix = "A"},
  current_max = {label = "Max Current", value = function(widget) return stat(widget, "current", "max") end, decimals = 0, suffix = "A"},
  voltage_min = {label = "Min Voltage", value = function(widget) return stat(widget, "voltage", "min") end, decimals = 1, suffix = "V"},
  voltage_max = {label = "Max Voltage", value = function(widget) return stat(widget, "voltage", "max") end, decimals = 1, suffix = "V"},
  headspeed_min = {label = "Min Headspeed", value = function(widget) return stat(widget, "rpm", "min") end, decimals = 0, suffix = ""},
  headspeed_max = {label = "Max Headspeed", value = function(widget) return stat(widget, "rpm", "max") end, decimals = 0, suffix = ""},
  temp_esc_max = {label = "Max ESC Temp", value = function(widget) return temperatureValue(widget, stat(widget, "temp_esc", "max")) end, decimals = 0, temperature = true},
  temp_mcu_max = {label = "Max MCU Temp", value = function(widget) return temperatureValue(widget, stat(widget, "temp_mcu", "max")) end, decimals = 0, temperature = true},
  link_min = {label = "Min Link", value = function(widget) return stat(widget, "link", "min") end, decimals = 0, suffix = "dB"},
  link_max = {label = "Max Link", value = function(widget) return stat(widget, "link", "max") end, decimals = 0, suffix = "dB"},
}

local function recordStat(widget, key, value)
  value = tonumber(value)
  if not value then return end
  local entry = widget.stats[key]
  if not entry then
    entry = {min = value, max = value}
    widget.stats[key] = entry
    return
  end
  if value < entry.min then entry.min = value end
  if value > entry.max then entry.max = value end
end

local function resetRuntime(widget)
  if not widget then return end
  widget.layout = nil
  widget.lastMode = nil
  widget.lastConfigKey = nil
  widget.lastValues = {}
  widget.displayBlanked = false
  widget.displaySwitchKey = nil
  widget.displaySwitchSource = nil
end

local function clearDisplay(widget)
  if widget and widget.layout and not widget.displayBlanked then
    widget.layout:clearAndDisplayExtended({x = 0, y = 0, text = "", commands = {}})
  end
  if widget then
    widget.displayBlanked = true
    widget.lastMode = nil
    widget.lastConfigKey = nil
  end
end

local function switchSource(widget)
  local value = widget.settings and widget.settings.display_switch
  if value == nil or value == "" then
    widget.displaySwitchKey = nil
    widget.displaySwitchSource = nil
    return nil
  end
  if widget.displaySwitchKey == value and widget.displaySwitchSource ~= nil then return widget.displaySwitchSource end
  widget.displaySwitchKey = value
  widget.displaySwitchSource = nil
  local category, member = tostring(value):match("([^,]+),([^,]+)")
  category = tonumber(category)
  member = tonumber(member)
  if category and member then widget.displaySwitchSource = system.getSource({category = category, member = member}) end
  return widget.displaySwitchSource
end

local function displayEnabled(widget)
  local source = switchSource(widget)
  if not source then return true end
  return source:state() ~= true
end

local function mode(widget)
  if widget.previewMode == "preflight" or widget.previewMode == "inflight" or widget.previewMode == "postflight" then
    return widget.previewMode
  end
  return widget.flightmode:update(widget)
end

local function buildLayout(widget)
  if not glasses or not glasses.getWindowSize or not glasses.createLayout then return false end
  local w, h = glasses.getWindowSize()
  local padding = OUTER_PADDING
  local areaW = w - (padding * 2)
  local areaH = h - (padding * 2)
  local scale = (areaH > 0) and (areaH / 256) or 1
  local offsetX = clamp(widget.settings.offset_x, -20, 20)
  local offsetY = clamp(widget.settings.offset_y, -20, 20)
  local gap = math.max(4, floor(ICON_GAP * scale))
  local boxW = floor((areaW - gap) * 0.5)
  widget.offsetX = offsetX
  widget.offsetY = offsetY
  widget.iconGap = gap
  widget.metrics = {
    areaW = areaW,
    offsetX = offsetX,
    offsetY = offsetY,
    topRowY = floor(8 * scale) + offsetY,
    midRowY = floor(88 * scale) + offsetY,
    bottomRowY = floor(186 * scale) + offsetY,
    boxW = boxW,
    rightX = offsetX + boxW + gap,
    centerX = offsetX + floor((areaW - boxW) * 0.5),
    largeOffset = floor(8 * scale),
    smallOffset = floor(6 * scale),
    preflightTopOffset = floor(14 * scale),
    preflightBottomOffset = floor(2 * scale),
  }
  widget.layout = glasses.createLayout({
    x = floor(padding + 0.5),
    y = floor(padding + 0.5),
    w = areaW,
    h = areaH,
    text = {x = 0, y = 0, font = 1},
    border = false,
  })
  return widget.layout ~= nil
end

local function computeSlots(widget, modeKey, layoutChoice)
  local metrics = widget.metrics or {}
  local slots = {}
  local active = activeConfig.LAYOUT_ACTIVE[layoutChoice] or activeConfig.LAYOUT_ACTIVE.two_top_two_bottom
  local isPreflight = modeKey == "preflight"
  local leftX = metrics.offsetX or 0
  local function add(idx, enabled, x, y, size, font, textYOffset, width, align)
    slots[idx] = {enabled = enabled, x = x, y = y, size = size, font = font, textYOffset = textYOffset, width = width, align = align}
  end
  local largeFont = isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT
  local smallFont = isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT
  local compactFont = isPreflight and PREFLIGHT_BOTTOM_FONT or COMPACT_FONT
  local largeOffset = isPreflight and metrics.preflightTopOffset or metrics.largeOffset
  local smallOffset = isPreflight and metrics.preflightBottomOffset or metrics.smallOffset
  local boxW = metrics.boxW or 0
  local areaW = metrics.areaW or 0
  local rightX = metrics.rightX or 0
  local centerX = metrics.centerX or 0
  local topY = metrics.topRowY or 0
  local midY = metrics.midRowY or 0
  local bottomY = metrics.bottomRowY or 0

  if layoutChoice == "two_top_one_bottom" then
    add(1, active[1], leftX, topY, "large", largeFont, largeOffset, boxW, isPreflight and "center" or nil)
    add(2, active[2], rightX, topY, "large", largeFont, largeOffset, boxW, isPreflight and "center" or nil)
    add(3, active[3], centerX, bottomY, "small", smallFont, smallOffset, boxW, "center")
  elseif layoutChoice == "stacked_three" then
    add(1, active[1], leftX, topY, "large", largeFont, largeOffset, areaW, "center")
    add(2, active[2], leftX, midY, "large", largeFont, largeOffset, areaW, "center")
    add(3, active[3], leftX, bottomY, "small", smallFont, smallOffset, areaW, "center")
  elseif layoutChoice == "one_centered" then
    add(1, active[1], leftX, midY, "large", largeFont, largeOffset, areaW, "center")
  elseif layoutChoice == "one_top_two_bottom" then
    add(1, active[1], leftX, topY, "large", largeFont, largeOffset, areaW, "center")
    add(3, active[3], leftX, bottomY, "small", compactFont, smallOffset, boxW, isPreflight and "center" or nil)
    add(4, active[4], rightX, bottomY, "small", compactFont, smallOffset, boxW, isPreflight and "center" or nil)
  else
    add(1, active[1], leftX, topY, "large", largeFont, largeOffset, boxW, isPreflight and "center" or nil)
    add(2, active[2], rightX, topY, "large", largeFont, largeOffset, boxW, isPreflight and "center" or nil)
    add(3, active[3], leftX, bottomY, "small", compactFont, smallOffset, boxW, isPreflight and "center" or nil)
    add(4, active[4], rightX, bottomY, "small", compactFont, smallOffset, boxW, isPreflight and "center" or nil)
  end
  return slots
end

local function valueFor(widget, modeKey, key)
  local def = SENSOR_DEFS[key] or SENSOR_DEFS.off
  local value = def.value and def.value(widget, modeKey) or nil
  if value == nil then return "-" end
  if def.decimals ~= nil then return formatNumber(value, def.decimals, def.temperature and temperatureSuffix(widget) or def.suffix) end
  return tostring(value)
end

local function render(widget, modeKey, values, slots, configKey)
  local commands = {}
  local function toInt(value)
    value = tonumber(value) or 0
    if value >= 0 then return floor(value + 0.5) end
    return math.ceil(value - 0.5)
  end
  for i = 1, #values do
    local slot = slots[i]
    if slot and slot.enabled ~= false then
      local text = values[i] or "-"
      local textX = slot.x
      if slot.align == "center" and slot.width then
        textX = slot.x + math.max(0, (slot.width - estimateTextWidth(text, slot.font)) * 0.5)
      end
      commands[#commands + 1] = {text = {text = text, x = toInt(textX), y = toInt(slot.y + (slot.textYOffset or 0)), font = slot.font}}
    end
  end
  widget.layout:clearAndDisplayExtended({x = 0, y = 0, text = "", commands = commands})
  widget.lastMode = modeKey
  widget.lastConfigKey = configKey
  widget.displayBlanked = false
  for i = 1, #values do widget.lastValues[i] = values[i] end
end

local function update(widget, snapshot)
  snapshot = snapshot or {}
  widget.connected = snapshot.connected == true
  widget.isArmed = snapshot.isArmed
  widget.voltage = snapshot.voltage
  widget.batteryConfig = snapshot.batteryConfig
  widget.consumption = snapshot.consumption
  widget.current = snapshot.current
  widget.throttlePercent = snapshot.throttlePercent
  widget.rpm = snapshot.rpm
  widget.linkQuality = snapshot.linkQuality
  widget.tempEsc = snapshot.tempEsc
  widget.tempMcu = snapshot.tempMcu
  widget.fuelPercent = snapshot.fuelPercent
  widget.governorMode = snapshot.governorMode
  widget.governorState = snapshot.governorState
  widget.timerLive = snapshot.timerLive or 0
  widget.timerSession = snapshot.timerSession or 0
  if widget.flightmode:update(widget) == "inflight" then
    recordStat(widget, "fuel", widget.fuelPercent)
    recordStat(widget, "current", widget.current)
    recordStat(widget, "voltage", widget.voltage)
    recordStat(widget, "rpm", widget.rpm)
    recordStat(widget, "temp_esc", widget.tempEsc)
    recordStat(widget, "temp_mcu", widget.tempMcu)
    recordStat(widget, "link", widget.linkQuality)
  end
end

local function create()
  local settingsSnapshot = settingsStore.load()
  local widget = {
    settings = settingsStore.activelook(settingsSnapshot),
    temperatureUnit = temperatureUnit(settingsSnapshot),
    flightmode = flightmode.new(),
    stats = {},
    lastDraw = 0,
    lastValues = {},
  }
  widget.sessionHandler = bus.subscribe("session.update", function(snapshot) update(widget, snapshot) end)
  widget.settingsHandler = bus.subscribe("settings.update", function(snapshot)
    widget.settings = settingsStore.activelook(snapshot)
    widget.temperatureUnit = temperatureUnit(snapshot)
    resetRuntime(widget)
  end)
  widget.controlHandler = bus.subscribe("activelook.control", function(action)
    if type(action) ~= "table" then return end
    widget.previewMode = action.previewMode
    if action.reset then resetRuntime(widget) end
  end)
  return widget
end

local function wakeup(widget)
  if not widget or not widget.settings or widget.settings.enabled ~= true then
    clearDisplay(widget)
    return
  end
  if not displayEnabled(widget) then
    clearDisplay(widget)
    return
  end
  if widget.offsetX ~= widget.settings.offset_x or widget.offsetY ~= widget.settings.offset_y then
    resetRuntime(widget)
  end
  if not widget.layout and not buildLayout(widget) then return end
  local now = os_clock()
  if (now - (widget.lastDraw or 0)) < REDRAW_INTERVAL then return end
  widget.lastDraw = now

  local modeKey = mode(widget)
  local layoutChoice = widget.settings["layout_" .. modeKey] or activeConfig.DEFAULTS["layout_" .. modeKey]
  local layout = {}
  for i = 1, 4 do layout[i] = widget.settings[modeKey .. "_" .. i] or activeConfig.DEFAULTS[modeKey .. "_" .. i] end
  local configKey = layoutChoice .. "|" .. concat(layout, "|")
  local slots = computeSlots(widget, modeKey, layoutChoice)
  local values = {}
  for i = 1, 4 do values[i] = valueFor(widget, modeKey, layout[i]) end

  local dirty = modeKey ~= widget.lastMode or configKey ~= widget.lastConfigKey
  for i = 1, #values do
    if values[i] ~= widget.lastValues[i] then dirty = true end
  end
  if dirty then render(widget, modeKey, values, slots, configKey) end
end

local function build(widget)
  resetRuntime(widget)
  if widget and widget.settings and widget.settings.enabled == true then buildLayout(widget) end
end

local widgetDef = {
  key = "rfalk",
  name = "Rotorflight ActiveLook",
  create = create,
  build = build,
  wakeup = wakeup,
}

local function init()
  if system.registerGlassesWidget then system.registerGlassesWidget(widgetDef) end
end

return {init = init}
