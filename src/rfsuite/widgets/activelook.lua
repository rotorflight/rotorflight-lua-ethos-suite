-- Rotorflight ActiveLook widget.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local activeConfig = requireModule("lib/activelook_config.lua")
local alerts = requireModule("lib/activelook_alerts.lua")
local engineType = requireModule("lib/engine_type.lua")
local flightmode = requireModule("widgets/dashboard/flightmode.lua")

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
local LOW_FUEL_ICON_NITRO = 11
local LOW_FUEL_ICON_ELECTRIC = 21
local ESC_TEMP_ICON = 18
local RF_LINK_ICON = 16
local ALERT_ICON_PX = 40
local ETHOS_BITMAP_FRAME_PX = 40
local FUEL_ICON_BOTTOM_CLEARANCE = 56
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

local function linkSuffix(widget)
  return widget.linkQualityIsPercent and "%" or "dB"
end

local function governorStateLabel(value)
  value = tonumber(value)
  if not value then return "UNKNOWN" end
  return GOVERNOR_LABELS[floor(value)] or "UNKNOWN"
end

local function estimateTextWidth(text, fontId)
  local px = FONT_PX[fontId] or 24
  text = tostring(text or "")
  local length = 0
  for i = 1, #text do
    local byte = text:byte(i)
    if byte < 128 or byte >= 192 then length = length + 1 end
  end
  return length * (px * 0.6)
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
  off = {},
  flightmode = {
    value = function(_, mode)
      if mode == "inflight" then return "FLY" end
      if mode == "postflight" then return "POST" end
      return "PRE"
    end,
  },
  timer = {value = function(widget) return formatDuration(widget.timerLive or widget.timerSession or 0) end},
  governor = {
    value = function(widget)
      return governorStateLabel(widget.governorState or widget.governorMode)
    end,
  },
  armed = {value = function(widget) return widget.isArmed == true and "ARMED" or "DISARMED" end},
  fuel = {value = function(widget) return sensor(widget, "fuel") end, decimals = 0, suffix = "%"},
  consumption = {value = function(widget) return sensor(widget, "consumption") end, decimals = 0, suffix = "mAh"},
  current = {value = function(widget) return sensor(widget, "current") end, decimals = 1, suffix = "A"},
  voltage = {value = function(widget) return sensor(widget, "voltage") end, decimals = 1, suffix = "V"},
  cell_voltage = {value = function(widget) return sensor(widget, "cell_voltage") end, decimals = 2, suffix = "V"},
  headspeed = {value = function(widget) return sensor(widget, "rpm") end, decimals = 0, suffix = ""},
  temp_esc = {value = function(widget) return temperatureValue(widget, sensor(widget, "temp_esc")) end, decimals = 0, temperature = true},
  temp_mcu = {value = function(widget) return temperatureValue(widget, sensor(widget, "temp_mcu")) end, decimals = 0, temperature = true},
  link = {value = function(widget) return sensor(widget, "link") end, decimals = 0, link = true},
  fuel_min = {value = function(widget) return stat(widget, "fuel", "min") end, decimals = 0, suffix = "%"},
  fuel_max = {value = function(widget) return stat(widget, "fuel", "max") end, decimals = 0, suffix = "%"},
  current_min = {value = function(widget) return stat(widget, "current", "min") end, decimals = 1, suffix = "A"},
  current_max = {value = function(widget) return stat(widget, "current", "max") end, decimals = 0, suffix = "A"},
  voltage_min = {value = function(widget) return stat(widget, "voltage", "min") end, decimals = 1, suffix = "V"},
  voltage_max = {value = function(widget) return stat(widget, "voltage", "max") end, decimals = 1, suffix = "V"},
  headspeed_min = {value = function(widget) return stat(widget, "rpm", "min") end, decimals = 0, suffix = ""},
  headspeed_max = {value = function(widget) return stat(widget, "rpm", "max") end, decimals = 0, suffix = ""},
  temp_esc_max = {value = function(widget) return temperatureValue(widget, stat(widget, "temp_esc", "max")) end, decimals = 0, temperature = true},
  temp_mcu_max = {value = function(widget) return temperatureValue(widget, stat(widget, "temp_mcu", "max")) end, decimals = 0, temperature = true},
  link_min = {value = function(widget) return stat(widget, "link", "min") end, decimals = 0, link = true},
  link_max = {value = function(widget) return stat(widget, "link", "max") end, decimals = 0, link = true},
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

