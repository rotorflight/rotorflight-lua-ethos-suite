-- Controls -> Adjustments.
--
-- Custom editor for ADJUSTMENT_RANGES. The original page has additional
-- per-slot prefetch paths; this lite port keeps the same editable surface
-- on top of the bulk read and changed-slot writes to minimize moving parts.

local requireModule = assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local adjustmentsMsp = requireModule("lib/msp_adjustments.lua")

local PAGE_TITLE = "@i18n(app.modules.adjustments.name)@"
local BTN_OK = "@i18n(app.btn_ok_long)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"
local MSG_RELOAD_TITLE = "@i18n(reload)@"
local MSG_RELOAD_BODY = "@i18n(app.msg_reload_settings)@"

local ALWAYS_ON_CHANNEL = 255
local AUX_CHANNEL_COUNT = 20
local RANGE_MIN = 875
local RANGE_MAX = 2125
local RANGE_STEP = 5
local RANGE_SNAP_DELTA_US = 50
local AUTODETECT_DELTA_US = 120
local FORM_RIGHT_PADDING = 12

local ADJUST_TYPE_OPTIONS = {
  {"Off", 0},
  {"Mapped", 1},
  {"Stepped", 2},
}

local ADJUST_FUNCTIONS = {
  {id = 0, name = "None", min = 0, max = 100},
  {id = 1, name = "Rate Profile", min = 1, max = 6},
  {id = 2, name = "PID Profile", min = 1, max = 6},
  {id = 3, name = "LED Profile", min = 1, max = 4},
  {id = 4, name = "OSD Profile", min = 1, max = 3},
  {id = 5, name = "Pitch Rate", min = 0, max = 255},
  {id = 6, name = "Roll Rate", min = 0, max = 255},
  {id = 7, name = "Yaw Rate", min = 0, max = 255},
  {id = 8, name = "Pitch RC Rate", min = 0, max = 255},
  {id = 9, name = "Roll RC Rate", min = 0, max = 255},
  {id = 10, name = "Yaw RC Rate", min = 0, max = 255},
  {id = 11, name = "Pitch RC Expo", min = 0, max = 100},
  {id = 12, name = "Roll RC Expo", min = 0, max = 100},
  {id = 13, name = "Yaw RC Expo", min = 0, max = 100},
  {id = 14, name = "Pitch P", min = 0, max = 250},
  {id = 15, name = "Pitch I", min = 0, max = 250},
  {id = 16, name = "Pitch D", min = 0, max = 250},
  {id = 17, name = "Pitch F", min = 0, max = 250},
  {id = 18, name = "Roll P", min = 0, max = 250},
  {id = 19, name = "Roll I", min = 0, max = 250},
  {id = 20, name = "Roll D", min = 0, max = 250},
  {id = 21, name = "Roll F", min = 0, max = 250},
  {id = 22, name = "Yaw P", min = 0, max = 250},
  {id = 23, name = "Yaw I", min = 0, max = 250},
  {id = 24, name = "Yaw D", min = 0, max = 250},
  {id = 25, name = "Yaw F", min = 0, max = 250},
  {id = 26, name = "Yaw CW Stop Gain", min = 25, max = 250},
  {id = 27, name = "Yaw CCW Stop Gain", min = 25, max = 250},
  {id = 28, name = "Yaw Cyclic FF", min = 0, max = 250},
  {id = 29, name = "Yaw Collective FF", min = 0, max = 250},
  {id = 30, name = "Yaw Collective Dynamic", min = -125, max = 125},
  {id = 31, name = "Yaw Collective Decay", min = 1, max = 250},
  {id = 32, name = "Pitch Collective FF", min = 0, max = 250},
  {id = 33, name = "Pitch Gyro Cutoff", min = 0, max = 250},
  {id = 34, name = "Roll Gyro Cutoff", min = 0, max = 250},
  {id = 35, name = "Yaw Gyro Cutoff", min = 0, max = 250},
  {id = 36, name = "Pitch Dterm Cutoff", min = 0, max = 250},
  {id = 37, name = "Roll Dterm Cutoff", min = 0, max = 250},
  {id = 38, name = "Yaw Dterm Cutoff", min = 0, max = 250},
  {id = 39, name = "Rescue Climb Collective", min = 0, max = 1000},
  {id = 40, name = "Rescue Hover Collective", min = 0, max = 1000},
  {id = 41, name = "Rescue Hover Altitude", min = 0, max = 2500},
  {id = 42, name = "Rescue Alt P", min = 0, max = 250},
  {id = 43, name = "Rescue Alt I", min = 0, max = 250},
  {id = 44, name = "Rescue Alt D", min = 0, max = 250},
  {id = 45, name = "Angle Level Gain", min = 0, max = 200},
  {id = 46, name = "Horizon Level Gain", min = 0, max = 200},
  {id = 47, name = "Acro Trainer Gain", min = 25, max = 255},
  {id = 48, name = "Governor Gain", min = 0, max = 250},
  {id = 49, name = "Governor P", min = 0, max = 250},
  {id = 50, name = "Governor I", min = 0, max = 250},
  {id = 51, name = "Governor D", min = 0, max = 250},
  {id = 52, name = "Governor F", min = 0, max = 250},
  {id = 53, name = "Governor TTA", min = 0, max = 250},
  {id = 54, name = "Governor Cyclic FF", min = 0, max = 250},
  {id = 55, name = "Governor Collective FF", min = 0, max = 250},
  {id = 56, name = "Pitch B", min = 0, max = 250},
  {id = 57, name = "Roll B", min = 0, max = 250},
  {id = 58, name = "Yaw B", min = 0, max = 250},
  {id = 59, name = "Pitch O", min = 0, max = 250},
  {id = 60, name = "Roll O", min = 0, max = 250},
  {id = 61, name = "Cross Coupling Gain", min = 0, max = 250},
  {id = 62, name = "Cross Coupling Ratio", min = 0, max = 250},
  {id = 63, name = "Cross Coupling Cutoff", min = 0, max = 250},
  {id = 64, name = "Acc Trim Pitch", min = -300, max = 300},
  {id = 65, name = "Acc Trim Roll", min = -300, max = 300},
  {id = 66, name = "Yaw Inertia Precomp Gain", min = 0, max = 250},
  {id = 67, name = "Yaw Inertia Precomp Cutoff", min = 0, max = 250},
  {id = 68, name = "Pitch Setpoint Boost Gain", min = 0, max = 255},
  {id = 69, name = "Roll Setpoint Boost Gain", min = 0, max = 255},
  {id = 70, name = "Yaw Setpoint Boost Gain", min = 0, max = 255},
  {id = 71, name = "Collective Setpoint Boost Gain", min = 0, max = 255},
  {id = 72, name = "Yaw Dynamic Ceiling Gain", min = 0, max = 250},
  {id = 73, name = "Yaw Dynamic Deadband Gain", min = 0, max = 250},
  {id = 74, name = "Yaw Dynamic Deadband Filter", min = 0, max = 250},
  {id = 75, name = "Yaw Precomp Cutoff", min = 0, max = 250},
  {id = 76, name = "Governor Idle Throttle", min = 0, max = 250},
  {id = 77, name = "Governor Auto Throttle", min = 0, max = 250},
  {id = 78, name = "Governor Max Throttle", min = 0, max = 100},
  {id = 79, name = "Governor Min Throttle", min = 0, max = 100},
  {id = 80, name = "Governor Headspeed", min = 0, max = 10000},
  {id = 81, name = "Governor Yaw FF", min = 0, max = 250},
  {id = 82, name = "Battery Profile", min = 1, max = 6},
}

