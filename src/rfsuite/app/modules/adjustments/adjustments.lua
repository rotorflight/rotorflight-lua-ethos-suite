--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local ADJUST_TYPE_OPTIONS = {
    "@i18n(app.modules.adjustments.type_off)@",
    "@i18n(app.modules.adjustments.type_mapped)@",
    "@i18n(app.modules.adjustments.type_stepped)@"
}
local MODULE_TITLE = "@i18n(app.modules.adjustments.name)@"
local ALWAYS_ON_CHANNEL = 255
local AUX_CHANNEL_COUNT_FALLBACK = 20

local RANGE_MIN = 875
local RANGE_MAX = 2125
local RANGE_STEP = 5
local RANGE_SNAP_DELTA_US = 50
local AUTODETECT_DELTA_US = 120

local ADJ_STEP_MIN = 0
local ADJ_STEP_MAX = 255
local ADJUSTMENT_RANGE_MAX = 42
local ADJUSTMENT_RANGE_DEFAULT_COUNT = 42
local MSP_FUNCTION_NAME_PREFETCH_MIN_API = "12.09"

-- gate the prefetch call until its in the firmware
local USE_MSP_FUNCTION_NAME_PREFETCH = false

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
    {id = 30, name = "Yaw Collective Dyn", min = -125, max = 125, maxApi = "12.07"},
    {id = 31, name = "Yaw Collective Decay", min = 1, max = 250, maxApi = "12.07"},
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
    {id = 66, name = "Yaw Inertia Precomp Gain", min = 0, max = 250, minApi = "12.08"},
    {id = 67, name = "Yaw Inertia Precomp Cutoff", min = 0, max = 250, minApi = "12.08"},
    {id = 68, name = "Pitch Setpoint Boost Gain", min = 0, max = 255, minApi = "12.08"},
    {id = 69, name = "Roll Setpoint Boost Gain", min = 0, max = 255, minApi = "12.08"},
    {id = 70, name = "Yaw Setpoint Boost Gain", min = 0, max = 255, minApi = "12.08"},
    {id = 71, name = "Col Setpoint Boost Gain", min = 0, max = 255, minApi = "12.08"},
    {id = 72, name = "Yaw Dyn Ceiling Gain", min = 0, max = 250, minApi = "12.08"},
    {id = 73, name = "Yaw Dyn Deadband Gain", min = 0, max = 250, minApi = "12.08"},
    {id = 74, name = "Yaw Dyn Deadband Filter", min = 0, max = 250, minApi = "12.08"},
    {id = 75, name = "Yaw Precomp Cutoff", min = 0, max = 250, minApi = "12.08"},
    {id = 76, name = "Gov Idle Throttle", min = 0, max = 250, minApi = "12.09"},
    {id = 77, name = "Gov Auto Throttle", min = 0, max = 250, minApi = "12.09"},
    {id = 78, name = "Gov Max Throttle", min = 0, max = 100, minApi = "12.09"},
    {id = 79, name = "Gov Min Throttle", min = 0, max = 100, minApi = "12.09"},
    {id = 80, name = "Gov Headspeed", min = 0, max = 10000, minApi = "12.09"},
    {id = 81, name = "Gov Yaw FF", min = 0, max = 250, minApi = "12.09"}
}

local state = {
    title = MODULE_TITLE,
    adjustmentRanges = {},
    selectedRangeIndex = 1,
    loaded = false,
    loading = false,
    saving = false,
    readFallbackLocked = false,
    dirty = false,
    loadError = nil,
    saveError = nil,
    infoMessage = nil,
    needsRender = false,
    pendingFocusKey = nil,
    channelSources = {},
    liveFields = {},
    autoDetectEnaSlots = {},
    autoDetectAdjSlots = {},
    functionById = {},
    functionOptions = {},
    functionOptionIds = {},
    dirtySlots = {},
    loadedSlots = {},
    pendingSlotLoads = {},
    supportsAdjustmentFunctions = nil,
    showFunctionNamesInRangeSelector = false
}

local function setPendingFocus(key)
    state.pendingFocusKey = key
end

local function restorePendingFocus(focusTargets)
    local key = state.pendingFocusKey
    if not key then return end
    state.pendingFocusKey = nil

    local target = focusTargets and focusTargets[key] or nil
    if target and target.focus then target:focus() end
end

local function queueDirect(message, uuid)
    if message and uuid and message.uuid == nil then message.uuid = uuid end
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function quantizeUs(value)
    return clamp(math.floor((value + (RANGE_STEP / 2)) / RANGE_STEP) * RANGE_STEP, RANGE_MIN, RANGE_MAX)
end

local function setUsRangeStart(rangeTable, value)
    local adjusted = quantizeUs(value)
    local currentEnd = quantizeUs((rangeTable and rangeTable["end"]) or RANGE_MAX)

    if adjusted <= currentEnd then
        rangeTable.start = adjusted
        rangeTable["end"] = currentEnd
    else
        rangeTable.start = currentEnd
        rangeTable["end"] = adjusted
    end
end

local function setUsRangeEnd(rangeTable, value)
    local adjusted = quantizeUs(value)
    local currentStart = quantizeUs((rangeTable and rangeTable.start) or RANGE_MIN)

    if adjusted >= currentStart then
        rangeTable.start = currentStart
        rangeTable["end"] = adjusted
    else
        rangeTable.start = adjusted
        rangeTable["end"] = currentStart
    end
end

local function toS8Byte(value)
    local v = clamp(math.floor(value + 0.5), -128, 127)
    if v < 0 then return v + 256 end
    return v
end

local function toS16Bytes(value)
    local v = clamp(math.floor(value + 0.5), -32768, 32767)
    if v < 0 then v = v + 65536 end
    return v % 256, math.floor(v / 256)
end

local function channelRawToUs(value)
    if value == nil then return nil end

    if value >= -1200 and value <= 1200 then
        return clamp(math.floor(1500 + (value * 500 / 1024) + 0.5), RANGE_MIN, RANGE_MAX)
    end

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

local function hasActiveAutoDetect()
    for _, v in pairs(state.autoDetectEnaSlots) do
        if v ~= nil then return true end
    end
    for _, v in pairs(state.autoDetectAdjSlots) do
        if v ~= nil then return true end
    end
    return false
end

local function functionVisible(def)
    if def.minApi and not rfsuite.utils.apiVersionCompare(">=", def.minApi) then return false end
    if def.maxApi and not rfsuite.utils.apiVersionCompare("<=", def.maxApi) then return false end
    return true
end

