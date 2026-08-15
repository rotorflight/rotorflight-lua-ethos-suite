-- Controls -> Modes.
--
-- Custom editor for BOXIDS/BOXNAMES/MODE_RANGES/MODE_RANGES_EXTRA. This
-- intentionally stays page-local instead of using page_runtime: it has a
-- four-step read, full-slot sequential writes, and wakeup-driven live AUX
-- pulse display/auto-detect behavior.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local closeKey = requireModule("app/close_key.lua")
local header = requireModule("app/header.lua")
local eeprom = requireModule("lib/msp_eeprom.lua")
local progressDialog = requireModule("app/progress_dialog.lua")
local mspModes = requireModule("lib/msp_modes.lua")

local PAGE_TITLE = "@i18n(app.modules.modes.name)@"
local BTN_ADD = "@i18n(app.btn_add)@"
local BTN_OK = "@i18n(app.btn_ok_long)@"
local BTN_CANCEL = "@i18n(app.btn_cancel)@"
local MSG_SAVE_TITLE = "@i18n(app.msg_save_settings)@"
local MSG_SAVE_BODY = "@i18n(app.msg_save_current_page)@"
local MSG_RELOAD_TITLE = "@i18n(reload)@"
local MSG_RELOAD_BODY = "@i18n(app.msg_reload_settings)@"
local MSG_LOADING_TITLE = "@i18n(app.modules.modes.name)@"
local MSG_LOADING_BODY = "@i18n(app.modules.modes.loading_config)@"
local MSG_SAVING_BODY = "@i18n(app.modules.modes.saving_config)@"

local MODE_LOGIC_OPTIONS = {{"OR", 0}, {"AND", 1}}
local MODE_NAME_BY_ID = {
  [0] = "ARM",
  [1] = "ANGLE",
  [2] = "HORIZON",
  [3] = "ALTHOLD",
  [13] = "BEEPER",
  [15] = "LEDLOW",
  [17] = "CALIB",
  [19] = "OSD DISABLE",
  [20] = "TELEMETRY",
  [26] = "BLACKBOX",
  [27] = "FAILSAFE",
  [31] = "BLACKBOX ERASE",
  [32] = "CAMERA CONTROL 1",
  [33] = "CAMERA CONTROL 2",
  [34] = "CAMERA CONTROL 3",
  [36] = "PREARM",
  [37] = "GPS BEEP SATELLITE COUNT",
  [39] = "VTX PIT MODE",
  [40] = "USER1",
  [41] = "USER2",
  [42] = "USER3",
  [43] = "USER4",
  [45] = "PARALYZE",
  [46] = "GPS RESCUE",
  [47] = "TRAINER",
  [48] = "VTX CONTROL DISABLE",
  [51] = "STICK COMMANDS DISABLE",
  [52] = "BEEPER MUTE",
  [53] = "RESCUE",
  [55] = "GOVERNOR FALLBACK",
  [56] = "GOVERNOR SUSPEND",
  [57] = "GOVERNOR BYPASS",
}
local AUX_CHANNEL_COUNT = 20
local RANGE_MIN = 875
local RANGE_MAX = 2125
local RANGE_STEP = 5
local RANGE_SNAP_DELTA_US = 50
local FORM_RIGHT_PADDING = 10

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
  local values = range.range or {}
  return {
    id = range.id or 0,
    auxChannelIndex = range.auxChannelIndex or 0,
    range = {
      start = values.start or 900,
      ["end"] = values["end"] or 900,
    },
  }
end

local function cloneExtra(extra)
  extra = extra or {}
  return {
    id = extra.id or 0,
    modeLogic = extra.modeLogic or 0,
    linkedTo = extra.linkedTo or 0,
  }
end

local function cloneRanges(ranges)
  local out = {}
  for i = 1, #(ranges or {}) do out[i] = cloneRange(ranges[i]) end
  return out
end

local function cloneExtras(extras)
  local out = {}
  for i = 1, #(extras or {}) do out[i] = cloneExtra(extras[i]) end
  return out
end