local FUNCTION_OPTIONS = {}
local FUNCTION_BY_ID = {}
for i = 1, #ADJUST_FUNCTIONS do
  FUNCTION_OPTIONS[i] = {ADJUST_FUNCTIONS[i].name, i}
  FUNCTION_BY_ID[ADJUST_FUNCTIONS[i].id] = ADJUST_FUNCTIONS[i]
end

local function clamp(value, minValue, maxValue)
  value = tonumber(value) or minValue
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function quantizeUs(value)
  return clamp(math.floor((value + (RANGE_STEP / 2)) / RANGE_STEP) * RANGE_STEP, RANGE_MIN, RANGE_MAX)
end

local function cloneRange(range)
  range = range or {}
  return {
    adjFunction = range.adjFunction or 0,
    enaChannel = range.enaChannel or 0,
    enaRange = {start = range.enaRange and range.enaRange.start or 1300, ["end"] = range.enaRange and range.enaRange["end"] or 1700},
    adjChannel = range.adjChannel or 0,
    adjRange1 = {start = range.adjRange1 and range.adjRange1.start or 1300, ["end"] = range.adjRange1 and range.adjRange1["end"] or 1700},
    adjRange2 = {start = range.adjRange2 and range.adjRange2.start or 1300, ["end"] = range.adjRange2 and range.adjRange2["end"] or 1700},
    adjMin = range.adjMin or 0,
    adjMax = range.adjMax or 100,
    adjStep = range.adjStep or 0,
  }