local function buildFunctionOptions(currentId)
    local entries = {}
    local byId = {}

    for i = 1, #ADJUST_FUNCTIONS do
        local def = ADJUST_FUNCTIONS[i]
        if functionVisible(def) then
            entries[#entries + 1] = {name = def.name, id = def.id}
            byId[def.id] = def
        end
    end

    if currentId ~= nil and byId[currentId] == nil then
        local fallback = {id = currentId, name = "@i18n(app.modules.adjustments.function_label)@ " .. tostring(currentId), min = -32768, max = 32767}
        entries[#entries + 1] = {name = fallback.name, id = fallback.id}
        byId[currentId] = fallback
    end

    table.sort(entries, function(a, b) return a.id < b.id end)

    local options = {}
    local optionIds = {}
    for i = 1, #entries do
        options[i] = {entries[i].name, i}
        optionIds[i] = entries[i].id
    end

    state.functionById = byId
    state.functionOptions = options
    state.functionOptionIds = optionIds
end

local function getFunctionById(id)
    local def = state.functionById[id]
    if def then return def end

    for i = 1, #ADJUST_FUNCTIONS do
        local item = ADJUST_FUNCTIONS[i]
        if item.id == id then return item end
    end

    return nil
end

local function getFunctionDisplayName(fnId)
    local fn = getFunctionById(math.floor(fnId or 0))
    if fn and fn.name then return fn.name end
    return "@i18n(app.modules.adjustments.function_label)@ " .. tostring(math.floor(fnId or 0))
end

local function getFunctionChoiceIndex(fnId)
    for i = 1, #state.functionOptionIds do
        if state.functionOptionIds[i] == fnId then return i end
    end
    return 1
end

local function buildChoiceTable(values, inc)
    local out = {}
    inc = inc or 0
    for i = 1, #values do
        out[i] = {values[i], i + inc}
    end
    return out
end

local function hasAssignedFunction(adjRange)
    if type(adjRange) ~= "table" then return false end
    return math.floor(adjRange.adjFunction or 0) > 0
end

local function buildRangeSlotLabel(slotIndex, adjRange)
    local label = "@i18n(app.modules.adjustments.range)@ " .. tostring(slotIndex)
    if not state.showFunctionNamesInRangeSelector then return label end
    if not hasAssignedFunction(adjRange) then return label end

    local fnId = math.floor(adjRange.adjFunction or 0)
    local fnName = getFunctionDisplayName(fnId)
    return label .. " - " .. fnName
end

local function buildRangeSlotOptions()
    local values = {}
    for i = 1, #state.adjustmentRanges do
        values[#values + 1] = buildRangeSlotLabel(i, state.adjustmentRanges[i])
    end
    return buildChoiceTable(values, 0)
end

local function refreshRangeSlotOptions()
    local slotChoice = state.liveFields and state.liveFields.slotChoice
    if slotChoice and slotChoice.values then
        slotChoice:values(buildRangeSlotOptions())
    end
end

local function buildAuxOptions(includeAuto, includeAlways)
    local options = {}
    if includeAuto then options[#options + 1] = "@i18n(app.modules.adjustments.channel_auto)@" end
    if includeAlways then options[#options + 1] = "@i18n(app.modules.adjustments.channel_always)@" end
    for i = 1, AUX_CHANNEL_COUNT_FALLBACK do
        options[#options + 1] = "@i18n(app.modules.adjustments.channel_aux_prefix)@" .. tostring(i)
    end
    return options
end

local ADJUST_TYPE_OPTIONS_TBL = buildChoiceTable(ADJUST_TYPE_OPTIONS, -1)
local ADJ_CHANNEL_OPTIONS = buildAuxOptions(true, false)
local ENA_CHANNEL_OPTIONS = buildAuxOptions(true, true)
local ADJ_CHANNEL_OPTIONS_TBL = buildChoiceTable(ADJ_CHANNEL_OPTIONS, 0)
local ENA_CHANNEL_OPTIONS_TBL = buildChoiceTable(ENA_CHANNEL_OPTIONS, 0)

local function getAdjustmentType(adjRange)
    if (adjRange.adjFunction or 0) == 0 then return 0 end
    if (adjRange.adjStep or 0) > 0 then return 2 end
    return 1
end

local function normalizeRangePair(rangeTable)
    local startValue = RANGE_MIN
    local endValue = RANGE_MAX

    if type(rangeTable) == "table" then
        startValue = rangeTable.start or startValue
        endValue = rangeTable["end"] or endValue
    end

    local normalized = {
        start = quantizeUs(startValue),
        ["end"] = quantizeUs(endValue)
    }
    if normalized.start > normalized["end"] then normalized["end"] = normalized.start end
    return normalized
end

local function sanitizeAdjustmentRange(adjRange)
    if type(adjRange) ~= "table" then adjRange = {} end

    adjRange.adjFunction = clamp(math.floor(adjRange.adjFunction or 0), 0, 255)
    adjRange.enaChannel = clamp(math.floor(adjRange.enaChannel or 0), 0, 255)
    adjRange.adjChannel = clamp(math.floor(adjRange.adjChannel or 0), 0, 255)
    adjRange.adjStep = clamp(math.floor(adjRange.adjStep or 0), ADJ_STEP_MIN, ADJ_STEP_MAX)

    adjRange.enaRange = normalizeRangePair(adjRange.enaRange)
    adjRange.adjRange1 = normalizeRangePair(adjRange.adjRange1)
    adjRange.adjRange2 = normalizeRangePair(adjRange.adjRange2)

    local cfg = getFunctionById(adjRange.adjFunction)
    if (adjRange.adjFunction or 0) == 0 then
        adjRange.adjMin = 0
        adjRange.adjMax = 100
        adjRange.adjStep = 0
    else
        local minLimit = cfg and cfg.min or -32768
        local maxLimit = cfg and cfg.max or 32767

        adjRange.adjMin = clamp(math.floor(adjRange.adjMin or minLimit), minLimit, maxLimit)
        adjRange.adjMax = clamp(math.floor(adjRange.adjMax or maxLimit), minLimit, maxLimit)
        if adjRange.adjMin > adjRange.adjMax then adjRange.adjMax = adjRange.adjMin end
    end

    if adjRange.enaChannel == ALWAYS_ON_CHANNEL then
        adjRange.enaRange.start = 1500
        adjRange.enaRange["end"] = 1500
    end

    return adjRange
end

local function limitAdjustmentRanges(raw)
    if type(raw) ~= "table" then return {} end

    local out = {}
    for i = 1, ADJUSTMENT_RANGE_MAX do
        local item = raw[i]
        if item == nil then break end
        out[i] = item
    end
    return out
end

local function newDefaultAdjustmentRange()
    return {
        adjFunction = 0,
        enaChannel = 0,
        enaRange = {start = 1300, ["end"] = 1700},
        adjChannel = 0,
        adjRange1 = {start = 1300, ["end"] = 1700},
        adjRange2 = {start = 1300, ["end"] = 1700},
        adjMin = 0,
        adjMax = 100,
        adjStep = 0
    }
end

local function buildDefaultAdjustmentRanges(count)
    local total = clamp(math.floor(count or ADJUSTMENT_RANGE_DEFAULT_COUNT), 1, ADJUSTMENT_RANGE_MAX)
    local ranges = {}
    for i = 1, total do
        ranges[i] = newDefaultAdjustmentRange()
    end
    return ranges
end

local function ensureRangeStructure(adjRange)
    if type(adjRange.enaRange) ~= "table" then adjRange.enaRange = {} end
    if type(adjRange.adjRange1) ~= "table" then adjRange.adjRange1 = {} end
    if type(adjRange.adjRange2) ~= "table" then adjRange.adjRange2 = {} end

    if adjRange.enaRange.start == nil then adjRange.enaRange.start = RANGE_MIN end
    if adjRange.enaRange["end"] == nil then adjRange.enaRange["end"] = RANGE_MAX end
    if adjRange.adjRange1.start == nil then adjRange.adjRange1.start = RANGE_MIN end
    if adjRange.adjRange1["end"] == nil then adjRange.adjRange1["end"] = RANGE_MAX end
    if adjRange.adjRange2.start == nil then adjRange.adjRange2.start = RANGE_MIN end
    if adjRange.adjRange2["end"] == nil then adjRange.adjRange2["end"] = RANGE_MAX end

    if adjRange.adjFunction == nil then adjRange.adjFunction = 0 end
    if adjRange.enaChannel == nil then adjRange.enaChannel = 0 end
    if adjRange.adjChannel == nil then adjRange.adjChannel = 0 end
    if adjRange.adjMin == nil then adjRange.adjMin = 0 end
    if adjRange.adjMax == nil then adjRange.adjMax = 100 end
    if adjRange.adjStep == nil then adjRange.adjStep = 0 end

    return adjRange
end

local function getSelectedRange()
    if #state.adjustmentRanges == 0 then return nil end
    local idx = clamp(state.selectedRangeIndex, 1, #state.adjustmentRanges)
    local adjRange = state.adjustmentRanges[idx]
    if type(adjRange) ~= "table" then
        adjRange = {}
        state.adjustmentRanges[idx] = adjRange
    end
    return ensureRangeStructure(adjRange)
end

local function markDirty(slotIndex)
    state.dirty = true
    local idx = slotIndex or state.selectedRangeIndex
    if idx == nil then return end
    idx = clamp(math.floor(idx), 1, math.max(#state.adjustmentRanges, 1))
    state.dirtySlots[idx] = true
end

local function getChangedSlots()
    local changedSlots = {}
    for slotIndex, isDirty in pairs(state.dirtySlots or {}) do
        if isDirty == true then
            local idx = tonumber(slotIndex)
            if idx and idx >= 1 and idx <= #state.adjustmentRanges then
                changedSlots[#changedSlots + 1] = idx
            end
        end
    end
    table.sort(changedSlots)
    return changedSlots
end

local function updateSaveButtonState()
    local nav = rfsuite.app and rfsuite.app.formNavigationFields
    local saveField = nav and nav["save"] or nil
    if not saveField or not saveField.enable then return end

    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    local requireDirty = not (pref == false or pref == "false")
    local canSave = state.loaded and (not state.loading) and (not state.saving) and (not state.readFallbackLocked) and ((not requireDirty) or state.dirty)
    saveField:enable(canSave)
end

local function syncNavButtonsForState()
    local page = rfsuite.app and rfsuite.app.Page
    if not page then return end

    if state.readFallbackLocked then
        page.navButtons = {menu = true, save = false, reload = true, tool = false, help = false}
    else
        page.navButtons = {menu = true, save = true, reload = true, tool = false, help = true}
    end
end

local function countActiveRanges()
    local used = 0
    for i = 1, #state.adjustmentRanges do
        if hasAssignedFunction(state.adjustmentRanges[i]) then used = used + 1 end
    end
    return used
end

local function setLoadError(reason)
    state.loading = false
    state.loaded = false
    state.loadError = reason or "Load failed"
    state.needsRender = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function parseAdjustmentRangeRecord(buf)
    if type(buf) ~= "table" then return nil end
    buf.offset = 1

    local adjFunction = rfsuite.tasks.msp.mspHelper.readU8(buf)
    if adjFunction == nil then return nil end

    local enaChannel = rfsuite.tasks.msp.mspHelper.readU8(buf)
    local enaStartStep = rfsuite.tasks.msp.mspHelper.readS8(buf)
    local enaEndStep = rfsuite.tasks.msp.mspHelper.readS8(buf)
    local adjChannel = rfsuite.tasks.msp.mspHelper.readU8(buf)
    local adjRange1StartStep = rfsuite.tasks.msp.mspHelper.readS8(buf)
    local adjRange1EndStep = rfsuite.tasks.msp.mspHelper.readS8(buf)
    local adjRange2StartStep = rfsuite.tasks.msp.mspHelper.readS8(buf)
    local adjRange2EndStep = rfsuite.tasks.msp.mspHelper.readS8(buf)
    local adjMin = rfsuite.tasks.msp.mspHelper.readS16(buf)
    local adjMax = rfsuite.tasks.msp.mspHelper.readS16(buf)
    local adjStep = rfsuite.tasks.msp.mspHelper.readU8(buf)

    if enaChannel == nil or enaStartStep == nil or enaEndStep == nil or adjChannel == nil or adjRange1StartStep == nil or
        adjRange1EndStep == nil or adjRange2StartStep == nil or adjRange2EndStep == nil or adjMin == nil or adjMax == nil or adjStep == nil then
        return nil
    end

    return {
        adjFunction = adjFunction,
        enaChannel = enaChannel,
        enaRange = {
            start = 1500 + (enaStartStep * 5),
            ["end"] = 1500 + (enaEndStep * 5)
        },
        adjChannel = adjChannel,
        adjRange1 = {
            start = 1500 + (adjRange1StartStep * 5),
            ["end"] = 1500 + (adjRange1EndStep * 5)
        },
        adjRange2 = {
            start = 1500 + (adjRange2StartStep * 5),
            ["end"] = 1500 + (adjRange2EndStep * 5)
        },
        adjMin = adjMin,
        adjMax = adjMax,
        adjStep = adjStep
    }
end

local function readAdjustmentRangeSlot(slotIndex, onComplete, onError)
    slotIndex = clamp(math.floor(slotIndex or 1), 1, ADJUSTMENT_RANGE_MAX)

    local message = {
        command = 156,
        payload = {slotIndex - 1},
        processReply = function(_, buf)
            local parsed = parseAdjustmentRangeRecord(buf)
            if not parsed then
                if onError then onError("GET_ADJUSTMENT_RANGE parse failed at slot " .. tostring(slotIndex)) end
                return
            end
            if onComplete then onComplete(parsed) end
        end,
        errorHandler = function()
            if onError then onError("GET_ADJUSTMENT_RANGE failed at slot " .. tostring(slotIndex)) end
        end,
        simulatorResponse = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, 0, 0}
    }

    local ok, reason = queueDirect(message, string.format("adjustments.get.%d", slotIndex))
    if not ok and onError then onError(reason or "queue_rejected") end
end

local function requestSlotLoad(slotIndex, onComplete, onError)
    slotIndex = clamp(math.floor(slotIndex or 1), 1, math.max(#state.adjustmentRanges, 1))

    if state.loadedSlots[slotIndex] then
        if onComplete then onComplete(state.adjustmentRanges[slotIndex]) end
        return
    end

    if state.pendingSlotLoads[slotIndex] then return end
    state.pendingSlotLoads[slotIndex] = true

    local function clearPending()
        state.pendingSlotLoads[slotIndex] = nil
    end

    readAdjustmentRangeSlot(slotIndex, function(parsed)
        clearPending()
        if not state.dirtySlots[slotIndex] then
            state.adjustmentRanges[slotIndex] = sanitizeAdjustmentRange(parsed)
        end
        state.loadedSlots[slotIndex] = true
        if onComplete then onComplete(state.adjustmentRanges[slotIndex]) end
    end, function(reason)
        clearPending()
        if onError then onError(reason) end
    end)
end

local function readAdjustmentFunctions(onComplete, onError)
    if state.supportsAdjustmentFunctions == false then
        if onError then onError("GET_ADJUSTMENT_FUNCTION_IDS unsupported") end
        return
    end

    local API = rfsuite.tasks.msp.api.load("GET_ADJUSTMENT_FUNCTION_IDS")
    if not API then
        state.supportsAdjustmentFunctions = false
        if onError then onError("GET_ADJUSTMENT_FUNCTION_IDS API unavailable") end
        return
    end

    API.setCompleteHandler(function()
        state.supportsAdjustmentFunctions = true
        local values = API.readValue("adjustment_function_ids") or {}
        if onComplete then onComplete(values) end
    end)

    API.setErrorHandler(function()
        state.supportsAdjustmentFunctions = false
        if onError then onError("GET_ADJUSTMENT_FUNCTION_IDS read failed") end
    end)

    API.read()
end

local function shouldUseMspFunctionNamePrefetch()
    if not USE_MSP_FUNCTION_NAME_PREFETCH then return false end
    return rfsuite.utils.apiVersionCompare(">=", MSP_FUNCTION_NAME_PREFETCH_MIN_API)
end

local function applyAdjustmentFunctions(functions)
    if type(functions) ~= "table" then return end
    local maxSlots = math.min(#state.adjustmentRanges, ADJUSTMENT_RANGE_MAX)
    for slotIndex = 1, maxSlots do
        local fnId = functions[slotIndex]
        if fnId ~= nil and not state.dirtySlots[slotIndex] then
            local adjRange = ensureRangeStructure(state.adjustmentRanges[slotIndex] or newDefaultAdjustmentRange())
            adjRange.adjFunction = clamp(math.floor(fnId), 0, 255)
            state.adjustmentRanges[slotIndex] = adjRange
        end
    end
end

local function readAdjustmentRangesBulk(onComplete, onError)
    local API = rfsuite.tasks.msp.api.load("ADJUSTMENT_RANGES")
    if not API then
        if onError then onError("ADJUSTMENT_RANGES API unavailable") end
        return
    end

    API.setCompleteHandler(function()
        local ranges = limitAdjustmentRanges(API.readValue("adjustment_ranges"))
        if onComplete then onComplete(ranges) end
    end)

    API.setErrorHandler(function()
        if onError then onError("ADJUSTMENT_RANGES read failed") end
    end)

    API.read()
end

local function readAdjustmentRanges()
    local function finalizeWithRanges(rawRanges, messageOverride)
        local ranges = limitAdjustmentRanges(rawRanges)
        local usedDefaultFallback = false
        if #ranges == 0 then
            ranges = buildDefaultAdjustmentRanges(ADJUSTMENT_RANGE_DEFAULT_COUNT)
            usedDefaultFallback = true
        end

        local function finalizeLoad()
            state.adjustmentRanges = ranges
            state.selectedRangeIndex = clamp(state.selectedRangeIndex, 1, math.max(#state.adjustmentRanges, 1))
            state.loading = false
            state.loaded = true
            state.readFallbackLocked = false
            state.showFunctionNamesInRangeSelector = false
            state.dirty = false
            state.dirtySlots = {}
            state.loadedSlots = {}
            state.pendingSlotLoads = {}
            for i = 1, #state.adjustmentRanges do
                state.loadedSlots[i] = true
            end
            state.loadError = nil
            state.infoMessage = messageOverride or (usedDefaultFallback and "@i18n(app.modules.adjustments.info_default_slots)@" or nil)
            state.needsRender = true
            rfsuite.app.triggers.closeProgressLoader = true
        end

        local callback = rfsuite.tasks and rfsuite.tasks.callback
        if callback and callback.now then
            callback.now(finalizeLoad)
        else
            finalizeLoad()
        end
    end

    local function finalizeFallbackLocked()
        local function finalizeFallback()
            state.adjustmentRanges = buildDefaultAdjustmentRanges(ADJUSTMENT_RANGE_DEFAULT_COUNT)
            state.selectedRangeIndex = 1
            state.loading = false
            state.loaded = true
            state.readFallbackLocked = true
            state.showFunctionNamesInRangeSelector = false
            state.dirty = false
            state.dirtySlots = {}
            state.loadedSlots = {}
            state.pendingSlotLoads = {}
            state.loadError = nil
            state.infoMessage = nil
            state.needsRender = true
            rfsuite.app.triggers.closeProgressLoader = true
        end

        local callback = rfsuite.tasks and rfsuite.tasks.callback
        if callback and callback.now then
            callback.now(finalizeFallback)
        else
            finalizeFallback()
        end
    end

    state.adjustmentRanges = buildDefaultAdjustmentRanges(ADJUSTMENT_RANGE_DEFAULT_COUNT)
    state.selectedRangeIndex = clamp(state.selectedRangeIndex, 1, math.max(#state.adjustmentRanges, 1))
    state.loadedSlots = {}
    state.pendingSlotLoads = {}
    state.showFunctionNamesInRangeSelector = false

    local function finalizeInitialLoad()
        state.loading = false
        state.loaded = true
        state.readFallbackLocked = false
        state.dirty = false
        state.dirtySlots = {}
        state.loadError = nil
        state.infoMessage = nil
        state.needsRender = true
        rfsuite.app.triggers.closeProgressLoader = true
    end

    requestSlotLoad(state.selectedRangeIndex, function()
        if not shouldUseMspFunctionNamePrefetch() then
            finalizeInitialLoad()
            return
        end

        -- Optional acceleration path: prefill slot labels by function-id only.
        -- If firmware does not support this command, continue normally.
        readAdjustmentFunctions(function(functions)
            applyAdjustmentFunctions(functions)
            state.showFunctionNamesInRangeSelector = true
            finalizeInitialLoad()
        end, function()
            state.showFunctionNamesInRangeSelector = false
            finalizeInitialLoad()
        end)
    end, function()
        -- Older FC builds may not support per-slot get. Fall back to legacy bulk read.
        readAdjustmentRangesBulk(function(ranges)
            finalizeWithRanges(ranges, "@i18n(app.modules.adjustments.info_legacy_load)@")
        end, function()
            finalizeFallbackLocked()
        end)
    end)
end

local function addRangeSlot()
    if #state.adjustmentRanges >= ADJUSTMENT_RANGE_MAX then
        local buttons = {{label = "@i18n(app.btn_ok_long)@", action = function() return true end}}
        form.openDialog({
            width = nil,
            title = MODULE_TITLE,
            message = "@i18n(app.modules.adjustments.msg_no_free_slots)@",
            buttons = buttons,
            wakeup = function() end,
            paint = function() end,
            options = TEXT_LEFT
        })
        return
    end

    state.adjustmentRanges[#state.adjustmentRanges + 1] = newDefaultAdjustmentRange()
    state.selectedRangeIndex = #state.adjustmentRanges
    state.loadedSlots[state.selectedRangeIndex] = true
    state.pendingSlotLoads[state.selectedRangeIndex] = nil
    markDirty(state.selectedRangeIndex)
    state.needsRender = true
end

local function startLoad()
    state.loading = true
    state.loaded = false
    state.readFallbackLocked = false
    state.loadError = nil
    state.saveError = nil
    state.infoMessage = nil
    state.channelSources = {}
    state.autoDetectEnaSlots = {}
    state.autoDetectAdjSlots = {}
    state.dirtySlots = {}
    state.loadedSlots = {}
    state.pendingSlotLoads = {}
    state.needsRender = true
    rfsuite.app.ui.progressDisplay(MODULE_TITLE, "@i18n(app.modules.adjustments.loading_ranges)@")
    readAdjustmentRanges()
end

local function setTypeForRange(adjRange, typ)
    typ = clamp(math.floor(typ or 0), 0, 2)

    if typ == 0 then
        adjRange.adjFunction = 0
        adjRange.adjStep = 0
        adjRange.adjMin = 0
        adjRange.adjMax = 100
        return
    end

    if (adjRange.adjFunction or 0) == 0 then adjRange.adjFunction = 1 end

    if typ == 1 then
        adjRange.adjStep = 0
    else
        if (adjRange.adjStep or 0) == 0 then adjRange.adjStep = 1 end
    end

    local cfg = getFunctionById(adjRange.adjFunction)
    if cfg then
        adjRange.adjMin = clamp(adjRange.adjMin or cfg.min, cfg.min, cfg.max)
        adjRange.adjMax = clamp(adjRange.adjMax or cfg.max, cfg.min, cfg.max)
        if adjRange.adjMin > adjRange.adjMax then adjRange.adjMax = adjRange.adjMin end
    end
end

local function setFunctionForRange(adjRange, fnId)
    fnId = clamp(math.floor(fnId or 0), 0, 255)
    adjRange.adjFunction = fnId

    if fnId == 0 then
        adjRange.adjStep = 0
        adjRange.adjMin = 0
        adjRange.adjMax = 100
        return
    end

    local cfg = getFunctionById(fnId)
    if not cfg then
        adjRange.adjMin = clamp(adjRange.adjMin or 0, -32768, 32767)
        adjRange.adjMax = clamp(adjRange.adjMax or 100, -32768, 32767)
    else
        adjRange.adjMin = clamp(adjRange.adjMin or cfg.min, cfg.min, cfg.max)
        adjRange.adjMax = clamp(adjRange.adjMax or cfg.max, cfg.min, cfg.max)
    end

    if adjRange.adjMin > adjRange.adjMax then adjRange.adjMax = adjRange.adjMin end
end

local function showInfoDialog(title, message)
    local buttons = {{label = "@i18n(app.btn_ok_long)@", action = function() return true end}}
    form.openDialog({
        width = nil,
        title = title,
        message = message,
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
end

local function confirmRangeSet(title, message, onConfirm)
    local buttons = {
        {label = "@i18n(app.btn_ok_long)@", action = function() if onConfirm then onConfirm() end; return true end},
        {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }

    form.openDialog({
        width = nil,
        title = title,
        message = message,
        buttons = buttons,
        wakeup = function() end,
        paint = function() end,
        options = TEXT_LEFT
    })
end

local function detectAutoAuxChannel(autoState)
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

    if bestIdx ~= nil and bestDelta >= AUTODETECT_DELTA_US then return bestIdx, bestUs end
    return nil, nil
end

local function getChannelUsForRangeSet(channelIndex, autoTable, slot)
    if autoTable and autoTable[slot] then
        showInfoDialog(MODULE_TITLE, "@i18n(app.modules.adjustments.msg_auto_detect_lock_first)@")
        return nil
    end

    local us = getAuxPulseUs(channelIndex or 0)
    if not us then
        showInfoDialog(MODULE_TITLE, "@i18n(app.modules.adjustments.msg_live_channel_unavailable)@")
        return nil
    end
    return us
end

local function applyRangeSetFromChannel(title, rangeTable, us, slotIndex)
    local targetStart = quantizeUs(us - RANGE_SNAP_DELTA_US)
    local targetEnd = quantizeUs(us + RANGE_SNAP_DELTA_US)
    if targetStart > targetEnd then
        local mid = quantizeUs(us)
        targetStart = mid
        targetEnd = mid
    end

    confirmRangeSet(
        title,
        "@i18n(app.modules.adjustments.confirm_use_current)@ "
            .. tostring(us) .. "us?\n\n"
            .. "@i18n(app.modules.adjustments.min_label)@: " .. tostring(targetStart) .. "us\n"
            .. "@i18n(app.modules.adjustments.max_label)@: " .. tostring(targetEnd) .. "us",
        function()
            rangeTable.start = targetStart
            rangeTable["end"] = targetEnd
            markDirty(slotIndex)
        end
    )
end

local function syncEnableControls(adjRange)
    if not adjRange then return end

    local isAlways = (adjRange.enaChannel == ALWAYS_ON_CHANNEL)
    local live = state.liveFields

    if live.enaStart and live.enaStart.enable then live.enaStart:enable(not isAlways) end
    if live.enaEnd and live.enaEnd.enable then live.enaEnd:enable(not isAlways) end
    if live.enaSetBtn and live.enaSetBtn.enable then live.enaSetBtn:enable(not isAlways) end

    if isAlways then
        if live.enaStart and live.enaStart.value then live.enaStart:value(1500) end
        if live.enaEnd and live.enaEnd.value then live.enaEnd:value(1500) end
    end
end

local function syncValueControls(adjRange)
    if not adjRange then return end

    local live = state.liveFields
    local enabled = ((adjRange.adjFunction or 0) > 0)

    if live.valStart and live.valStart.value then live.valStart:value(adjRange.adjMin) end
    if live.valEnd and live.valEnd.value then live.valEnd:value(adjRange.adjMax) end
    if live.valStart and live.valStart.enable then live.valStart:enable(enabled) end
    if live.valEnd and live.valEnd.enable then live.valEnd:enable(enabled) end
end

local function isWithin(value, rangeTable)
    if value == nil or rangeTable == nil then return false end
    return value >= (rangeTable.start or RANGE_MIN) and value <= (rangeTable["end"] or RANGE_MAX)
end

local function calcPreview(adjRange, adjType, enaUs, adjUs)
    local result = {active = false, text = "-"}
    if adjType == 0 then return result end

    local enabled = false
    if adjRange.enaChannel == ALWAYS_ON_CHANNEL then
        enabled = true
    else
        enabled = isWithin(enaUs, adjRange.enaRange)
    end
    if not enabled then return result end

    if adjType == 1 then
        if adjUs == nil then return result end

        local rangeWidth = (adjRange.adjRange1["end"] or RANGE_MAX) - (adjRange.adjRange1.start or RANGE_MIN)
        local valueWidth = (adjRange.adjMax or 0) - (adjRange.adjMin or 0)

        local value
        if rangeWidth > 0 and valueWidth > 0 then
            local offset = rangeWidth / 2
            value = (adjRange.adjMin or 0) + math.floor((((adjUs - (adjRange.adjRange1.start or RANGE_MIN)) * valueWidth) + offset) / rangeWidth)
            value = clamp(value, adjRange.adjMin or -32768, adjRange.adjMax or 32767)
        else
            value = adjRange.adjMin or 0
        end

        result.active = true
        result.text = tostring(value)
        return result
    end

    if adjType == 2 and adjUs ~= nil then
        if isWithin(adjUs, adjRange.adjRange1) then
            result.active = true
            result.text = "-" .. tostring(adjRange.adjStep or 0)
            return result
        end

        if isWithin(adjUs, adjRange.adjRange2) then
            result.active = true
            result.text = "+" .. tostring(adjRange.adjStep or 0)
            return result
        end
    end

    return result
end

local function updateLiveFields()
    local adjRange = getSelectedRange()
    if not adjRange then return end

    local slot = state.selectedRangeIndex

    local enaUs = nil
    local enaAutoState = state.autoDetectEnaSlots[slot]
    if enaAutoState then
        local idx, us = detectAutoAuxChannel(enaAutoState)
        if idx ~= nil then
            adjRange.enaChannel = idx
            state.autoDetectEnaSlots[slot] = nil
            markDirty(slot)
            syncEnableControls(adjRange)
            enaUs = us
        else
            if state.liveFields.ena and state.liveFields.ena.value then state.liveFields.ena:value("@i18n(app.modules.adjustments.channel_auto_detecting)@") end
        end
    elseif adjRange.enaChannel == ALWAYS_ON_CHANNEL then
        if state.liveFields.ena and state.liveFields.ena.value then state.liveFields.ena:value("@i18n(app.modules.adjustments.channel_always)@") end
        enaUs = 1500
    else
        enaUs = getAuxPulseUs(adjRange.enaChannel or 0)
        if state.liveFields.ena and state.liveFields.ena.value then
            if enaUs then
                state.liveFields.ena:value(" " .. tostring(enaUs) .. "us")
            else
                state.liveFields.ena:value(" --")
            end
        end
    end

    local adjUs = nil
    local autoState = state.autoDetectAdjSlots[slot]
    if autoState then
        local idx, us = detectAutoAuxChannel(autoState)
        if idx ~= nil then
            adjRange.adjChannel = idx
            state.autoDetectAdjSlots[slot] = nil
            markDirty(slot)
            adjUs = us
        else
            if state.liveFields.adj and state.liveFields.adj.value then state.liveFields.adj:value("@i18n(app.modules.adjustments.channel_auto_detecting)@") end
        end
    else
        adjUs = getAuxPulseUs(adjRange.adjChannel or 0)
        if state.liveFields.adj and state.liveFields.adj.value then
            if adjUs then
                state.liveFields.adj:value(" " .. tostring(adjUs) .. "us")
            else
                state.liveFields.adj:value(" --")
            end
        end
    end

    if state.liveFields.preview and state.liveFields.preview.value then
        local preview = calcPreview(adjRange, getAdjustmentType(adjRange), enaUs, adjUs)
        local valueText = preview.text
        if preview.active then valueText = valueText .. "*" end
        state.liveFields.preview:value("Output: " .. valueText)
    end
    if state.liveFields.previewCompact and state.liveFields.previewCompact.value then
        local preview = calcPreview(adjRange, getAdjustmentType(adjRange), enaUs, adjUs)
        local valueText = preview.text
        if preview.active then valueText = valueText .. "*" end
        state.liveFields.previewCompact:value("O:" .. valueText)
    end
end

local function render()
    local app = rfsuite.app

    state.liveFields = {}
    syncNavButtonsForState()

    form.clear()
    app.ui.fieldHeader(state.title)

    if state.loading then
        form.addLine("@i18n(app.modules.adjustments.loading_ranges_detail)@")
        return
    end

    if state.loadError then
        form.addLine("@i18n(app.modules.adjustments.load_error)@ " .. tostring(state.loadError))
        return
    end

    if state.readFallbackLocked then
        form.addLine("@i18n(app.modules.adjustments.read_timeout)@")
        form.addLine("@i18n(app.modules.adjustments.editing_disabled_reload_back)@")
        return
    end

    if #state.adjustmentRanges == 0 then
        form.addLine("@i18n(app.modules.adjustments.no_ranges_reported)@")
        return
    end

    local width = app.lcdWidth
    local h = app.radio.navbuttonHeight
    local y = app.radio.linePaddingTop
    local rightPadding = 8
    local gap = 6
    local wSet = math.max(42, math.floor(width * 0.14))
    local wLive = math.floor(width * 0.18)
    local wChoice = math.max(96, math.floor(width * 0.22))
    local wNum = math.floor(width * 0.16)
    local xSet = width - rightPadding - wSet
    local xLive = xSet - gap - wLive
    local xChoice = xLive - gap - wChoice
    local xEnd = xSet - gap - wNum
    local xStart = xEnd - gap - wNum
    local wRightColumn = (width - rightPadding) - xChoice
    local focusTargets = {}
    local function registerFocus(key, field)
        if key and field then focusTargets[key] = field end
        return field
    end

    local activeCount = countActiveRanges()
    local infoLine = form.addLine("@i18n(app.modules.adjustments.active_ranges)@ " .. tostring(activeCount) .. " / " .. tostring(#state.adjustmentRanges))
    local previewW = math.max(48, math.floor(width * 0.16))
    local previewX = width - rightPadding - previewW

    if state.dirty then
        local statusW = math.max(76, math.floor(width * 0.22))
        local statusX = previewX - gap - statusW
        local statusBtn = form.addButton(infoLine, {x = statusX, y = y, w = statusW, h = h}, {
            text = "@i18n(app.modules.adjustments.unsaved_changes)@",
            icon = nil,
            options = FONT_S,
            paint = function() end,
            press = function() end
        })
        if statusBtn and statusBtn.enable then statusBtn:enable(false) end
    end
    local preview = form.addStaticText(infoLine, {x = previewX, y = y, w = previewW, h = h}, "Output: -")
    if preview and preview.value then state.liveFields.preview = preview end

    if hasActiveAutoDetect() then form.addLine("@i18n(app.modules.adjustments.auto_detect_active_toggle)@") end
    if state.saveError then form.addLine("@i18n(app.modules.adjustments.save_error)@ " .. tostring(state.saveError)) end
    if state.infoMessage then form.addLine(state.infoMessage) end

    local slotOptionsTbl = buildRangeSlotOptions()
    local adjRange = getSelectedRange()
    if not adjRange then return end

    buildFunctionOptions(adjRange.adjFunction)
    local adjType = getAdjustmentType(adjRange)

    local slotLine = form.addLine("@i18n(app.modules.adjustments.range)@")
    local slotChoiceW = wRightColumn
    if not state.showFunctionNamesInRangeSelector then
        slotChoiceW = math.max(96, math.floor(wRightColumn * 0.5))
    end
    local slotChoice = form.addChoiceField(
        slotLine,
        {x = xChoice, y = y, w = slotChoiceW, h = h},
        slotOptionsTbl,
        function() return state.selectedRangeIndex end,
        function(value)
            setPendingFocus("slotChoice")
            state.selectedRangeIndex = clamp(value or 1, 1, #state.adjustmentRanges)
            requestSlotLoad(state.selectedRangeIndex, function()
                state.needsRender = true
            end, function(reason)
                state.infoMessage = reason or "@i18n(app.modules.adjustments.load_error)@"
                state.needsRender = true
            end)
            state.needsRender = true
        end
    )
    registerFocus("slotChoice", slotChoice)
    state.liveFields.slotChoice = slotChoice
    if slotChoice and slotChoice.values then slotChoice:values(slotOptionsTbl) end

    if not state.showFunctionNamesInRangeSelector then
        local slotFnX = xChoice + slotChoiceW + gap
        local slotFnW = (xChoice + wRightColumn) - slotFnX
        if slotFnW > 20 then
            local slotFunctionName = form.addStaticText(slotLine, {x = slotFnX, y = y, w = slotFnW, h = h}, " " .. getFunctionDisplayName(adjRange.adjFunction))
            if slotFunctionName and slotFunctionName.value then state.liveFields.slotFunction = slotFunctionName end
        end
    end

    local typeLine = form.addLine("@i18n(app.modules.adjustments.type)@", nil, true)
    local typeChoice = form.addChoiceField(
        typeLine,
        {x = xChoice, y = y, w = wRightColumn, h = h},
        ADJUST_TYPE_OPTIONS_TBL,
        function() return getAdjustmentType(adjRange) end,
        function(value)
            local prevType = getAdjustmentType(adjRange)
            setTypeForRange(adjRange, value)
            adjRange = sanitizeAdjustmentRange(adjRange)
            state.adjustmentRanges[state.selectedRangeIndex] = adjRange
            markDirty()
            refreshRangeSlotOptions()
            local newType = getAdjustmentType(adjRange)
            if prevType == 2 or newType == 2 then
                setPendingFocus("typeChoice")
                state.needsRender = true
            else
                syncValueControls(adjRange)
            end
        end
    )
    registerFocus("typeChoice", typeChoice)
    if typeChoice and typeChoice.values then typeChoice:values(ADJUST_TYPE_OPTIONS_TBL) end
    if typeChoice and typeChoice.enable then typeChoice:enable(true) end

    local enaSetBtn
    local enaStart
    local enaEnd
    local enaChannelLine = form.addLine("@i18n(app.modules.adjustments.enable_channel)@", nil, false)
    local enaChoice = form.addChoiceField(
        enaChannelLine,
        {x = xChoice, y = y, w = wChoice, h = h},
        ENA_CHANNEL_OPTIONS_TBL,
        function()
            if state.autoDetectEnaSlots[state.selectedRangeIndex] then return 1 end
            if adjRange.enaChannel == ALWAYS_ON_CHANNEL then return 2 end
            return clamp((adjRange.enaChannel or 0) + 3, 3, #ENA_CHANNEL_OPTIONS)
        end,
        function(value)
            if value == 1 then
                state.autoDetectEnaSlots[state.selectedRangeIndex] = {baseline = nil}
            elseif value == 2 then
                state.autoDetectEnaSlots[state.selectedRangeIndex] = nil
                adjRange.enaChannel = ALWAYS_ON_CHANNEL
                adjRange.enaRange.start = 1500
                adjRange.enaRange["end"] = 1500
            else
                state.autoDetectEnaSlots[state.selectedRangeIndex] = nil
                adjRange.enaChannel = clamp((value or 3) - 3, 0, AUX_CHANNEL_COUNT_FALLBACK - 1)
            end
            markDirty()
            syncEnableControls(adjRange)
        end
    )
    registerFocus("enaChoice", enaChoice)
    if enaChoice and enaChoice.values then enaChoice:values(ENA_CHANNEL_OPTIONS_TBL) end
    if enaChoice and enaChoice.enable then enaChoice:enable(true) end
    local enaLive = form.addStaticText(enaChannelLine, {x = xLive, y = y, w = wLive, h = h}, " --")
    if enaLive and enaLive.value then state.liveFields.ena = enaLive end
    enaSetBtn = form.addButton(enaChannelLine, {x = xSet, y = y, w = wSet, h = h}, {
        text = "@i18n(app.modules.adjustments.set)@",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function()
            if adjRange.enaChannel == ALWAYS_ON_CHANNEL then
                confirmRangeSet("@i18n(app.modules.adjustments.set_enable_range)@", "@i18n(app.modules.adjustments.always_fixed_1500_confirm)@", function()
                    adjRange.enaRange.start = 1500
                    adjRange.enaRange["end"] = 1500
                    markDirty()
                end)
                return
            end
            local us = getChannelUsForRangeSet(adjRange.enaChannel, state.autoDetectEnaSlots, state.selectedRangeIndex)
            if not us then return end
            applyRangeSetFromChannel("@i18n(app.modules.adjustments.set_enable_range)@", adjRange.enaRange, us)
        end
    })
    state.liveFields.enaSetBtn = enaSetBtn

    local enaRangeLine = form.addLine("@i18n(app.modules.adjustments.enable_range)@", nil, true)
    enaStart = form.addNumberField(
        enaRangeLine,
        {x = xStart, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return adjRange.enaRange.start end,
        function(value)
            setUsRangeStart(adjRange.enaRange, value)
            markDirty()
        end
    )
    state.liveFields.enaStart = enaStart
    enaEnd = form.addNumberField(
        enaRangeLine,
        {x = xEnd, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return adjRange.enaRange["end"] end,
        function(value)
            setUsRangeEnd(adjRange.enaRange, value)
            markDirty()
        end
    )
    state.liveFields.enaEnd = enaEnd
    if enaStart and enaStart.step then enaStart:step(RANGE_STEP) end
    if enaEnd and enaEnd.step then enaEnd:step(RANGE_STEP) end
    if enaStart and enaStart.suffix then enaStart:suffix("us") end
    if enaEnd and enaEnd.suffix then enaEnd:suffix("us") end
    syncEnableControls(adjRange)

    local adjChannelLine = form.addLine("@i18n(app.modules.adjustments.value_channel)@", nil, false)
    local adjChoice = form.addChoiceField(
        adjChannelLine,
        {x = xChoice, y = y, w = wChoice, h = h},
        ADJ_CHANNEL_OPTIONS_TBL,
        function()
            if state.autoDetectAdjSlots[state.selectedRangeIndex] then return 1 end
            return clamp((adjRange.adjChannel or 0) + 2, 2, #ADJ_CHANNEL_OPTIONS)
        end,
        function(value)
            if value == 1 then
                state.autoDetectAdjSlots[state.selectedRangeIndex] = {baseline = nil}
            else
                state.autoDetectAdjSlots[state.selectedRangeIndex] = nil
                adjRange.adjChannel = clamp((value or 2) - 2, 0, AUX_CHANNEL_COUNT_FALLBACK - 1)
            end
            markDirty()
        end
    )
    registerFocus("adjChoice", adjChoice)
    if adjChoice and adjChoice.values then adjChoice:values(ADJ_CHANNEL_OPTIONS_TBL) end
    if adjChoice and adjChoice.enable then adjChoice:enable(true) end
    local adjLive = form.addStaticText(adjChannelLine, {x = xLive, y = y, w = wLive, h = h}, " --")
    if adjLive and adjLive.value then state.liveFields.adj = adjLive end

    if adjType == 2 then
        local stepLine = form.addLine("@i18n(app.modules.adjustments.step_size)@", nil, false)
        local stepField = form.addNumberField(
            stepLine,
            {x = xEnd, y = y, w = wNum, h = h},
            ADJ_STEP_MIN,
            ADJ_STEP_MAX,
            function() return adjRange.adjStep end,
            function(value)
                adjRange.adjStep = clamp(math.floor(value), ADJ_STEP_MIN, ADJ_STEP_MAX)
                markDirty()
            end
        )
        if stepField and stepField.enable then stepField:enable(true) end
    end

    local range1Label = adjType == 2 and "@i18n(app.modules.adjustments.decrease_range)@" or "@i18n(app.modules.adjustments.adjust_range)@"
    local range1Line = form.addLine(range1Label, nil, adjType ~= 2)
    local range1Start = form.addNumberField(
        range1Line,
        {x = xStart, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return adjRange.adjRange1.start end,
        function(value)
            setUsRangeStart(adjRange.adjRange1, value)
            markDirty()
        end
    )
    local range1End = form.addNumberField(
        range1Line,
        {x = xEnd, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return adjRange.adjRange1["end"] end,
        function(value)
            setUsRangeEnd(adjRange.adjRange1, value)
            markDirty()
        end
    )
    if range1Start and range1Start.step then range1Start:step(RANGE_STEP) end
    if range1End and range1End.step then range1End:step(RANGE_STEP) end
    if range1Start and range1Start.suffix then range1Start:suffix("us") end
    if range1End and range1End.suffix then range1End:suffix("us") end
    form.addButton(range1Line, {x = xSet, y = y, w = wSet, h = h}, {
        text = "@i18n(app.modules.adjustments.set)@",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function()
            local us = getChannelUsForRangeSet(adjRange.adjChannel, state.autoDetectAdjSlots, state.selectedRangeIndex)
            if not us then return end
            local title = (adjType == 2) and "@i18n(app.modules.adjustments.set_decrease_range)@" or "@i18n(app.modules.adjustments.set_adjust_range)@"
            applyRangeSetFromChannel(title, adjRange.adjRange1, us)
        end
    })

    if adjType == 2 then
        local range2Line = form.addLine("@i18n(app.modules.adjustments.increase_range)@", nil, true)
        local range2Start = form.addNumberField(
            range2Line,
            {x = xStart, y = y, w = wNum, h = h},
            RANGE_MIN,
            RANGE_MAX,
            function() return adjRange.adjRange2.start end,
            function(value)
                setUsRangeStart(adjRange.adjRange2, value)
                markDirty()
            end
        )
        local range2End = form.addNumberField(
            range2Line,
            {x = xEnd, y = y, w = wNum, h = h},
            RANGE_MIN,
            RANGE_MAX,
            function() return adjRange.adjRange2["end"] end,
            function(value)
                setUsRangeEnd(adjRange.adjRange2, value)
                markDirty()
            end
        )
        if range2Start and range2Start.step then range2Start:step(RANGE_STEP) end
        if range2End and range2End.step then range2End:step(RANGE_STEP) end
        if range2Start and range2Start.suffix then range2Start:suffix("us") end
        if range2End and range2End.suffix then range2End:suffix("us") end
        form.addButton(range2Line, {x = xSet, y = y, w = wSet, h = h}, {
            text = "@i18n(app.modules.adjustments.set)@",
            icon = nil,
            options = FONT_S,
            paint = function() end,
            press = function()
                local us = getChannelUsForRangeSet(adjRange.adjChannel, state.autoDetectAdjSlots, state.selectedRangeIndex)
                if not us then return end
                applyRangeSetFromChannel("@i18n(app.modules.adjustments.set_increase_range)@", adjRange.adjRange2, us)
            end
        })
    end

    local functionLine = form.addLine("@i18n(app.modules.adjustments.function)@", nil, false)
    local functionChoice = form.addChoiceField(
        functionLine,
        {x = xChoice, y = y, w = wChoice, h = h},
        state.functionOptions,
        function() return getFunctionChoiceIndex(adjRange.adjFunction or 0) end,
        function(value)
            local prevType = getAdjustmentType(adjRange)
            local fnId = state.functionOptionIds[value or 1] or 0
            setFunctionForRange(adjRange, fnId)
            adjRange = sanitizeAdjustmentRange(adjRange)
            state.adjustmentRanges[state.selectedRangeIndex] = adjRange
            markDirty()
            refreshRangeSlotOptions()
            if state.liveFields.slotFunction and state.liveFields.slotFunction.value and not state.showFunctionNamesInRangeSelector then
                state.liveFields.slotFunction:value(" " .. getFunctionDisplayName(adjRange.adjFunction))
            end
            local newType = getAdjustmentType(adjRange)
            if prevType == 2 or newType == 2 then
                setPendingFocus("functionChoice")
                state.needsRender = true
            else
                syncValueControls(adjRange)
            end
        end
    )
    registerFocus("functionChoice", functionChoice)
    if functionChoice and functionChoice.values then functionChoice:values(state.functionOptions) end
    if functionChoice and functionChoice.enable then functionChoice:enable(true) end

    local valueCfg = getFunctionById(adjRange.adjFunction)
    local valueMin = valueCfg and valueCfg.min or -32768
    local valueMax = valueCfg and valueCfg.max or 32767

    local valRangeLine = form.addLine("@i18n(app.modules.adjustments.value_range)@", nil, true)
    local valStart = form.addNumberField(
        valRangeLine,
        {x = xStart, y = y, w = wNum, h = h},
        valueMin,
        valueMax,
        function() return adjRange.adjMin end,
        function(value)
            local adjusted = clamp(math.floor(value), valueMin, valueMax)
            adjRange.adjMin = adjusted
            if adjRange.adjMax < adjusted then adjRange.adjMax = adjusted end
            markDirty()
        end
    )
    local valEnd = form.addNumberField(
        valRangeLine,
        {x = xEnd, y = y, w = wNum, h = h},
        valueMin,
        valueMax,
        function() return adjRange.adjMax end,
        function(value)
            local adjusted = clamp(math.floor(value), valueMin, valueMax)
            adjRange.adjMax = adjusted
            if adjRange.adjMin > adjusted then adjRange.adjMin = adjusted end
            markDirty()
        end
    )
    registerFocus("valStart", valStart)
    registerFocus("valEnd", valEnd)
    state.liveFields.valStart = valStart
    state.liveFields.valEnd = valEnd
    local previewCompact = form.addStaticText(valRangeLine, {x = xSet, y = y, w = wSet, h = h}, "O:-")
    if previewCompact and previewCompact.value then state.liveFields.previewCompact = previewCompact end
    if adjType == 0 then
        if valStart and valStart.enable then valStart:enable(false) end
        if valEnd and valEnd.enable then valEnd:enable(false) end
    end

    restorePendingFocus(focusTargets)
end

local function queueSetAdjustmentRange(slotIndex, done, failed)
    local adjRange = sanitizeAdjustmentRange(state.adjustmentRanges[slotIndex] or {})
    state.adjustmentRanges[slotIndex] = adjRange

    local enaStartStep = clamp((adjRange.enaRange.start - 1500) / 5, -125, 125)
    local enaEndStep = clamp((adjRange.enaRange["end"] - 1500) / 5, -125, 125)
    local adjRange1StartStep = clamp((adjRange.adjRange1.start - 1500) / 5, -125, 125)
    local adjRange1EndStep = clamp((adjRange.adjRange1["end"] - 1500) / 5, -125, 125)
    local adjRange2StartStep = clamp((adjRange.adjRange2.start - 1500) / 5, -125, 125)
    local adjRange2EndStep = clamp((adjRange.adjRange2["end"] - 1500) / 5, -125, 125)

    local minLo, minHi = toS16Bytes(adjRange.adjMin)
    local maxLo, maxHi = toS16Bytes(adjRange.adjMax)

    local payload = {
        slotIndex - 1,
        clamp(adjRange.adjFunction, 0, 255),
        clamp(adjRange.enaChannel, 0, 255),
        toS8Byte(enaStartStep),
        toS8Byte(enaEndStep),
        clamp(adjRange.adjChannel, 0, 255),
        toS8Byte(adjRange1StartStep),
        toS8Byte(adjRange1EndStep),
        toS8Byte(adjRange2StartStep),
        toS8Byte(adjRange2EndStep),
        minLo,
        minHi,
        maxLo,
        maxHi,
        clamp(adjRange.adjStep, ADJ_STEP_MIN, ADJ_STEP_MAX)
    }

    local message = {
        command = 53,
        payload = payload,
        processReply = function() if done then done() end end,
        errorHandler = function() if failed then failed("SET_ADJUSTMENT_RANGE failed at slot " .. tostring(slotIndex)) end end,
        simulatorResponse = {}
    }

    local ok, reason = queueDirect(message, string.format("adjustments.slot.%d", slotIndex))
    if not ok and failed then failed(reason or "queue_rejected") end
end

local function queueEepromWrite(done, failed)
    local message = {
        command = 250,
        processReply = function() if done then done() end end,
        errorHandler = function() if failed then failed("EEPROM write failed") end end,
        simulatorResponse = {}
    }

    local ok, reason = queueDirect(message, "adjustments.eeprom")
    if not ok and failed then failed(reason or "queue_rejected") end
end

local function saveAllRanges()
    state.saveError = nil
    local changedSlots = getChangedSlots()
    local total = #changedSlots

    if total == 0 then
        state.dirty = false
        state.dirtySlots = {}
        state.infoMessage = nil
        state.needsRender = true
        return
    end

    state.saving = true
    state.infoMessage = nil
    rfsuite.app.ui.progressDisplay(MODULE_TITLE, "@i18n(app.modules.adjustments.saving_changed_ranges)@")

    local slotPos = 1

    local function failed(reason)
        state.saving = false
        state.saveError = reason or "Save failed"
        state.needsRender = true
        rfsuite.app.triggers.closeProgressLoader = true
    end

    local function writeNext()
        if slotPos > total then
            queueEepromWrite(function()
                state.saving = false
                state.dirty = false
                state.dirtySlots = {}
                state.saveError = nil
                state.infoMessage = nil
                state.needsRender = true
                rfsuite.app.triggers.closeProgressLoader = true
            end, failed)
            return
        end

        local slotIndex = changedSlots[slotPos]
        queueSetAdjustmentRange(slotIndex, function()
            slotPos = slotPos + 1
            writeNext()
        end, failed)
    end

    writeNext()
end

local function onSaveMenu()
    if state.loading or state.saving or not state.loaded then return end
    if state.readFallbackLocked then return end
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    local requireDirty = not (pref == false or pref == "false")
    if requireDirty and (not state.dirty) then return end

    if hasActiveAutoDetect() then
        local buttons = {{label = "@i18n(app.btn_ok_long)@", action = function() return true end}}
        form.openDialog({
            width = nil,
            title = MODULE_TITLE,
            message = "@i18n(app.modules.adjustments.msg_auto_detect_lock_save)@",
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

    updateLiveFields()
end

local function openPage(opts)
    local idx = opts.idx
    state.title = opts.title or MODULE_TITLE

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = state.title
    rfsuite.app.lastScript = opts.script
    rfsuite.session.lastPage = opts.script

    buildFunctionOptions(nil)
    startLoad()
end

return {
    title = MODULE_TITLE,
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