local function clearStats(stats)
  for key in pairs(stats) do stats[key] = nil end
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

local function resetRuntime(widget)
  if not widget then return end
  clearDisplay(widget)
  widget.layout = nil
  widget.lowFuelSlots = nil
  widget.alertSlots = nil
  widget.phaseLayouts = nil
  widget.lastMode = nil
  widget.lastConfigKey = nil
  if widget.lastValues then
    for key in pairs(widget.lastValues) do widget.lastValues[key] = nil end
  end
  widget.lastFuelIcon = nil
  widget.lastAlertIcon = nil
  widget.displayBlanked = false
  widget.displaySwitchKey = nil
  widget.displaySwitchSource = nil
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

local function layoutPhase(widget)
  if widget.previewMode == "preflight" or widget.previewMode == "inflight" or widget.previewMode == "postflight" then
    return widget.previewMode
  end
  return flightmode.layoutPhase(widget.flightmode:update(widget))
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
  -- Ethos flips bitmap commands using a fixed 40x40 frame.
  -- Leave an additional image-height clearance: the device test at the calculated
  -- bottom edge erased only the icon's top row. This bound needs device validation.
  -- See docs/reference/activelook-coordinate-mapping.md.
  local maxIconX = math.max(0, areaW - ETHOS_BITMAP_FRAME_PX)
  local maxIconY = math.max(0, areaH - ETHOS_BITMAP_FRAME_PX - FUEL_ICON_BOTTOM_CLEARANCE)
  widget.fuelIconX = floor(clamp(offsetX, 0, maxIconX))
  widget.fuelIconY = floor(clamp(maxIconY + offsetY, 0, maxIconY))
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
  local function add(idx, enabled, x, y, font, textYOffset, width, align)
    slots[idx] = {enabled = enabled, x = x, y = y, font = font, textYOffset = textYOffset, width = width, align = align}
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
    add(1, active[1], leftX, topY, largeFont, largeOffset, boxW, isPreflight and "center" or nil)
    add(2, active[2], rightX, topY, largeFont, largeOffset, boxW, isPreflight and "center" or nil)
    add(3, active[3], centerX, bottomY, smallFont, smallOffset, boxW, "center")
  elseif layoutChoice == "stacked_three" then
    add(1, active[1], leftX, topY, largeFont, largeOffset, areaW, "center")
    add(2, active[2], leftX, midY, largeFont, largeOffset, areaW, "center")
    add(3, active[3], leftX, bottomY, smallFont, smallOffset, areaW, "center")
  elseif layoutChoice == "one_centered" then
    add(1, active[1], leftX, midY, largeFont, largeOffset, areaW, "center")
  elseif layoutChoice == "one_top_two_bottom" then
    add(1, active[1], leftX, topY, largeFont, largeOffset, areaW, "center")
    add(3, active[3], leftX, bottomY, compactFont, smallOffset, boxW, isPreflight and "center" or nil)
    add(4, active[4], rightX, bottomY, compactFont, smallOffset, boxW, isPreflight and "center" or nil)
  else
    add(1, active[1], leftX, topY, largeFont, largeOffset, boxW, isPreflight and "center" or nil)
    add(2, active[2], rightX, topY, largeFont, largeOffset, boxW, isPreflight and "center" or nil)
    add(3, active[3], leftX, bottomY, compactFont, smallOffset, boxW, isPreflight and "center" or nil)
    add(4, active[4], rightX, bottomY, compactFont, smallOffset, boxW, isPreflight and "center" or nil)
  end
  return slots
end

local function valueFor(widget, modeKey, key)
  local def = SENSOR_DEFS[key] or SENSOR_DEFS.off
  local value = def.value and def.value(widget, modeKey) or nil
  if value == nil then return "-" end
  if def.decimals ~= nil then return formatNumber(value, def.decimals, def.temperature and temperatureSuffix(widget) or (def.link and linkSuffix(widget) or def.suffix)) end
  return tostring(value)
end

-- Use the existing Smart Fuel percentage; missing telemetry stays hidden.
local function fuelIcon(widget, modeKey)
  if modeKey ~= "inflight" or widget.settings.inflight_fuel_icon ~= true then return nil end
  local fuel = tonumber(widget.fuelPercent)
  if not fuel or fuel ~= fuel then return nil end
  local percent = clamp(fuel, 0, 100)
  -- Nearest quarter: empty, quarter, half, three quarters, full (frsky IDs 02-06).
  return 2 + floor(percent / 25 + 0.5)
