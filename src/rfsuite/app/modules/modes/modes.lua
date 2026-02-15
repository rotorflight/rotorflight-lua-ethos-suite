--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MODE_LOGIC_OPTIONS = {"OR", "AND"}
local AUX_CHANNEL_COUNT_FALLBACK = 20
local RANGE_MIN = 875
local RANGE_MAX = 2125
local RANGE_STEP = 5
local RANGE_SNAP_DELTA_US = 50
local MODULE_LOADER_SPEED = 0.05

local state = {
    title = "Modes",
    modeNames = {},
    modeIds = {},
    modeRanges = {},
    modeRangesExtra = {},
    modes = {},
    selectedModeIndex = 1,
    loaded = false,
    loading = false,
    saving = false,
    dirty = false,
    loadError = nil,
    saveError = nil,
    needsRender = false,
    liveRangeFields = {},
    channelSources = {},
    autoDetectSlots = {}
}

local function queueDirect(message, uuid)
    if message and uuid and message.uuid == nil then message.uuid = uuid end
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function toS8Byte(value)
    local v = clamp(math.floor(value + 0.5), -128, 127)
    if v < 0 then return v + 256 end
    return v
end

local function quantizeUs(value)
    return clamp(math.floor((value + (RANGE_STEP / 2)) / RANGE_STEP) * RANGE_STEP, RANGE_MIN, RANGE_MAX)
end

local function channelRawToUs(value)
    if value == nil then return nil end

    -- Ethos channel sources are typically -1024..1024.
    if value >= -1200 and value <= 1200 then
        return clamp(math.floor(1500 + (value * 500 / 1024) + 0.5), RANGE_MIN, RANGE_MAX)
    end

    -- Fallback if a source already reports pulse width style values.
    if value >= 700 and value <= 2300 then
        return clamp(math.floor(value + 0.5), RANGE_MIN, RANGE_MAX)
    end

    return nil
end

local function auxIndexToMember(auxIndex)
    local idx = clamp(auxIndex or 0, 0, AUX_CHANNEL_COUNT_FALLBACK - 1)
    local rx = rfsuite.session and rfsuite.session.rx
    local map = rx and rx.map or nil

    if map then
        if idx == 0 and map.aux1 ~= nil then return map.aux1 end
        if idx == 1 and map.aux2 ~= nil then return map.aux2 end
        if idx == 2 and map.aux3 ~= nil then return map.aux3 end
    end

    local base = 5
    if map and map.aux1 ~= nil then base = map.aux1 end
    return base + idx
end

local function getChannelSource(member)
    local src = state.channelSources[member]
    if src == nil then
        src = system.getSource({category = CATEGORY_CHANNEL, member = member, options = 0})
        state.channelSources[member] = src or false
    end
    if src == false then return nil end
    return src
end

local function getAuxPulseUs(auxIndex)
    local member = auxIndexToMember(auxIndex)
    local src = getChannelSource(member)
    if not src then return nil end
    local raw = src:value()
    if raw == nil or type(raw) ~= "number" then return nil end
    return channelRawToUs(raw)
end