local function rangesEqual(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    local ar, br = a[i], b[i]
    local av, bv = ar.range or {}, br.range or {}
    if ar.id ~= br.id or ar.auxChannelIndex ~= br.auxChannelIndex
      or av.start ~= bv.start or av["end"] ~= bv["end"] then
      return false
    end
  end
  return true
end

local function extrasEqual(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    local ae, be = a[i], b[i]
    if ae.id ~= be.id or ae.modeLogic ~= be.modeLogic or ae.linkedTo ~= be.linkedTo then
      return false
    end
  end
  return true
end

local function buildAuxOptions()
  local options = {{"AUTO", 1}}
  for i = 1, AUX_CHANNEL_COUNT do
    options[#options + 1] = {"AUX " .. tostring(i), i + 1}
  end
  return options
end

local AUX_OPTIONS = buildAuxOptions()

local function channelRawToUs(value)
  if type(value) ~= "number" then return nil end
  if value >= -1200 and value <= 1200 then
    return clamp(math.floor(1500 + (value * 500 / 1024) + 0.5), RANGE_MIN, RANGE_MAX)
  end
  if value >= 700 and value <= 2300 then
    return clamp(math.floor(value + 0.5), RANGE_MIN, RANGE_MAX)
  end
  return nil
end

local function auxIndexToMember(auxIndex)
  return 5 + clamp(auxIndex or 0, 0, AUX_CHANNEL_COUNT - 1)
end

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

local function showInfo(title, message)
  form.openDialog({
    title = title,
    message = message,
    buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}},
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })
end

local function open(opts)
  local disposed = false
  local headerHandle = nil
  local dialog = nil
  local loaded = false
  local loading = false
  local saving = false
  local dirty = false
  local loadError = nil
  local saveError = nil
  local needsRender = false
  local modeNames = {}
  local modeIds = {}
  local modeRanges = {}
  local modeRangesExtra = {}
  local originalRanges = {}
  local originalExtras = {}
  local modes = {}
  local selectedModeIndex = 1
  local liveRangeFields = {}
  local channelSources = {}
  local autoDetectSlots = {}

  local function closeDialog(focusFn)
    if not dialog then return end
    dialog:value(100)
    dialog:close()
    dialog = nil
    if focusFn then
      focusFn()
    elseif headerHandle then
      headerHandle.focusMenu()
    end
  end

  local function showProgress(message)
    dialog = progressDialog.open({
      title = MSG_LOADING_TITLE,
      message = message,
      speed = progressDialog.SPEED.SLOW,
    })
  end

  local function setBusy()
    if headerHandle then
      headerHandle.setSaveEnabled(loaded and dirty and not loading and not saving)
      headerHandle.setReloadEnabled(not saving)
    end
  end

  local function markDirty()
    dirty = not rangesEqual(modeRanges, originalRanges) or not extrasEqual(modeRangesExtra, originalExtras)
    setBusy()
  end

  local function buildModesFromRaw()
    modes = {}
    local idToModeIndex = {}
    local count = math.max(#modeIds, #modeNames)

    if count == 0 and #modeRanges > 0 then
      local seen = {}
      for i = 1, #modeRanges do
        local id = modeRanges[i] and modeRanges[i].id
        if id and id > 0 and not seen[id] then
          seen[id] = true
          modeIds[#modeIds + 1] = id
        end
      end
      table.sort(modeIds)
      count = #modeIds
    end

    for i = 1, count do
      local id = modeIds[i]
      if id == nil then id = i - 1 end
      local name = modeNames[i]
      if (not name or name == "") and MODE_NAME_BY_ID[id] then name = MODE_NAME_BY_ID[id] end
      if not name or name == "" then name = "Mode " .. tostring(id) end
      modes[i] = {id = id, name = name, ranges = {}}
      idToModeIndex[id] = i
    end

    for slot = 1, #modeRanges do
      local range = modeRanges[slot]
      local extra = modeRangesExtra[slot] or {id = 0, modeLogic = 0, linkedTo = 0}
      local modeIndex = range and idToModeIndex[range.id] or nil
      local values = range and range.range or nil
      if modeIndex and (extra.linkedTo or 0) == 0 and values
        and (values.start or 0) < (values["end"] or 0) then
        modes[modeIndex].ranges[#modes[modeIndex].ranges + 1] = {
          slot = slot,
          auxChannelIndex = range.auxChannelIndex or 0,
          range = {
            start = clamp(values.start or RANGE_MIN, RANGE_MIN, RANGE_MAX),
            ["end"] = clamp(values["end"] or RANGE_MAX, RANGE_MIN, RANGE_MAX),
          },
          modeLogic = extra.modeLogic or 0,
        }
      end
    end

    selectedModeIndex = clamp(selectedModeIndex, 1, math.max(#modes, 1))
  end

  local function getSelectedMode()
    if #modes == 0 then return nil end
    return modes[selectedModeIndex]
  end

  local function getChannelSource(member)
    if not system or not system.getSource or CATEGORY_CHANNEL == nil then return nil end
    local src = channelSources[member]
    if src == nil then
      src = system.getSource({category = CATEGORY_CHANNEL, member = member, options = 0})
      channelSources[member] = src or false
    end
    if src == false then return nil end
    return src
  end

  local function getAuxPulseUs(auxIndex)
    local src = getChannelSource(auxIndexToMember(auxIndex))
    if not src or not src.value then return nil end
    return channelRawToUs(src:value())
  end

  local function hasActiveAutoDetect()
    for _, value in pairs(autoDetectSlots) do
      if value ~= nil then return true end
    end
    return false
  end

  local render

  local function setLoadError(reason)
    loading = false
    loaded = false
    loadError = reason or "Load failed"
    closeDialog()
    needsRender = true
    setBusy()
  end

  local function loadData(focusFn)
    if disposed then return end
    loading = true
    loaded = false
    dirty = false
    loadError = nil
    saveError = nil
    modeNames = {}
    modeIds = {}
    modeRanges = {}
    modeRangesExtra = {}
    originalRanges = {}
    originalExtras = {}
    autoDetectSlots = {}
    channelSources = {}
    setBusy()
    showProgress(MSG_LOADING_BODY)

    local function readExtras()
      bus.publish("msp.request", mspModes.buildModeRangesExtraReadMessage(function(data)
        if disposed then return end
        modeRangesExtra = cloneExtras(data)
        for i = #modeRangesExtra + 1, #modeRanges do
          modeRangesExtra[i] = {id = 0, modeLogic = 0, linkedTo = 0}
        end
        originalRanges = cloneRanges(modeRanges)
        originalExtras = cloneExtras(modeRangesExtra)
        buildModesFromRaw()
        loading = false
        loaded = true
        dirty = false
        closeDialog(focusFn)
        needsRender = true
        setBusy()
      end, function() setLoadError("Failed reading mode range extras") end))
    end

    local function readRanges()
      bus.publish("msp.request", mspModes.buildModeRangesReadMessage(function(data)
        if disposed then return end
        modeRanges = cloneRanges(data)
        readExtras()
      end, function() setLoadError("Failed reading mode ranges") end))
    end

    local function readNames()
      bus.publish("msp.request", mspModes.buildBoxNamesReadMessage(function(data)
        if disposed then return end
        modeNames = data or {}
        readRanges()
      end, function() setLoadError("Failed reading mode names") end))
    end

    bus.publish("msp.request", mspModes.buildBoxIdsReadMessage(function(data)
      if disposed then return end
      modeIds = data or {}
      readNames()
    end, function() setLoadError("Failed reading mode IDs") end))
  end

  local function removeRangeSlot(slot)
    if not slot then return end
    modeRanges[slot] = {id = 0, auxChannelIndex = 0, range = {start = 900, ["end"] = 900}}
    modeRangesExtra[slot] = {id = 0, modeLogic = 0, linkedTo = 0}
    autoDetectSlots[slot] = nil
    buildModesFromRaw()
    markDirty()
    needsRender = true
  end

  local function addRangeToSelectedMode()
    local mode = getSelectedMode()
    if not mode then return end

    local freeSlot = nil
    for i = 1, #modeRanges do
      local range = modeRanges[i]
      local values = range and range.range or {}
      if (range.id or 0) == 0 and (values.start or 0) >= (values["end"] or 0) then
        freeSlot = i
        break
      end
    end

    if not freeSlot then
      showInfo(PAGE_TITLE, "@i18n(app.modules.modes.msg_no_free_slots)@")
      return
    end

    modeRanges[freeSlot] = {
      id = mode.id,
      auxChannelIndex = 0,
      range = {start = 1300, ["end"] = 1700},
    }
    modeRangesExtra[freeSlot] = {id = mode.id, modeLogic = 0, linkedTo = 0}
    buildModesFromRaw()
    markDirty()
    needsRender = true
  end

  local function addModeRangeLine(rangeIndex, modeRange)
    local slot = modeRange.slot
    local rawRange = slot and modeRanges[slot] or nil
    local rawExtra = slot and modeRangesExtra[slot] or nil
    if not rawRange or not rawExtra or not rawRange.range then return end

    local width = windowWidth()
    local rightPadding = FORM_RIGHT_PADDING
    local gap = 6
    local wSet = math.max(42, math.floor(width * 0.12))
    local wLive = math.floor(width * 0.22)
    local xSet = width - rightPadding - wSet
    local xLive = xSet - gap - wLive

    local lineTop = form.addLine("@i18n(app.modules.modes.range)@ " .. tostring(rangeIndex), nil, false)
    local topY, topH = lineMetrics(lineTop)
    local liveText = form.addStaticText(lineTop, {x = xLive, y = topY, w = wLive, h = topH}, "--")
    if liveText and liveText.value then liveRangeFields[slot] = liveText end

    form.addButton(lineTop, {x = xSet, y = topY, w = wSet, h = topH}, {
      text = "@i18n(app.modules.modes.set)@",
      options = FONT_S + CENTERED,
      press = function()
        if autoDetectSlots[slot] then
          showInfo(PAGE_TITLE, "@i18n(app.modules.modes.msg_auto_detect_lock_first)@")
          return
        end

        local us = getAuxPulseUs(rawRange.auxChannelIndex or 0)
        if not us then
          showInfo(PAGE_TITLE, "@i18n(app.modules.modes.msg_live_channel_unavailable)@")
          return
        end

        local targetStart = quantizeUs(us - RANGE_SNAP_DELTA_US)
        local targetEnd = quantizeUs(us + RANGE_SNAP_DELTA_US)
        form.openDialog({
          title = "@i18n(app.modules.modes.set_range_title)@",
          message = "@i18n(app.modules.modes.msg_use_current)@ " .. tostring(us) .. "us?\n\n"
            .. "@i18n(app.modules.modes.min_label)@: " .. tostring(targetStart) .. "us\n"
            .. "@i18n(app.modules.modes.max_label)@: " .. tostring(targetEnd) .. "us",
          buttons = {
            {label = BTN_OK, action = function()
              rawRange.range.start = targetStart
              rawRange.range["end"] = targetEnd
              buildModesFromRaw()
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
      end,
    })

    local wDel = math.max(28, math.floor(width * 0.07))
    local wAux = math.floor(width * 0.22)
    local wLogic = math.floor(width * 0.12)
    local wNum = math.floor(width * 0.17)
    local xDel = width - rightPadding - wDel
    local xEnd = xDel - gap - wNum
    local xStart = xEnd - gap - wNum
    local xLogic = xStart - gap - wLogic
    local xAux = xLogic - gap - wAux

    local lineBottom = form.addLine(" ", nil, true)
    local bottomY, bottomH = lineMetrics(lineBottom)

    form.addChoiceField(lineBottom, {x = xAux, y = bottomY, w = wAux, h = bottomH}, AUX_OPTIONS,
      function()
        if autoDetectSlots[slot] then return 1 end
        return clamp((rawRange.auxChannelIndex or 0) + 2, 2, #AUX_OPTIONS)
      end,
      function(value)
        if value == 1 then
          autoDetectSlots[slot] = {baseline = nil}
        else
          autoDetectSlots[slot] = nil
          rawRange.auxChannelIndex = clamp((value or 2) - 2, 0, AUX_CHANNEL_COUNT - 1)
        end
        markDirty()
      end)

    form.addChoiceField(lineBottom, {x = xLogic, y = bottomY, w = wLogic, h = bottomH}, MODE_LOGIC_OPTIONS,
      function() return clamp(rawExtra.modeLogic or 0, 0, 1) end,
      function(value)
        rawExtra.modeLogic = clamp(value or 0, 0, 1)
        markDirty()
      end)

    local startField = form.addNumberField(lineBottom, {x = xStart, y = bottomY, w = wNum, h = bottomH}, RANGE_MIN, RANGE_MAX,
      function() return rawRange.range.start end,
      function(value)
        local adjusted = quantizeUs(value)
        rawRange.range.start = adjusted
        if rawRange.range["end"] < adjusted then rawRange.range["end"] = adjusted end
        buildModesFromRaw()
        markDirty()
      end)

    local endField = form.addNumberField(lineBottom, {x = xEnd, y = bottomY, w = wNum, h = bottomH}, RANGE_MIN, RANGE_MAX,
      function() return rawRange.range["end"] end,
      function(value)
        local adjusted = quantizeUs(value)
        rawRange.range["end"] = adjusted
        if rawRange.range.start > adjusted then rawRange.range.start = adjusted end
        buildModesFromRaw()
        markDirty()
      end)

    if startField and startField.suffix then startField:suffix("us") end
    if endField and endField.suffix then endField:suffix("us") end
    if startField and startField.step then startField:step(RANGE_STEP) end
    if endField and endField.step then endField:step(RANGE_STEP) end

    form.addButton(lineBottom, {x = xDel, y = bottomY, w = wDel, h = bottomH}, {
      text = "X",
      options = FONT_S + CENTERED,
      press = function() removeRangeSlot(slot) end,
    })
  end

  render = function()
    liveRangeFields = {}
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
        if not loaded or loading or saving or not dirty then return end
        if hasActiveAutoDetect() then
          showInfo(PAGE_TITLE, "@i18n(app.modules.modes.msg_auto_detect_lock_save)@")
          return
        end
        form.openDialog({
          title = MSG_SAVE_TITLE,
          message = MSG_SAVE_BODY,
          buttons = {
            {label = BTN_OK, action = function()
              local slot = 1
              local total = #modeRanges
              saving = true
              saveError = nil
              setBusy()
              showProgress(MSG_SAVING_BODY)

              local function fail(reason)
                if disposed then return end
                saving = false
                saveError = reason or "Save failed"
                closeDialog(headerHandle and headerHandle.focusSave)
                needsRender = true
                setBusy()
              end

              local function writeNext()
                if disposed then return end
                if slot > total then
                  bus.publish("msp.request", eeprom.buildWriteMessage(function()
                    if disposed then return end
                    originalRanges = cloneRanges(modeRanges)
                    originalExtras = cloneExtras(modeRangesExtra)
                    dirty = false
                    saving = false
                    closeDialog(headerHandle and headerHandle.focusSave)
                    needsRender = true
                    setBusy()
                  end, fail))
                  return
                end
                local writeSlot = slot
                slot = slot + 1
                bus.publish("msp.request", mspModes.buildSetModeRangeMessage(
                  writeSlot,
                  modeRanges[writeSlot],
                  modeRangesExtra[writeSlot],
                  writeNext,
                  function() fail("SET_MODE_RANGE failed at slot " .. tostring(writeSlot)) end))
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
        if saving then return end
        form.openDialog({
          title = MSG_RELOAD_TITLE,
          message = MSG_RELOAD_BODY,
          buttons = {
            {label = BTN_OK, action = function() loadData(headerHandle and headerHandle.focusReload); return true end},
            {label = BTN_CANCEL, action = function() return true end},
          },
          wakeup = function() end,
          paint = function() end,
          options = TEXT_LEFT,
        })
      end,
    })
    setBusy()

    if loading then
      form.addLine("@i18n(app.modules.modes.loading)@")
      return
    end
    if loadError then
      form.addLine("@i18n(app.modules.modes.load_error)@ " .. tostring(loadError))
      return
    end
    if #modes == 0 then
      form.addLine("@i18n(app.modules.modes.no_modes)@")
      return
    end

    local width = windowWidth()
    local rightPadding = FORM_RIGHT_PADDING
    local modeOptions = {}
    for i = 1, #modes do modeOptions[i] = {modes[i].name, i} end

    local modeLine = form.addLine("@i18n(app.modules.modes.mode)@")
    local modeY, modeH = lineMetrics(modeLine)
    form.addChoiceField(modeLine, {x = math.floor(width * 0.44), y = modeY, w = math.floor(width * 0.55) - rightPadding, h = modeH}, modeOptions,
      function() return selectedModeIndex end,
      function(value)
        selectedModeIndex = clamp(value or 1, 1, #modes)
        buildModesFromRaw()
        needsRender = true
      end)

    local selectedMode = getSelectedMode()
    local ranges = selectedMode and selectedMode.ranges or {}
    local infoLine = form.addLine("@i18n(app.modules.modes.active_ranges)@ " .. tostring(#ranges) .. " / " .. tostring(#modeRanges))
    local infoY, infoH = lineMetrics(infoLine)
    if dirty then
      local statusW = math.floor(width * 0.30)
      local statusX = width - rightPadding - statusW
      local statusBtn = form.addButton(infoLine, {x = statusX, y = infoY, w = statusW, h = infoH}, {
        text = "@i18n(app.modules.modes.unsaved_changes)@",
        options = FONT_S + CENTERED,
        press = function() end,
      })
      if statusBtn and statusBtn.enable then statusBtn:enable(false) end
    end
    if hasActiveAutoDetect() then form.addLine("@i18n(app.modules.modes.auto_detect_active)@") end
    if saveError then form.addLine("@i18n(app.modules.modes.save_error)@ " .. tostring(saveError)) end

    local actionLine = form.addLine("")
    local actionY, actionH = lineMetrics(actionLine)
    local buttonW = math.floor(width * 0.22)
    form.addButton(actionLine, {x = width - rightPadding - buttonW, y = actionY, w = buttonW, h = actionH}, {
      text = BTN_ADD,
      options = FONT_S + CENTERED,
      press = addRangeToSelectedMode,
    })

    if #ranges == 0 then
      form.addLine("@i18n(app.modules.modes.no_ranges)@")
      return
    end

    for i = 1, #ranges do addModeRangeLine(i, ranges[i]) end
  end

  local function updateLiveRangeFields()
    for slot, field in pairs(liveRangeFields) do
      local range = modeRanges[slot]
      if field and field.value and range and range.range then
        local autoState = autoDetectSlots[slot]
        if autoState then
          local bestIdx, bestUs = nil, nil
          local bestDelta = 0
          for auxIdx = 0, AUX_CHANNEL_COUNT - 1 do
            local us = getAuxPulseUs(auxIdx)
            if us then
              if not autoState.baseline then autoState.baseline = {} end
              if autoState.baseline[auxIdx] == nil then
                autoState.baseline[auxIdx] = us
              else
                local delta = math.abs(us - autoState.baseline[auxIdx])
                if delta > bestDelta then
                  bestDelta = delta
                  bestIdx = auxIdx
                  bestUs = us
                end
              end
            end
          end
          if bestIdx ~= nil and bestDelta >= 120 then
            range.auxChannelIndex = bestIdx
            autoDetectSlots[slot] = nil
            markDirty()
            needsRender = true
            field:value("AUX " .. tostring(bestIdx + 1) .. ": " .. tostring(bestUs or 0) .. "us")
          else
            field:value("AUTO...")
          end
        else
          local us = getAuxPulseUs(range.auxChannelIndex or 0)
          if us then
            local inRange = us >= (range.range.start or RANGE_MIN) and us <= (range.range["end"] or RANGE_MAX)
            local text = tostring(us) .. "us"
            if inRange then text = text .. " *" end
            field:value(text)
          else
            field:value("--")
          end
        end
      elseif field and field.value then
        field:value("--")
      end
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
      closeDialog()
    end)
  end

  if opts.setWakeupHandler then
    opts.setWakeupHandler(function()
      if needsRender then
        render()
        needsRender = false
      end
      setBusy()
      if loaded and not loading and not saving then updateLiveRangeFields() end
    end)
  end

  form.clear()
  render()
  loadData()
end

return {open = open}