end

local function cloneRanges(ranges)
  local out = {}
  local count = ranges and #ranges or 0
  for i = 1, count do
    out[i] = cloneRange(ranges[i])
  end
  if #out == 0 then out[1] = cloneRange() end
  return out
end

local function sameRange(a, b)
  local function samePair(ap, bp)
    return (ap.start or 0) == (bp.start or 0) and (ap["end"] or 0) == (bp["end"] or 0)
  end
  return a.adjFunction == b.adjFunction
    and a.enaChannel == b.enaChannel
    and samePair(a.enaRange, b.enaRange)
    and a.adjChannel == b.adjChannel
    and samePair(a.adjRange1, b.adjRange1)
    and samePair(a.adjRange2, b.adjRange2)
    and a.adjMin == b.adjMin
    and a.adjMax == b.adjMax
    and a.adjStep == b.adjStep
end

local function buildAuxOptions(includeAuto, includeAlways)
  local options = {}
  if includeAuto then options[#options + 1] = {"AUTO", 1} end
  if includeAlways then options[#options + 1] = {"Always", #options + 1} end
  for i = 1, AUX_CHANNEL_COUNT do
    options[#options + 1] = {"AUX " .. tostring(i), #options + 1}
  end
  return options
end

local ENA_CHANNEL_OPTIONS = buildAuxOptions(true, true)
local ADJ_CHANNEL_OPTIONS = buildAuxOptions(true, false)

local function functionIndex(fnId)
  for i = 1, #ADJUST_FUNCTIONS do
    if ADJUST_FUNCTIONS[i].id == fnId then return i end
  end
  return 1
end

local function functionDef(fnId)
  return FUNCTION_BY_ID[fnId or 0] or {id = fnId or 0, name = "Function " .. tostring(fnId or 0), min = -32768, max = 32767}
end

local function adjustmentType(range)
  if (range.adjFunction or 0) == 0 then return 0 end
  if (range.adjStep or 0) > 0 then return 2 end
  return 1
end

local function setType(range, value)
  value = clamp(value or 0, 0, 2)
  if value == 0 then
    range.adjFunction = 0
    range.adjStep = 0
    range.adjMin = 0
    range.adjMax = 100
    return
  end
  if (range.adjFunction or 0) == 0 then range.adjFunction = 1 end
  range.adjStep = value == 2 and math.max(range.adjStep or 0, 1) or 0
  local def = functionDef(range.adjFunction)
  range.adjMin = clamp(range.adjMin or def.min, def.min, def.max)
  range.adjMax = clamp(range.adjMax or def.max, def.min, def.max)
end

local function setFunction(range, optionIndex)
  local def = ADJUST_FUNCTIONS[optionIndex or 1] or ADJUST_FUNCTIONS[1]
  range.adjFunction = def.id
  if def.id == 0 then
    range.adjStep = 0
    range.adjMin = 0
    range.adjMax = 100
  else
    range.adjMin = clamp(range.adjMin or def.min, def.min, def.max)
    range.adjMax = clamp(range.adjMax or def.max, def.min, def.max)
  end
end

local function setRangeStart(pair, value)
  local adjusted = quantizeUs(value)
  pair.start = adjusted
  if (pair["end"] or RANGE_MIN) < adjusted then pair["end"] = adjusted end
end

local function setRangeEnd(pair, value)
  local adjusted = quantizeUs(value)
  pair["end"] = adjusted
  if (pair.start or RANGE_MAX) > adjusted then pair.start = adjusted end
end

local function channelRawToUs(value)
  if type(value) ~= "number" then return nil end
  if value >= -1200 and value <= 1200 then
    return clamp(math.floor(1500 + (value * 500 / 1024) + 0.5), RANGE_MIN, RANGE_MAX)
  end
  if value >= 700 and value <= 2300 then return clamp(math.floor(value + 0.5), RANGE_MIN, RANGE_MAX) end
  return nil
end

local function open(opts)
  local disposed = false
  local headerHandle = nil
  local dialog = nil
  local loaded = false
  local busy = false
  local dirty = false
  local needsRender = false
  local selected = 1
  local ranges = {}
  local original = {}
  local dirtySlots = {}
  local channelSources = {}
  local liveFields = {}
  local autoEna = {}
  local autoAdj = {}
  local saveError = nil

  local function windowWidth()
    local w = 800
    if lcd and lcd.getWindowSize then
      local gotW = lcd.getWindowSize()
      if type(gotW) == "number" and gotW > 0 then w = gotW end
    end
    return w
  end

  local function lineMetrics(line)
    local slots = form.getFieldSlots(line, {0})
    local slot = slots and slots[1] or nil
    return (slot and slot.y) or 0, (slot and slot.h) or 38
  end

  local function closeDialog(focusFn)
    if not dialog then return end
    dialog:value(100)
    dialog:close()
    dialog = nil
    if focusFn then focusFn() elseif headerHandle then headerHandle.focusMenu() end
  end

  local function showProgress(message)
    dialog = progressDialog.open({
      title = PAGE_TITLE,
      message = message,
      speed = progressDialog.SPEED.SLOW,
    })
  end

  local function updateButtons()
    if not headerHandle then return end
    headerHandle.setSaveEnabled(loaded and dirty and not busy)
    headerHandle.setReloadEnabled(not busy)
  end

  local function markDirty(slot)
    slot = slot or selected
    dirtySlots[slot] = not sameRange(ranges[slot], original[slot])
    dirty = false
    for _, changed in pairs(dirtySlots) do
      if changed then dirty = true; break end
    end
    updateButtons()
  end

  local function getChannelSource(auxIndex)
    if not system or not system.getSource or CATEGORY_CHANNEL == nil then return nil end
    local member = 5 + clamp(auxIndex or 0, 0, AUX_CHANNEL_COUNT - 1)
    local src = channelSources[member]
    if src == nil then
      src = system.getSource({category = CATEGORY_CHANNEL, member = member, options = 0})
      channelSources[member] = src or false
    end
    if src == false then return nil end
    return src
  end

  local function getAuxUs(auxIndex)
    local src = getChannelSource(auxIndex)
    if not src or not src.value then return nil end
    return channelRawToUs(src:value())
  end

  local function detectAuto(state)
    local bestIdx, bestUs, bestDelta = nil, nil, 0
    for aux = 0, AUX_CHANNEL_COUNT - 1 do
      local us = getAuxUs(aux)
      if us then
        if not state.baseline then state.baseline = {} end
        if state.baseline[aux] == nil then
          state.baseline[aux] = us
        else
          local delta = math.abs(us - state.baseline[aux])
          if delta > bestDelta then bestIdx, bestUs, bestDelta = aux, us, delta end
        end
      end
    end
    if bestIdx ~= nil and bestDelta >= AUTODETECT_DELTA_US then return bestIdx, bestUs end
    return nil, nil
  end

  local function showInfo(message)
    form.openDialog({
      title = PAGE_TITLE,
      message = message,
      buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}},
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  local function setFromCurrent(title, range, auxIndex, autoTable)
    if autoTable[selected] then
      showInfo("@i18n(app.modules.adjustments.msg_auto_detect_lock_first)@")
      return
    end
    local us = getAuxUs(auxIndex or 0)
    if not us then
      showInfo("@i18n(app.modules.adjustments.msg_live_channel_unavailable)@")
      return
    end
    local startValue = quantizeUs(us - RANGE_SNAP_DELTA_US)
    local endValue = quantizeUs(us + RANGE_SNAP_DELTA_US)
    form.openDialog({
      title = title,
      message = "@i18n(app.modules.adjustments.confirm_use_current)@ " .. tostring(us) .. "us?\n\n"
        .. "@i18n(app.modules.adjustments.min_label)@: " .. tostring(startValue) .. "us\n"
        .. "@i18n(app.modules.adjustments.max_label)@: " .. tostring(endValue) .. "us",
      buttons = {
        {label = BTN_OK, action = function()
          range.start = startValue
          range["end"] = endValue
          markDirty()
          needsRender = true
          return true
        end},
        {label = BTN_CANCEL, action = function() return true end},
      },
      wakeup = function() end,
      paint = function() end,
      options = TEXT_LEFT,
    })
  end

  local function slotOptions()
    local out = {}
    for i = 1, #ranges do
      local label = "Range " .. tostring(i)
      if (ranges[i].adjFunction or 0) > 0 then label = label .. " - " .. functionDef(ranges[i].adjFunction).name end
      out[i] = {label, i}
    end
    return out
  end

  local function activeCount()
    local count = 0
    for i = 1, #ranges do
      if (ranges[i].adjFunction or 0) > 0 then count = count + 1 end
    end
    return count
  end

  local function channelChoiceValue(range, isEnable)
    if isEnable and range.enaChannel == ALWAYS_ON_CHANNEL then return 2 end
    if isEnable then return clamp((range.enaChannel or 0) + 3, 3, #ENA_CHANNEL_OPTIONS) end
    return clamp((range.adjChannel or 0) + 2, 2, #ADJ_CHANNEL_OPTIONS)
  end

  local render

  local function addRangeFields(label, range, auxIndex, autoTable, setTitle)
    local width = windowWidth()
    local gap = 6
    local rightPadding = FORM_RIGHT_PADDING
    local wSet = math.max(42, math.floor(width * 0.12))
    local wNum = math.floor(width * 0.17)
    local xSet = width - rightPadding - wSet
    local xEnd = xSet - gap - wNum
    local xStart = xEnd - gap - wNum
    local line = form.addLine(label)
    local y, h = lineMetrics(line)
    local startField = form.addNumberField(line, {x = xStart, y = y, w = wNum, h = h}, RANGE_MIN, RANGE_MAX,
      function() return range.start end,
      function(value) setRangeStart(range, value); markDirty() end)
    local endField = form.addNumberField(line, {x = xEnd, y = y, w = wNum, h = h}, RANGE_MIN, RANGE_MAX,
      function() return range["end"] end,
      function(value) setRangeEnd(range, value); markDirty() end)
    if startField and startField.step then startField:step(RANGE_STEP) end
    if endField and endField.step then endField:step(RANGE_STEP) end
    if startField and startField.suffix then startField:suffix("us") end
    if endField and endField.suffix then endField:suffix("us") end
    form.addButton(line, {x = xSet, y = y, w = wSet, h = h}, {
      text = "@i18n(app.modules.adjustments.set)@",
      options = FONT_S + CENTERED,
      press = function() setFromCurrent(setTitle, range, auxIndex, autoTable) end,
    })
  end

  render = function()
    liveFields = {}
    form.clear()
    headerHandle = header.build(PAGE_TITLE, {
      onBack = function()
        disposed = true
        if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
        if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
        closeDialog()
        if opts.onBack then opts.onBack() end
      end,
      onSave = function()
        if not loaded or not dirty or busy then return end
        if autoEna[selected] or autoAdj[selected] then
          showInfo("@i18n(app.modules.adjustments.msg_auto_detect_lock_save)@")
          return
        end
        form.openDialog({
          title = MSG_SAVE_TITLE,
          message = MSG_SAVE_BODY,
          buttons = {
            {label = BTN_OK, action = function()
              local changed = {}
              for slot, isDirty in pairs(dirtySlots) do
                if isDirty then changed[#changed + 1] = slot end
              end
              table.sort(changed)
              local pos = 1
              busy = true
              saveError = nil
              updateButtons()
              showProgress("@i18n(app.modules.adjustments.saving_changed_ranges)@")

              local function fail(reason)
                if disposed then return end
                busy = false
                saveError = reason or "Save failed"
                closeDialog(headerHandle and headerHandle.focusSave)
                updateButtons()
                needsRender = true
              end

              local function writeNext()
                if disposed then return end
                local slot = changed[pos]
                if not slot then
                  bus.publish("msp.request", eeprom.buildWriteMessage(function()
                    if disposed then return end
                    original = cloneRanges(ranges)
                    dirtySlots = {}
                    dirty = false
                    busy = false
                    closeDialog(headerHandle and headerHandle.focusSave)
                    updateButtons()
                    needsRender = true
                  end, fail))
                  return
                end
                pos = pos + 1
                bus.publish("msp.request", adjustmentsMsp.buildWriteMessage(slot, ranges[slot], writeNext, function()
                  fail("SET_ADJUSTMENT_RANGE failed at slot " .. tostring(slot))
                end))
              end

              writeNext()
              return true
            end},
            {label = BTN_CANCEL, action = function() return true end},
          },
          wakeup = function() end,
          paint = function() end,
          options = TEXT_LEFT,
        })
      end,
      onReload = function()
        if busy then return end
        form.openDialog({
          title = MSG_RELOAD_TITLE,
          message = MSG_RELOAD_BODY,
          buttons = {
            {label = BTN_OK, action = function()
              loaded = false
              busy = true
              dirty = false
              dirtySlots = {}
              updateButtons()
              showProgress("@i18n(app.modules.adjustments.loading_ranges)@")
              bus.publish("msp.request", adjustmentsMsp.buildReadMessage(function(data)
                if disposed then return end
                ranges = cloneRanges(data.ranges)
                original = data.ranges or {}
                loaded = true
                busy = false
                closeDialog(headerHandle and headerHandle.focusReload)
                updateButtons()
                needsRender = true
              end, function()
                if disposed then return end
                busy = false
                closeDialog(headerHandle and headerHandle.focusReload)
                updateButtons()
              end))
              return true
            end},
            {label = BTN_CANCEL, action = function() return true end},
          },
          wakeup = function() end,
          paint = function() end,
          options = TEXT_LEFT,
        })
      end,
    })
    updateButtons()

    if busy and not loaded then
      form.addLine("@i18n(app.modules.adjustments.loading_ranges_detail)@")
      return
    end

    local range = ranges[selected]
    if not range then
      form.addLine("@i18n(app.modules.adjustments.loading_ranges_detail)@")
      return
    end
    local typ = adjustmentType(range)
    local width = windowWidth()
    local gap = 6
    local rightPadding = FORM_RIGHT_PADDING
    local wChoice = math.floor(width * 0.52)
    local xChoice = width - rightPadding - wChoice
    local wLive = math.floor(width * 0.16)
    local wChannel = math.floor(width * 0.24)
    local xLive = width - rightPadding - wLive
    local xChannel = xLive - gap - wChannel
    local wNum = math.floor(width * 0.17)
    local xEnd = width - rightPadding - wNum
    local xStart = xEnd - gap - wNum

    form.addLine("@i18n(app.modules.adjustments.active_ranges)@ " .. tostring(activeCount()) .. " / " .. tostring(#ranges))
    if saveError then form.addLine("@i18n(app.modules.adjustments.save_error)@ " .. tostring(saveError)) end
    if dirty then form.addLine("@i18n(app.modules.adjustments.unsaved_changes)@") end
    if autoEna[selected] or autoAdj[selected] then form.addLine("@i18n(app.modules.adjustments.auto_detect_active_toggle)@") end

    local slotLine = form.addLine("@i18n(app.modules.adjustments.range)@")
    local y, h = lineMetrics(slotLine)
    form.addChoiceField(slotLine, {x = xChoice, y = y, w = wChoice, h = h}, slotOptions(),
      function() return selected end,
      function(value) selected = clamp(value or 1, 1, #ranges); needsRender = true end)

    local typeLine = form.addLine("@i18n(app.modules.adjustments.type)@")
    y, h = lineMetrics(typeLine)
    form.addChoiceField(typeLine, {x = xChoice, y = y, w = wChoice, h = h}, ADJUST_TYPE_OPTIONS,
      function() return typ end,
      function(value) setType(range, value); markDirty(); needsRender = true end)

    local fnLine = form.addLine("@i18n(app.modules.adjustments.function)@")
    y, h = lineMetrics(fnLine)
    form.addChoiceField(fnLine, {x = xChoice, y = y, w = wChoice, h = h}, FUNCTION_OPTIONS,
      function() return functionIndex(range.adjFunction) end,
      function(value) setFunction(range, value); markDirty(); needsRender = true end)

    local enaLine = form.addLine("@i18n(app.modules.adjustments.enable_channel)@")
    y, h = lineMetrics(enaLine)
    form.addChoiceField(enaLine, {x = xChannel, y = y, w = wChannel, h = h}, ENA_CHANNEL_OPTIONS,
      function()
        if autoEna[selected] then return 1 end
        return channelChoiceValue(range, true)
      end,
      function(value)
        if value == 1 then
          autoEna[selected] = {baseline = nil}
        elseif value == 2 then
          autoEna[selected] = nil
          range.enaChannel = ALWAYS_ON_CHANNEL
          range.enaRange.start = 1500
          range.enaRange["end"] = 1500
        else
          autoEna[selected] = nil
          range.enaChannel = clamp((value or 3) - 3, 0, AUX_CHANNEL_COUNT - 1)
        end
        markDirty()
        needsRender = true
      end)
    local enaLive = form.addStaticText(enaLine, {x = xLive, y = y, w = wLive, h = h}, "--")
    liveFields.ena = enaLive

    if range.enaChannel ~= ALWAYS_ON_CHANNEL then
      addRangeFields("@i18n(app.modules.adjustments.enable_range)@", range.enaRange, range.enaChannel, autoEna,
        "@i18n(app.modules.adjustments.set_enable_range)@")
    end

    local adjLine = form.addLine("@i18n(app.modules.adjustments.value_channel)@")
    y, h = lineMetrics(adjLine)
    form.addChoiceField(adjLine, {x = xChannel, y = y, w = wChannel, h = h}, ADJ_CHANNEL_OPTIONS,
      function()
        if autoAdj[selected] then return 1 end
        return channelChoiceValue(range, false)
      end,
      function(value)
        if value == 1 then
          autoAdj[selected] = {baseline = nil}
        else
          autoAdj[selected] = nil
          range.adjChannel = clamp((value or 2) - 2, 0, AUX_CHANNEL_COUNT - 1)
        end
        markDirty()
      end)
    local adjLive = form.addStaticText(adjLine, {x = xLive, y = y, w = wLive, h = h}, "--")
    liveFields.adj = adjLive

    if typ == 2 then
      local stepLine = form.addLine("@i18n(app.modules.adjustments.step_size)@")
      y, h = lineMetrics(stepLine)
      form.addNumberField(stepLine, {x = xEnd, y = y, w = wNum, h = h}, 0, 255,
        function() return range.adjStep end,
        function(value) range.adjStep = clamp(value, 0, 255); markDirty() end)
      addRangeFields("@i18n(app.modules.adjustments.decrease_range)@", range.adjRange1, range.adjChannel, autoAdj,
        "@i18n(app.modules.adjustments.set_decrease_range)@")
      addRangeFields("@i18n(app.modules.adjustments.increase_range)@", range.adjRange2, range.adjChannel, autoAdj,
        "@i18n(app.modules.adjustments.set_increase_range)@")
    else
      addRangeFields("@i18n(app.modules.adjustments.adjust_range)@", range.adjRange1, range.adjChannel, autoAdj,
        "@i18n(app.modules.adjustments.set_adjust_range)@")
    end

    local def = functionDef(range.adjFunction)
    local valLine = form.addLine("@i18n(app.modules.adjustments.value_range)@")
    y, h = lineMetrics(valLine)
    local minField = form.addNumberField(valLine, {x = xStart, y = y, w = wNum, h = h}, def.min, def.max,
      function() return range.adjMin end,
      function(value)
        range.adjMin = clamp(value, def.min, def.max)
        if range.adjMax < range.adjMin then range.adjMax = range.adjMin end
        markDirty()
      end)
    local maxField = form.addNumberField(valLine, {x = xEnd, y = y, w = wNum, h = h}, def.min, def.max,
      function() return range.adjMax end,
      function(value)
        range.adjMax = clamp(value, def.min, def.max)
        if range.adjMin > range.adjMax then range.adjMin = range.adjMax end
        markDirty()
      end)
    if typ == 0 then
      if minField and minField.enable then minField:enable(false) end
      if maxField and maxField.enable then maxField:enable(false) end
    end
  end

  local function updateLive()
    local range = ranges[selected]
    if not range then return end

    local enaUs = nil
    if autoEna[selected] then
      local idx, us = detectAuto(autoEna[selected])
      if idx ~= nil then
        range.enaChannel = idx
        autoEna[selected] = nil
        markDirty()
        needsRender = true
        enaUs = us
      elseif liveFields.ena and liveFields.ena.value then
        liveFields.ena:value("AUTO...")
      end
    elseif range.enaChannel == ALWAYS_ON_CHANNEL then
      enaUs = 1500
      if liveFields.ena and liveFields.ena.value then liveFields.ena:value("Always") end
    else
      enaUs = getAuxUs(range.enaChannel)
      if liveFields.ena and liveFields.ena.value then liveFields.ena:value(enaUs and (tostring(enaUs) .. "us") or "--") end
    end

    local adjUs = nil
    if autoAdj[selected] then
      local idx, us = detectAuto(autoAdj[selected])
      if idx ~= nil then
        range.adjChannel = idx
        autoAdj[selected] = nil
        markDirty()
        needsRender = true
        adjUs = us
      elseif liveFields.adj and liveFields.adj.value then
        liveFields.adj:value("AUTO...")
      end
    else
      adjUs = getAuxUs(range.adjChannel)
      if liveFields.adj and liveFields.adj.value then liveFields.adj:value(adjUs and (tostring(adjUs) .. "us") or "--") end
    end
  end

  if opts.setEventHandler then
    opts.setEventHandler(function(category, value)
      if closeKey.shouldHandleClose(category, value) then
        disposed = true
        if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
        if opts.setCleanupHandler then opts.setCleanupHandler(nil) end
        closeDialog()
        if opts.onBack then opts.onBack() end
        return true
      end
      return false
    end)
  end

  if opts.setCleanupHandler then
    opts.setCleanupHandler(function()
      disposed = true
      if opts.setWakeupHandler then opts.setWakeupHandler(nil) end
      closeDialog()
    end)
  end

  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if disposed then return end
      if needsRender then
        render()
        needsRender = false
      end
      updateButtons()
      if loaded and not busy then updateLive() end
    end)
  end

  busy = true
  form.clear()
  render()
  showProgress("@i18n(app.modules.adjustments.loading_ranges)@")
  bus.publish("msp.request", adjustmentsMsp.buildReadMessage(function(data)
    if disposed then return end
    ranges = cloneRanges(data.ranges)
    original = data.ranges or {}
    loaded = true
    busy = false
    closeDialog()
    updateButtons()
    needsRender = true
  end, function()
    if disposed then return end
    busy = false
    closeDialog()
    updateButtons()
  end))
end

return {open = open}