local function buildAuxOptions()
    local options = {"AUTO"}
    for i = 1, AUX_CHANNEL_COUNT_FALLBACK do
        options[#options + 1] = "AUX " .. tostring(i)
    end
    return options
end

local AUX_OPTIONS = buildAuxOptions()

local function buildChoiceTable(values, inc)
    local out = {}
    inc = inc or 0
    for i = 1, #values do
        out[i] = {values[i], i + inc}
    end
    return out
end

local AUX_OPTIONS_TBL = buildChoiceTable(AUX_OPTIONS, 0)
local MODE_LOGIC_OPTIONS_TBL = buildChoiceTable(MODE_LOGIC_OPTIONS, -1)

local function canSave()
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    local requireDirty = not (pref == false or pref == "false")
    return state.loaded and (not state.loading) and (not state.saving) and ((not requireDirty) or state.dirty)
end

local function updateSaveButtonState()
    local nav = rfsuite.app and rfsuite.app.formNavigationFields
    local saveField = nav and nav["save"] or nil
    if not saveField then return end
    if saveField.enable then
        saveField:enable(canSave())
    end
end

local function syncNavButtonsForState()
    local page = rfsuite.app and rfsuite.app.Page
    if not page then return end
    page.navButtons = {menu = true, save = true, reload = true, tool = false, help = true}
end

-- Forward declaration: used by helpers defined before the function body.
local buildModesFromRaw

local function removeRangeSlot(slot)
    if not slot then return end

    state.modeRanges[slot] = {
        id = 0,
        auxChannelIndex = 0,
        range = {start = 900, ["end"] = 900}
    }
    state.modeRangesExtra[slot] = {
        id = 0,
        modeLogic = 0,
        linkedTo = 0
    }
    state.autoDetectSlots[slot] = nil

    state.dirty = true
    buildModesFromRaw()
    state.needsRender = true
end

local function addModeRangeLine(rangeIndex, modeRange)
    local app = rfsuite.app
    local slot = modeRange.slot
    local rawRange = slot and state.modeRanges[slot] or nil
    local rawExtra = slot and state.modeRangesExtra[slot] or nil
    if not rawRange or not rawExtra or not rawRange.range then return end

    local width = app.lcdWidth
    local h = app.radio.navbuttonHeight
    local y = app.radio.linePaddingTop

    local rightPadding = 8
    local gap = 6

    -- Line 1: range label + live pulse + Set action
    local wSet = math.max(34, math.floor(width * 0.14))
    local wLive = math.floor(width * 0.24)
    local xSet = width - rightPadding - wSet
    local xLive = xSet - gap - wLive

    -- Keep the two rows visually grouped: no separator after header row,
    -- separator after controls row.
    local lineTop = form.addLine("Range " .. tostring(rangeIndex), nil, false)
    local liveText = form.addStaticText(lineTop, {x = xLive, y = y, w = wLive, h = h}, "--")
    if liveText and liveText.value then state.liveRangeFields[slot] = liveText end

    form.addButton(lineTop, {x = xSet, y = y, w = wSet, h = h}, {
        text = "Set",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function()
            if state.autoDetectSlots[slot] then
                local buttons = {{label = "OK", action = function() return true end}}
                form.openDialog({
                    width = nil,
                    title = "Modes",
                    message = "Auto-detect is active for this row. Toggle to lock AUX first.",
                    buttons = buttons,
                    wakeup = function() end,
                    paint = function() end,
                    options = TEXT_LEFT
                })
                return
            end

            local us = getAuxPulseUs(rawRange.auxChannelIndex or 0)
            if not us then
                local buttons = {{label = "OK", action = function() return true end}}
                form.openDialog({
                    width = nil,
                    title = "Modes",
                    message = "Live channel value unavailable.",
                    buttons = buttons,
                    wakeup = function() end,
                    paint = function() end,
                    options = TEXT_LEFT
                })
                return
            end

            local targetStart = quantizeUs(us - RANGE_SNAP_DELTA_US)
            local targetEnd = quantizeUs(us + RANGE_SNAP_DELTA_US)
            if targetStart > targetEnd then
                local mid = quantizeUs(us)
                targetStart = mid
                targetEnd = mid
            end

            local buttons = {
                {
                    label = "@i18n(app.btn_ok_long)@",
                    action = function()
                        rawRange.range.start = targetStart
                        rawRange.range["end"] = targetEnd
                        state.dirty = true
                        state.needsRender = true
                        return true
                    end
                },
                {label = "@i18n(app.btn_cancel)@", action = function() return true end}
            }

            form.openDialog({
                width = nil,
                title = "Set Range",
                message = "Use current value " .. tostring(us) .. "us?\n\nMin: " .. tostring(targetStart) .. "us\nMax: " .. tostring(targetEnd) .. "us",
                buttons = buttons,
                wakeup = function() end,
                paint = function() end,
                options = TEXT_LEFT
            })
        end
    })

    -- Line 2: all controls (AUX + logic + start/end + delete)
    local wDel = math.max(24, math.floor(width * 0.08))
    local wAux = math.floor(width * 0.23)
    local wLogic = math.floor(width * 0.14)
    local wNum = math.floor(width * 0.17)

    local xDel = width - rightPadding - wDel
    local xEnd = xDel - gap - wNum
    local xStart = xEnd - gap - wNum
    local xLogic = xStart - gap - wLogic
    local xAux = xLogic - gap - wAux

    local lineBottom = form.addLine(" ", nil, true)

    local auxField = form.addChoiceField(
        lineBottom,
        {x = xAux, y = y, w = wAux, h = h},
        AUX_OPTIONS_TBL,
        function()
            if state.autoDetectSlots[slot] then return 1 end
            return clamp((rawRange.auxChannelIndex or 0) + 2, 2, #AUX_OPTIONS)
        end,
        function(value)
            if value == 1 then
                state.autoDetectSlots[slot] = {baseline = nil}
            else
                state.autoDetectSlots[slot] = nil
                rawRange.auxChannelIndex = clamp((value or 2) - 2, 0, AUX_CHANNEL_COUNT_FALLBACK - 1)
            end
            state.dirty = true
        end
    )

    local logicField = form.addChoiceField(
        lineBottom,
        {x = xLogic, y = y, w = wLogic, h = h},
        MODE_LOGIC_OPTIONS_TBL,
        function() return clamp(rawExtra.modeLogic or 0, 0, #MODE_LOGIC_OPTIONS - 1) end,
        function(value)
            rawExtra.modeLogic = clamp(value or 0, 0, 1)
            state.dirty = true
        end
    )

    local startField = form.addNumberField(
        lineBottom,
        {x = xStart, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return rawRange.range.start end,
        function(value)
            local adjusted = clamp(math.floor(value / RANGE_STEP) * RANGE_STEP, RANGE_MIN, RANGE_MAX)
            rawRange.range.start = adjusted
            if rawRange.range["end"] < adjusted then rawRange.range["end"] = adjusted end
            state.dirty = true
        end
    )

    local endField = form.addNumberField(
        lineBottom,
        {x = xEnd, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return rawRange.range["end"] end,
        function(value)
            local adjusted = clamp(math.floor(value / RANGE_STEP) * RANGE_STEP, RANGE_MIN, RANGE_MAX)
            rawRange.range["end"] = adjusted
            if rawRange.range.start > adjusted then rawRange.range.start = adjusted end
            state.dirty = true
        end
    )

    if startField and startField.suffix then startField:suffix("us") end
    if endField and endField.suffix then endField:suffix("us") end
    if startField and startField.step then startField:step(RANGE_STEP) end
    if endField and endField.step then endField:step(RANGE_STEP) end

    if logicField and logicField.enable then logicField:enable(true) end
    if auxField and auxField.enable then auxField:enable(true) end

    form.addButton(lineBottom, {x = xDel, y = y, w = wDel, h = h}, {
        text = "X",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function()
            removeRangeSlot(modeRange.slot)
        end
    })
end

buildModesFromRaw = function()
    state.modes = {}
    local idToModeIndex = {}

    local count = math.max(#state.modeIds, #state.modeNames)
    if count == 0 and #state.modeRanges > 0 then
        -- Last-resort fallback: derive list from mode ids found in mode ranges.
        local seen = {}
        for i = 1, #state.modeRanges do
            local id = state.modeRanges[i] and state.modeRanges[i].id
            if id and id > 0 and not seen[id] then
                seen[id] = true
                state.modeIds[#state.modeIds + 1] = id
            end
        end
        table.sort(state.modeIds)
        count = #state.modeIds
    end

    for i = 1, count do
        local id = state.modeIds[i]
        if id == nil then id = i - 1 end
        local name = state.modeNames[i]
        if not name or name == "" then name = "Mode " .. tostring(id) end

        state.modes[i] = {
            id = id,
            name = name,
            ranges = {}
        }
        idToModeIndex[id] = i
    end

    for slot = 1, #state.modeRanges do
        local range = state.modeRanges[slot]
        local extra = state.modeRangesExtra[slot] or {id = 0, modeLogic = 0, linkedTo = 0}
        local modeIndex = idToModeIndex[range.id]

        if modeIndex and (extra.linkedTo or 0) == 0 and range.range and (range.range.start or 0) < (range.range["end"] or 0) then
            state.modes[modeIndex].ranges[#state.modes[modeIndex].ranges + 1] = {
                slot = slot,
                auxChannelIndex = range.auxChannelIndex or 0,
                range = {
                    start = clamp(range.range.start or RANGE_MIN, RANGE_MIN, RANGE_MAX),
                    ["end"] = clamp(range.range["end"] or RANGE_MAX, RANGE_MIN, RANGE_MAX)
                },
                modeLogic = extra.modeLogic or 0
            }
        end
    end

    state.selectedModeIndex = clamp(state.selectedModeIndex, 1, math.max(#state.modes, 1))
end

local function setLoadError(reason)
    state.loading = false
    state.loaded = false
    state.loadError = reason or "Load failed"
    state.needsRender = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function readModeRangesExtra()
    local API = rfsuite.tasks.msp.api.load("MODE_RANGES_EXTRA")
    if not API then
        setLoadError("MODE_RANGES_EXTRA API unavailable")
        return
    end

    API.setCompleteHandler(function()
        state.modeRangesExtra = API.readValue("mode_ranges_extra") or {}
        state.loading = false
        state.loaded = true
        state.dirty = false
        state.loadError = nil
        buildModesFromRaw()
        state.needsRender = true
        rfsuite.app.triggers.closeProgressLoader = true
    end)

    API.setErrorHandler(function()
        setLoadError("Failed reading mode range extras")
    end)

    API.read()
end

local function readModeRanges()
    local API = rfsuite.tasks.msp.api.load("MODE_RANGES")
    if not API then
        setLoadError("MODE_RANGES API unavailable")
        return
    end

    API.setCompleteHandler(function()
        state.modeRanges = API.readValue("mode_ranges") or {}
        readModeRangesExtra()
    end)

    API.setErrorHandler(function()
        setLoadError("Failed reading mode ranges")
    end)

    API.read()
end

local function readBoxNames()
    local API = rfsuite.tasks.msp.api.load("BOXNAMES")
    if not API then
        setLoadError("BOXNAMES API unavailable")
        return
    end

    API.setCompleteHandler(function()
        state.modeNames = API.readValue("box_names") or {}
        readModeRanges()
    end)

    API.setErrorHandler(function()
        setLoadError("Failed reading mode names")
    end)

    API.read()
end

local function readBoxIds()
    local API = rfsuite.tasks.msp.api.load("BOXIDS")
    if not API then
        setLoadError("BOXIDS API unavailable")
        return
    end

    API.setCompleteHandler(function()
        state.modeIds = API.readValue("box_ids") or {}
        readBoxNames()
    end)

    API.setErrorHandler(function()
        setLoadError("Failed reading mode IDs")
    end)

    API.read()
end

local function startLoad()
    state.loading = true
    state.loaded = false
    state.loadError = nil
    state.saveError = nil
    state.autoDetectSlots = {}
    state.channelSources = {}
    state.needsRender = true
    local page = rfsuite.app and rfsuite.app.Page or nil
    local speed = page and tonumber(page.loaderspeed) or MODULE_LOADER_SPEED
    rfsuite.app.ui.progressDisplay("Modes", "Loading mode configuration", speed)
    readBoxIds()
end

local function hasActiveAutoDetect()
    for _, v in pairs(state.autoDetectSlots) do
        if v ~= nil then return true end
    end
    return false
end

local function getSelectedMode()
    if #state.modes == 0 then return nil end
    return state.modes[state.selectedModeIndex]
end

local function addRangeToSelectedMode()
    local mode = getSelectedMode()
    if not mode then return end

    local freeSlot = nil
    for i = 1, #state.modeRanges do
        local range = state.modeRanges[i]
        if (range.id or 0) == 0 and range.range and (range.range.start or 0) >= (range.range["end"] or 0) then
            freeSlot = i
            break
        end
    end

    if not freeSlot then
        local buttons = {{label = "OK", action = function() return true end}}
        form.openDialog({
            width = nil,
            title = "Modes",
            message = "No free mode slots remain. Delete an existing range first.",
            buttons = buttons,
            wakeup = function() end,
            paint = function() end,
            options = TEXT_LEFT
        })
        return
    end

    state.modeRanges[freeSlot] = {
        id = mode.id,
        auxChannelIndex = 0,
        range = {start = 1300, ["end"] = 1700}
    }
    state.modeRangesExtra[freeSlot] = {
        id = mode.id,
        modeLogic = (#mode.ranges > 0) and 0 or 0,
        linkedTo = 0
    }

    state.dirty = true
    buildModesFromRaw()
    state.needsRender = true
end

local function render()
    local app = rfsuite.app
    state.liveRangeFields = {}
    syncNavButtonsForState()
    form.clear()
    app.ui.fieldHeader(state.title)

    if state.loading then
        form.addLine("Loading mode data...")
        return
    end

    if state.loadError then
        form.addLine("Load error: " .. tostring(state.loadError))
        return
    end

    if #state.modes == 0 then
        form.addLine("No modes reported by FC.")
        return
    end

    local width = app.lcdWidth
    local h = app.radio.navbuttonHeight
    local y = app.radio.linePaddingTop
    local rightPadding = 8
    local buttonW = math.floor(width * 0.24)
    local buttonH = h

    local modeOptions = {}
    for i = 1, #state.modes do
        modeOptions[#modeOptions + 1] = state.modes[i].name
    end
    local modeOptionsTbl = buildChoiceTable(modeOptions, 0)

    local modeLine = form.addLine("Mode")
    local modeChoice = form.addChoiceField(
        modeLine,
        {x = width - rightPadding - math.floor(width * 0.5), y = y, w = math.floor(width * 0.5), h = h},
        modeOptionsTbl,
        function() return state.selectedModeIndex end,
        function(value)
            state.selectedModeIndex = clamp(value or 1, 1, #state.modes)
            buildModesFromRaw()
            state.needsRender = true
        end
    )
    if modeChoice and modeChoice.values then modeChoice:values(modeOptionsTbl) end
    if modeChoice and modeChoice.enable then modeChoice:enable(true) end

    local selectedMode = getSelectedMode()
    local ranges = selectedMode and selectedMode.ranges or {}
    local infoLine = form.addLine("Active ranges: " .. tostring(#ranges) .. " / " .. tostring(#state.modeRanges))
    if state.dirty then
        local statusW = math.floor(width * 0.32)
        local statusX = width - rightPadding - statusW
        local statusBtn = form.addButton(infoLine, {x = statusX, y = y, w = statusW, h = h}, {
            text = "Unsaved changes",
            icon = nil,
            options = FONT_S,
            paint = function() end,
            press = function() end
        })
        if statusBtn and statusBtn.enable then statusBtn:enable(false) end
    end
    if hasActiveAutoDetect() then form.addLine("Auto-detect active: toggle desired AUX channel") end
    if state.saveError then form.addLine("Save error: " .. tostring(state.saveError)) end

    local actionLine = form.addLine("")
    local addBtn = form.addButton(actionLine, {x = width - rightPadding - buttonW, y = y, w = buttonW, h = buttonH}, {
        text = "Add",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function() addRangeToSelectedMode() end
    })
    if addBtn and addBtn.enable then addBtn:enable(true) end

    if #ranges == 0 then
        form.addLine("No ranges configured for this mode.")
        return
    end

    for i = 1, #ranges do addModeRangeLine(i, ranges[i]) end
end

local function updateLiveRangeFields()
    if not state.liveRangeFields then return end

    for slot, field in pairs(state.liveRangeFields) do
        if field and field.value then
            local range = state.modeRanges[slot]
            if range and range.range then
                local autoState = state.autoDetectSlots[slot]
                if autoState then
                    local bestIdx = nil
                    local bestDelta = 0
                    local bestUs = nil

                    for auxIdx = 0, AUX_CHANNEL_COUNT_FALLBACK - 1 do
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

                    -- Detect a deliberate toggle and lock AUX channel.
                    if bestIdx ~= nil and bestDelta >= 120 then
                        range.auxChannelIndex = bestIdx
                        state.autoDetectSlots[slot] = nil
                        state.dirty = true
                        state.needsRender = true
                        field:value("AUX " .. tostring(bestIdx + 1) .. ": " .. tostring(bestUs or 0) .. "us")
                    else
                        field:value("AUTO...")
                    end
                else
                    local us = getAuxPulseUs(range.auxChannelIndex or 0)
                    if us then
                        local inRange = us >= (range.range.start or RANGE_MIN) and us <= (range.range["end"] or RANGE_MAX)
                        local txt = tostring(us) .. "us"
                        if inRange then txt = txt .. " *" end
                        field:value(txt)
                    else
                        field:value("--")
                    end
                end
            else
                field:value("--")
            end
        end
    end
end

local function queueSetModeRange(slotIndex, done, failed)
    local range = state.modeRanges[slotIndex] or {id = 0, auxChannelIndex = 0, range = {start = 900, ["end"] = 900}}
    local extra = state.modeRangesExtra[slotIndex] or {id = 0, modeLogic = 0, linkedTo = 0}

    local startStep = clamp((range.range.start - 1500) / 5, -125, 125)
    local endStep = clamp((range.range["end"] - 1500) / 5, -125, 125)
    local payload = {
        slotIndex - 1,
        clamp(range.id or 0, 0, 255),
        clamp(range.auxChannelIndex or 0, 0, 255),
        toS8Byte(startStep),
        toS8Byte(endStep),
        clamp(extra.modeLogic or 0, 0, 1),
        clamp(extra.linkedTo or 0, 0, 255)
    }

    local message = {
        command = 35,
        payload = payload,
        processReply = function() if done then done() end end,
        errorHandler = function() if failed then failed("SET_MODE_RANGE failed at slot " .. tostring(slotIndex)) end end,
        simulatorResponse = {}
    }
    local ok, reason = queueDirect(message, string.format("modes.slot.%d", slotIndex))
    if not ok and failed then failed(reason or "queue_rejected") end
end

local function queueEepromWrite(done, failed)
    local message = {
        command = 250,
        processReply = function() if done then done() end end,
        errorHandler = function() if failed then failed("EEPROM write failed") end end,
        simulatorResponse = {}
    }
    local ok, reason = queueDirect(message, "modes.eeprom")
    if not ok and failed then failed(reason or "queue_rejected") end
end

local function saveAllRanges()
    state.saving = true
    state.saveError = nil
    rfsuite.app.ui.progressDisplay("Modes", "Saving mode configuration")

    local slot = 1
    local total = #state.modeRanges

    local function failed(reason)
        state.saving = false
        state.saveError = reason or "Save failed"
        state.needsRender = true
        rfsuite.app.triggers.closeProgressLoader = true
    end

    local function writeNext()
        if slot > total then
            queueEepromWrite(function()
                state.saving = false
                state.dirty = false
                state.saveError = nil
                state.needsRender = true
                rfsuite.app.triggers.closeProgressLoader = true
            end, failed)
            return
        end

        queueSetModeRange(slot, function()
            slot = slot + 1
            writeNext()
        end, failed)
    end

    writeNext()
end

local function onSaveMenu()
    if state.loading or state.saving or not state.loaded then return end
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    local requireDirty = not (pref == false or pref == "false")
    if requireDirty and (not state.dirty) then return end

    if hasActiveAutoDetect() then
        local buttons = {{label = "OK", action = function() return true end}}
        form.openDialog({
            width = nil,
            title = "Modes",
            message = "Auto-detect is active. Toggle the desired AUX channel first.",
            buttons = buttons,
            wakeup = function() end,
            paint = function() end,
            options = TEXT_LEFT
        })
        return
    end

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        saveAllRanges()
        return
    end

    local buttons = {
        {label = "@i18n(app.btn_ok_long)@", action = function() saveAllRanges(); return true end},
        {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }
    form.openDialog({
        width = nil,
        title = "@i18n(app.msg_save_settings)@",
        message = "@i18n(app.msg_save_current_page)@",
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
end

local function onReloadMenu()
    if state.saving then return end
    startLoad()
end

local function onNavMenu()
    rfsuite.app.ui.openMainMenuSub("hardware")
    return true
end

local function wakeup()
    if state.needsRender then
        render()
        state.needsRender = false
    end
    updateSaveButtonState()
    if not state.loaded or state.loading then return end
    if state.saving then return end
    updateLiveRangeFields()
end

local function openPage(opts)
    local idx = opts.idx
    state.title = opts.title or "Modes"

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = state.title
    rfsuite.app.lastScript = opts.script
    rfsuite.session.lastPage = opts.script

    startLoad()
    state.needsRender = true
end

return {
    title = "Modes",
    openPage = openPage,
    wakeup = wakeup,
    onSaveMenu = onSaveMenu,
    onReloadMenu = onReloadMenu,
    onNavMenu = onNavMenu,
    eepromWrite = false,
    reboot = false,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = true},
    API = {}
}