end

local function render(widget, modeKey, values, slots, configKey, fuelIconId)
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
      local textW = estimateTextWidth(text, slot.font)
      local iconW = (slot.icon or slot.reserveIconSpace) and (ALERT_ICON_PX + ICON_GAP) or 0
      if slot.align == "center" and slot.width then
        textX = slot.x + math.max(0, (slot.width - textW - iconW) * 0.5) + iconW
      end
      commands[#commands + 1] = {text = {text = text, x = toInt(textX), y = toInt(slot.y + (slot.textYOffset or 0)), font = slot.font}}
      if slot.icon then
        -- Align the symbol with the percentage text.
        local iconY = slot.y + (slot.textYOffset or 0)
        commands[#commands + 1] = {bitmap = {id = slot.icon,
          x = math.max(0, toInt(textX - iconW)), y = math.max(0, toInt(iconY))}}
      end
    end
  end
  if fuelIconId then
    commands[#commands + 1] = {bitmap = {id = fuelIconId, x = widget.fuelIconX, y = widget.fuelIconY}}
  end
  widget.layout:clearAndDisplayExtended({x = 0, y = 0, text = "", commands = commands})
  widget.lastFuelIcon = fuelIconId
  widget.lastAlertIcon = slots[2] and slots[2].icon or nil
  widget.lastMode = modeKey
  widget.lastConfigKey = configKey
  widget.displayBlanked = false
  for i = 1, #values do widget.lastValues[i] = values[i] end
end

local function lowFuelSlots(widget, blinkOn)
  local slots = widget.lowFuelSlots
  local showIcon = widget.settings.low_fuel_icon
  local iconId = widget.electricModel and LOW_FUEL_ICON_ELECTRIC or LOW_FUEL_ICON_NITRO
  local icon = showIcon and blinkOn and iconId or nil
  if slots then
    slots[2].icon = icon
    slots[2].reserveIconSpace = showIcon
    return slots
  end
  local m = widget.metrics
  slots = {
    {enabled = true, x = m.offsetX, y = m.topRowY, font = 1, textYOffset = m.largeOffset, width = m.areaW, align = "center"},
    {enabled = true, x = m.offsetX, y = m.midRowY, font = 3, textYOffset = m.largeOffset, width = m.areaW, align = "center", icon = icon, reserveIconSpace = showIcon},
    {enabled = true, x = m.offsetX, y = m.bottomRowY, font = 1, textYOffset = m.smallOffset, width = m.boxW, align = "center"},
    {enabled = true, x = m.rightX, y = m.bottomRowY, font = 1, textYOffset = m.smallOffset, width = m.boxW, align = "center"},
  }
  widget.lowFuelSlots = slots
  return slots
end

local ALERT_LIMIT_PREFIX = "@i18n(widgets.activelook.alert_limit)@ "

local STATUS_LABELS = {[7] = "@i18n(widgets.activelook.alert_autorotation)@", [8] = "@i18n(widgets.activelook.alert_bailout)@"}

local function overlayNumber(widget, index, value, decimals, suffix, prefix)
  local cache = widget.overlayCache[index]
  if type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge then
    local scale = decimals == 1 and 10 or 1
    value = floor(value * scale + 0.5) / scale
  else
    value = nil
  end
  if cache.text == nil or cache.value ~= value or cache.decimals ~= decimals
      or cache.suffix ~= suffix or cache.prefix ~= prefix then
    cache.value, cache.decimals, cache.suffix, cache.prefix = value, decimals, suffix, prefix
    cache.text = (prefix or "") .. formatNumber(value, decimals, suffix)
  end
  return cache.text
end

local function overlaySlots(widget, overlay)
  if overlay.kind == "low_fuel" then return lowFuelSlots(widget, overlay.blinkOn) end
  local slots = widget.alertSlots
  if not slots then
    local m = widget.metrics
    slots = {
      {x = m.offsetX, y = m.topRowY, font = 1, textYOffset = m.largeOffset, width = m.areaW, align = "center"},
      {x = m.offsetX, y = m.midRowY, font = 2, textYOffset = m.largeOffset, width = m.areaW, align = "center"},
      {x = m.offsetX, y = m.bottomRowY, font = 1, textYOffset = m.smallOffset, width = m.areaW, align = "center"},
    }
    widget.alertSlots = slots
  end
  slots[2].font = overlay.kind == "governor_lost" and 1 or 2
  local temperature = overlay.kind == "esc_temp" and widget.settings.esc_temp_icon
  local icon = temperature and ESC_TEMP_ICON or (overlay.kind == "rf_link" and widget.settings.rf_link_icon and RF_LINK_ICON or nil)
  slots[2].icon = overlay.blinkOn and icon or nil
  slots[2].reserveIconSpace = icon ~= nil
  return slots
end

local function overlayValues(widget, overlay)
  local values = widget.overlayValues
  local kind = overlay.kind
  if kind == "low_fuel" then
    values[1] = widget.electricModel and "@i18n(widgets.activelook.alert_battery_empty)@" or "@i18n(widgets.activelook.alert_fuel_low)@"
    values[2] = overlayNumber(widget, 2, tonumber(widget.fuelPercent), 0, "%")
    values[3] = overlayNumber(widget, 3, widget.voltage, 1, "V")
    values[4] = overlayNumber(widget, 4, widget.consumption, 0, "mAh")
  else
    values[4] = nil
    if kind == "esc_temp" then
      values[1] = "@i18n(widgets.activelook.alert_esc_temp_high)@"
      values[2] = overlayNumber(widget, 2, temperatureValue(widget, widget.tempEsc), 0, temperatureSuffix(widget))
      values[3] = overlayNumber(widget, 3, temperatureValue(widget, widget.escTempLimit), 0, temperatureSuffix(widget), ALERT_LIMIT_PREFIX)
    elseif kind == "rf_link" then
      values[1] = "@i18n(widgets.activelook.alert_rf_link_low)@"
      local suffix = linkSuffix(widget)
      local limit = widget.linkQualityIsPercent and widget.settings.rf_link_percent_limit or widget.settings.rf_link_limit
      values[2] = overlayNumber(widget, 2, widget.linkQuality, 0, suffix)
      values[3] = overlayNumber(widget, 3, limit, 0, suffix, ALERT_LIMIT_PREFIX)
    elseif kind == "governor_lost" then
      values[1], values[2] = "@i18n(widgets.activelook.alert_warning)@", "@i18n(widgets.activelook.alert_headspeed_lost)@"
      values[3] = overlayNumber(widget, 3, widget.rpm, 0, "", "RPM ")
    else
      values[1], values[2] = "@i18n(widgets.activelook.alert_governor)@", STATUS_LABELS[overlay.governorState] or "-"
      values[3] = overlayNumber(widget, 3, widget.rpm, 0, "", "RPM ")
    end
  end
  return values
end

local function update(widget, snapshot)
  snapshot = snapshot or {}
  widget.connected = snapshot.connected == true
  widget.isArmed = snapshot.isArmed
  widget.rxMap = snapshot.rxMap
  widget.voltage = snapshot.voltage
  widget.batteryConfig = snapshot.batteryConfig
  widget.electricModel = engineType.isElectric(snapshot.batteryConfig, snapshot.smartfuelModelType)
  widget.consumption = snapshot.consumption
  widget.current = snapshot.current
  widget.throttlePercent = snapshot.throttlePercent
  widget.rpm = snapshot.rpm
  widget.linkQuality = snapshot.linkQuality
  widget.linkQualityIsPercent = snapshot.linkQualityIsPercent == true
  widget.tempEsc = snapshot.tempEsc
  widget.tempMcu = snapshot.tempMcu
  widget.fuelPercent = snapshot.fuelPercent
  widget.governorMode = snapshot.governorMode
  widget.governorState = snapshot.governorState
  widget.timerLive = snapshot.timerLive or 0
  widget.timerSession = snapshot.timerSession or 0
  local previousMode = widget.flightmode.current
  local currentMode = widget.flightmode:update(widget)
  if currentMode == "inflight" and previousMode ~= "inflight" and previousMode ~= "postflight" then
    clearStats(widget.stats)
  end
  alerts.update(widget.alertState, widget, currentMode, os_clock())
  if currentMode == "inflight" then
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
    overlayValues = {},
    overlayCache = {{}, {}, {}, {}},
    flightmode = flightmode.new(),
    stats = {},
    lastDraw = 0,
    lastValues = {},
  }
  widget.escTempLimit = activeConfig.escTempLimit(widget.settings, settingsSnapshot.events)
  widget.lowFuelRepeats = activeConfig.alertRepeats(widget.settings, settingsSnapshot.events, "low_fuel")
  widget.escTempRepeats = activeConfig.alertRepeats(widget.settings, settingsSnapshot.events, "esc_temp")
  widget.alertState = alerts.new(widget.settings)
  widget.sessionHandler = bus.subscribe("session.update", function(snapshot) update(widget, snapshot) end)
  widget.settingsHandler = bus.subscribe("settings.update", function(snapshot)
    widget.settings = settingsStore.activelook(snapshot)
    widget.temperatureUnit = temperatureUnit(snapshot)
    widget.escTempLimit = activeConfig.escTempLimit(widget.settings, snapshot.events)
    widget.lowFuelRepeats = activeConfig.alertRepeats(widget.settings, snapshot.events, "low_fuel")
    widget.escTempRepeats = activeConfig.alertRepeats(widget.settings, snapshot.events, "esc_temp")
    alerts.configure(widget.alertState, widget.settings)
    resetRuntime(widget)
  end)
  widget.controlHandler = bus.subscribe("activelook.control", function(action)
    if type(action) ~= "table" then return end
    if not action.reset then
      widget.previewMode = action.previewMode
      alerts.setPreview(widget.alertState, widget.previewMode, os_clock())
    end
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

  local modeKey = layoutPhase(widget)
  local overlay = alerts.current(widget.alertState, now)
  local configKey, slots, values
  if overlay then
    configKey = overlay.kind
    slots = overlaySlots(widget, overlay)
    values = overlayValues(widget, overlay)
  else
    -- Settings updates and geometry rebuilds invalidate these phase caches.
    local phases = widget.phaseLayouts
    if not phases then
      phases = {}
      widget.phaseLayouts = phases
    end
    local phase = phases[modeKey]
    if not phase then
      local layoutChoice = widget.settings["layout_" .. modeKey] or activeConfig.DEFAULTS["layout_" .. modeKey]
      local layout = {}
      for i = 1, 4 do layout[i] = widget.settings[modeKey .. "_" .. i] or activeConfig.DEFAULTS[modeKey .. "_" .. i] end
      phase = {keys = layout, configKey = layoutChoice .. "|" .. concat(layout, "|"),
        slots = computeSlots(widget, modeKey, layoutChoice), values = {}}
      phases[modeKey] = phase
    end
    configKey = phase.configKey
    slots = phase.slots
    values = phase.values
    for i = 1, 4 do values[i] = valueFor(widget, modeKey, phase.keys[i]) end
  end

  local fuelIconId = not overlay and fuelIcon(widget, modeKey) or nil
  local dirty = modeKey ~= widget.lastMode or configKey ~= widget.lastConfigKey
    or fuelIconId ~= widget.lastFuelIcon
    or ((configKey == "low_fuel" or configKey == "esc_temp" or configKey == "rf_link") and slots[2].icon ~= widget.lastAlertIcon)
  for i = 1, #values do
    if values[i] ~= widget.lastValues[i] then dirty = true end
  end
  if dirty then render(widget, modeKey, values, slots, configKey, fuelIconId) end
end

local function build(widget)
  resetRuntime(widget)
  if widget and widget.settings and widget.settings.enabled == true then buildLayout(widget) end
end

local function close(widget)
  if not widget then return end
  clearDisplay(widget)
  if widget.sessionHandler then
    bus.unsubscribe("session.update", widget.sessionHandler)
    widget.sessionHandler = nil
  end
  if widget.settingsHandler then
    bus.unsubscribe("settings.update", widget.settingsHandler)
    widget.settingsHandler = nil
  end
  if widget.controlHandler then
    bus.unsubscribe("activelook.control", widget.controlHandler)
    widget.controlHandler = nil
  end
  resetRuntime(widget)
  alerts.reset(widget.alertState)
  widget.alertSlots = nil
  widget.overlayValues = nil
  widget.overlayCache = nil
end

local widgetDef = {
  key = "rfalk",
  name = "Rotorflight ActiveLook",
  create = create,
  build = build,
  wakeup = wakeup,
  close = close,
}

local function init()
  if system.registerGlassesWidget then system.registerGlassesWidget(widgetDef) end
end

return {init = init}
