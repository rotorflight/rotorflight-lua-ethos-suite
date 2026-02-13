--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local ADJUST_TYPE_OPTIONS = {"OFF", "MAPPED", "STEPPED"}
local ALWAYS_ON_CHANNEL = 255
local AUX_CHANNEL_COUNT_FALLBACK = 20

local RANGE_MIN = 875
local RANGE_MAX = 2125
local RANGE_STEP = 5

local ADJ_STEP_MIN = 0
local ADJ_STEP_MAX = 255
local ADJUSTMENT_RANGE_MAX = 64
local ADJUSTMENT_RANGE_DEFAULT_COUNT = 42

local ADJUST_FUNCTIONS = {
    {id = 0, name = "None", min = 0, max = 100},
    {id = 1, name = "RateProfile", min = 1, max = 6},
    {id = 2, name = "PIDProfile", min = 1, max = 6},
    {id = 3, name = "LEDProfile", min = 1, max = 4},
    {id = 4, name = "OSDProfile", min = 1, max = 3},
    {id = 5, name = "PitchRate", min = 0, max = 255},
    {id = 6, name = "RollRate", min = 0, max = 255},
    {id = 7, name = "YawRate", min = 0, max = 255},
    {id = 8, name = "PitchRCRate", min = 0, max = 255},
    {id = 9, name = "RollRCRate", min = 0, max = 255},
    {id = 10, name = "YawRCRate", min = 0, max = 255},
    {id = 11, name = "PitchRCExpo", min = 0, max = 100},
    {id = 12, name = "RollRCExpo", min = 0, max = 100},
    {id = 13, name = "YawRCExpo", min = 0, max = 100},
    {id = 14, name = "PitchP", min = 0, max = 250},
    {id = 15, name = "PitchI", min = 0, max = 250},
    {id = 16, name = "PitchD", min = 0, max = 250},
    {id = 17, name = "PitchF", min = 0, max = 250},
    {id = 18, name = "RollP", min = 0, max = 250},
    {id = 19, name = "RollI", min = 0, max = 250},
    {id = 20, name = "RollD", min = 0, max = 250},
    {id = 21, name = "RollF", min = 0, max = 250},
    {id = 22, name = "YawP", min = 0, max = 250},
    {id = 23, name = "YawI", min = 0, max = 250},
    {id = 24, name = "YawD", min = 0, max = 250},
    {id = 25, name = "YawF", min = 0, max = 250},
    {id = 26, name = "YawCWStopGain", min = 25, max = 250},
    {id = 27, name = "YawCCWStopGain", min = 25, max = 250},
    {id = 28, name = "YawCyclicFF", min = 0, max = 250},
    {id = 29, name = "YawCollectiveFF", min = 0, max = 250},
    {id = 30, name = "YawCollectiveDyn", min = -125, max = 125, maxApi = "12.07"},
    {id = 31, name = "YawCollectiveDecay", min = 1, max = 250, maxApi = "12.07"},
    {id = 32, name = "PitchCollectiveFF", min = 0, max = 250},
    {id = 33, name = "PitchGyroCutoff", min = 0, max = 250},
    {id = 34, name = "RollGyroCutoff", min = 0, max = 250},
    {id = 35, name = "YawGyroCutoff", min = 0, max = 250},
    {id = 36, name = "PitchDtermCutoff", min = 0, max = 250},
    {id = 37, name = "RollDtermCutoff", min = 0, max = 250},
    {id = 38, name = "YawDtermCutoff", min = 0, max = 250},
    {id = 39, name = "RescueClimbCollective", min = 0, max = 1000},
    {id = 40, name = "RescueHoverCollective", min = 0, max = 1000},
    {id = 41, name = "RescueHoverAltitude", min = 0, max = 2500},
    {id = 42, name = "RescueAltP", min = 0, max = 250},
    {id = 43, name = "RescueAltI", min = 0, max = 250},
    {id = 44, name = "RescueAltD", min = 0, max = 250},
    {id = 45, name = "AngleLevelGain", min = 0, max = 200},
    {id = 46, name = "HorizonLevelGain", min = 0, max = 200},
    {id = 47, name = "AcroTrainerGain", min = 25, max = 255},
    {id = 48, name = "GovernorGain", min = 0, max = 250},
    {id = 49, name = "GovernorP", min = 0, max = 250},
    {id = 50, name = "GovernorI", min = 0, max = 250},
    {id = 51, name = "GovernorD", min = 0, max = 250},
    {id = 52, name = "GovernorF", min = 0, max = 250},
    {id = 53, name = "GovernorTTA", min = 0, max = 250},
    {id = 54, name = "GovernorCyclicFF", min = 0, max = 250},
    {id = 55, name = "GovernorCollectiveFF", min = 0, max = 250},
    {id = 56, name = "PitchB", min = 0, max = 250},
    {id = 57, name = "RollB", min = 0, max = 250},
    {id = 58, name = "YawB", min = 0, max = 250},
    {id = 59, name = "PitchO", min = 0, max = 250},
    {id = 60, name = "RollO", min = 0, max = 250},
    {id = 61, name = "CrossCouplingGain", min = 0, max = 250},
    {id = 62, name = "CrossCouplingRatio", min = 0, max = 250},
    {id = 63, name = "CrossCouplingCutoff", min = 0, max = 250},
    {id = 64, name = "AccTrimPitch", min = -300, max = 300},
    {id = 65, name = "AccTrimRoll", min = -300, max = 300},
    {id = 66, name = "YawInertiaPrecompGain", min = 0, max = 250, minApi = "12.08"},
    {id = 67, name = "YawInertiaPrecompCutoff", min = 0, max = 250, minApi = "12.08"},
    {id = 68, name = "PitchSetpointBoostGain", min = 0, max = 255, minApi = "12.08"},
    {id = 69, name = "RollSetpointBoostGain", min = 0, max = 255, minApi = "12.08"},
    {id = 70, name = "YawSetpointBoostGain", min = 0, max = 255, minApi = "12.08"},
    {id = 71, name = "CollectiveSetpointBoostGain", min = 0, max = 255, minApi = "12.08"},
    {id = 72, name = "YawDynCeilingGain", min = 0, max = 250, minApi = "12.08"},
    {id = 73, name = "YawDynDeadbandGain", min = 0, max = 250, minApi = "12.08"},
    {id = 74, name = "YawDynDeadbandFilter", min = 0, max = 250, minApi = "12.08"},
    {id = 75, name = "YawPrecompCutoff", min = 0, max = 250, minApi = "12.08"},
    {id = 76, name = "GovIdleThrottle", min = 0, max = 250, minApi = "12.09"},
    {id = 77, name = "GovAutoThrottle", min = 0, max = 250, minApi = "12.09"},
    {id = 78, name = "GovMaxThrottle", min = 0, max = 100, minApi = "12.09"},
    {id = 79, name = "GovMinThrottle", min = 0, max = 100, minApi = "12.09"},
    {id = 80, name = "GovHeadspeed", min = 0, max = 10000, minApi = "12.09"},
    {id = 81, name = "GovYawFF", min = 0, max = 250, minApi = "12.09"}
}

local state = {
    title = "Adjustment Functions",
    adjustmentRanges = {},
    selectedRangeIndex = 1,
    loaded = false,
    loading = false,
    saving = false,
    dirty = false,
    loadError = nil,
    saveError = nil,
    infoMessage = nil,
    needsRender = false,
    channelSources = {},
    liveFields = {},
    autoDetectAdjSlots = {},
    functionById = {},
    functionOptions = {},
    functionOptionIds = {}
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

local function quantizeUs(value)
    return clamp(math.floor((value + (RANGE_STEP / 2)) / RANGE_STEP) * RANGE_STEP, RANGE_MIN, RANGE_MAX)
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
        local fallback = {id = currentId, name = "Function " .. tostring(currentId), min = -32768, max = 32767}
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

local function buildAuxOptions(includeAuto, includeAlways)
    local options = {}
    if includeAuto then options[#options + 1] = "AUTO" end
    if includeAlways then options[#options + 1] = "Always" end
    for i = 1, AUX_CHANNEL_COUNT_FALLBACK do
        options[#options + 1] = "AUX " .. tostring(i)
    end
    return options
end

local ADJUST_TYPE_OPTIONS_TBL = buildChoiceTable(ADJUST_TYPE_OPTIONS, -1)
local ADJ_CHANNEL_OPTIONS = buildAuxOptions(true, false)
local ENA_CHANNEL_OPTIONS = buildAuxOptions(false, true)
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

local function countActiveRanges()
    local used = 0
    for i = 1, #state.adjustmentRanges do
        if (state.adjustmentRanges[i].adjFunction or 0) > 0 then used = used + 1 end
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

local function readAdjustmentRanges()
    local API = rfsuite.tasks.msp.api.load("ADJUSTMENT_RANGES")
    if not API then
        setLoadError("ADJUSTMENT_RANGES API unavailable")
        return
    end

    API.setCompleteHandler(function()
        local ranges = limitAdjustmentRanges(API.readValue("adjustment_ranges"))
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
            state.dirty = false
            state.loadError = nil
            state.infoMessage = usedDefaultFallback and "No ranges returned by FC. Showing default slot list." or nil
            state.needsRender = true
            rfsuite.app.triggers.closeProgressLoader = true
        end

        local callback = rfsuite.tasks and rfsuite.tasks.callback
        if callback and callback.now then
            callback.now(finalizeLoad)
        else
            finalizeLoad()
        end
    end)

    API.setErrorHandler(function()
        -- Some FC builds may NACK this read when no adjustments exist yet.
        -- Seed a local default list so users can create entries.
        local function finalizeFallback()
            state.adjustmentRanges = buildDefaultAdjustmentRanges(ADJUSTMENT_RANGE_DEFAULT_COUNT)
            state.selectedRangeIndex = 1
            state.loading = false
            state.loaded = true
            state.dirty = false
            state.loadError = nil
            state.infoMessage = "Adjustment read failed. Showing default slot list."
            state.needsRender = true
            rfsuite.app.triggers.closeProgressLoader = true
        end

        local callback = rfsuite.tasks and rfsuite.tasks.callback
        if callback and callback.now then
            callback.now(finalizeFallback)
        else
            finalizeFallback()
        end
    end)

    API.read()
end

local function addRangeSlot()
    if #state.adjustmentRanges >= ADJUSTMENT_RANGE_MAX then
        local buttons = {{label = "OK", action = function() return true end}}
        form.openDialog({
            width = nil,
            title = "Adjustment Functions",
            message = "No free adjustment slots remain.",
            buttons = buttons,
            wakeup = function() end,
            paint = function() end,
            options = TEXT_LEFT
        })
        return
    end

    state.adjustmentRanges[#state.adjustmentRanges + 1] = newDefaultAdjustmentRange()
    state.selectedRangeIndex = #state.adjustmentRanges
    state.dirty = true
    state.needsRender = true
end

local function startLoad()
    state.loading = true
    state.loaded = false
    state.loadError = nil
    state.saveError = nil
    state.infoMessage = nil
    state.channelSources = {}
    state.autoDetectAdjSlots = {}
    state.needsRender = true
    rfsuite.app.ui.progressDisplay("Adjustment Functions", "Loading adjustment ranges")
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

    local enaUs
    if adjRange.enaChannel == ALWAYS_ON_CHANNEL then
        if state.liveFields.ena and state.liveFields.ena.value then state.liveFields.ena:value("Always") end
        enaUs = 1500
    else
        enaUs = getAuxPulseUs(adjRange.enaChannel or 0)
        if state.liveFields.ena and state.liveFields.ena.value then
            if enaUs then
                state.liveFields.ena:value(tostring(enaUs) .. "us")
            else
                state.liveFields.ena:value("--")
            end
        end
    end

    local adjUs = nil
    local autoState = state.autoDetectAdjSlots[slot]
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

        if bestIdx ~= nil and bestDelta >= 120 then
            adjRange.adjChannel = bestIdx
            state.autoDetectAdjSlots[slot] = nil
            state.dirty = true
            state.needsRender = true
            adjUs = bestUs
        else
            if state.liveFields.adj and state.liveFields.adj.value then state.liveFields.adj:value("AUTO...") end
        end
    else
        adjUs = getAuxPulseUs(adjRange.adjChannel or 0)
        if state.liveFields.adj and state.liveFields.adj.value then
            if adjUs then
                state.liveFields.adj:value(tostring(adjUs) .. "us")
            else
                state.liveFields.adj:value("--")
            end
        end
    end

    if state.liveFields.preview and state.liveFields.preview.value then
        local preview = calcPreview(adjRange, getAdjustmentType(adjRange), enaUs, adjUs)
        if preview.active then
            state.liveFields.preview:value(preview.text .. " *")
        else
            state.liveFields.preview:value(preview.text)
        end
    end
end

local function render()
    local app = rfsuite.app

    state.liveFields = {}

    form.clear()
    app.ui.fieldHeader(state.title)

    if state.loading then
        form.addLine("Loading adjustment ranges...")
        return
    end

    if state.loadError then
        form.addLine("Load error: " .. tostring(state.loadError))
        return
    end

    if #state.adjustmentRanges == 0 then
        form.addLine("No adjustment ranges reported by FC.")
        return
    end

    local width = app.lcdWidth
    local h = app.radio.navbuttonHeight
    local y = app.radio.linePaddingTop
    local rightPadding = 8
    local gap = 6

    local activeCount = countActiveRanges()
    local infoLine = form.addLine("Active ranges: " .. tostring(activeCount) .. " / " .. tostring(#state.adjustmentRanges))
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
    if state.infoMessage then form.addLine(state.infoMessage) end

    local slotOptions = {}
    for i = 1, #state.adjustmentRanges do
        slotOptions[#slotOptions + 1] = "Range " .. tostring(i)
    end
    local slotOptionsTbl = buildChoiceTable(slotOptions, 0)

    local slotLine = form.addLine("Range")
    local addBtn = form.addButton(slotLine, {x = width - rightPadding - math.floor(width * 0.16), y = y, w = math.floor(width * 0.16), h = h}, {
        text = "Add",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function() addRangeSlot() end
    })
    if addBtn and addBtn.enable then addBtn:enable(true) end
    local slotChoice = form.addChoiceField(
        slotLine,
        {x = width - rightPadding - math.floor(width * 0.62), y = y, w = math.floor(width * 0.42), h = h},
        slotOptionsTbl,
        function() return state.selectedRangeIndex end,
        function(value)
            state.selectedRangeIndex = clamp(value or 1, 1, #state.adjustmentRanges)
            state.needsRender = true
        end
    )
    if slotChoice and slotChoice.values then slotChoice:values(slotOptionsTbl) end

    local adjRange = getSelectedRange()
    if not adjRange then return end

    buildFunctionOptions(adjRange.adjFunction)

    local typeLine = form.addLine("Type")
    local typeChoice = form.addChoiceField(
        typeLine,
        {x = width - rightPadding - math.floor(width * 0.45), y = y, w = math.floor(width * 0.45), h = h},
        ADJUST_TYPE_OPTIONS_TBL,
        function() return getAdjustmentType(adjRange) end,
        function(value)
            setTypeForRange(adjRange, value)
            adjRange = sanitizeAdjustmentRange(adjRange)
            state.adjustmentRanges[state.selectedRangeIndex] = adjRange
            state.dirty = true
            state.needsRender = true
        end
    )
    if typeChoice and typeChoice.enable then typeChoice:enable(true) end

    local functionLine = form.addLine("Function")
    local functionChoice = form.addChoiceField(
        functionLine,
        {x = width - rightPadding - math.floor(width * 0.60), y = y, w = math.floor(width * 0.60), h = h},
        state.functionOptions,
        function() return getFunctionChoiceIndex(adjRange.adjFunction or 0) end,
        function(value)
            local fnId = state.functionOptionIds[value or 1] or 0
            setFunctionForRange(adjRange, fnId)
            adjRange = sanitizeAdjustmentRange(adjRange)
            state.adjustmentRanges[state.selectedRangeIndex] = adjRange
            state.dirty = true
            state.needsRender = true
        end
    )
    if functionChoice and functionChoice.values then functionChoice:values(state.functionOptions) end
    if functionChoice and functionChoice.enable then functionChoice:enable(true) end

    local wLive = math.floor(width * 0.24)
    local wChoice = math.floor(width * 0.34)
    local xLive = width - rightPadding - wLive
    local xChoice = xLive - gap - wChoice

    local enaChannelLine = form.addLine("Enable channel")
    local enaChoice = form.addChoiceField(
        enaChannelLine,
        {x = xChoice, y = y, w = wChoice, h = h},
        ENA_CHANNEL_OPTIONS_TBL,
        function()
            if adjRange.enaChannel == ALWAYS_ON_CHANNEL then return 1 end
            return clamp((adjRange.enaChannel or 0) + 2, 2, #ENA_CHANNEL_OPTIONS)
        end,
        function(value)
            if value == 1 then
                adjRange.enaChannel = ALWAYS_ON_CHANNEL
                adjRange.enaRange.start = 1500
                adjRange.enaRange["end"] = 1500
            else
                adjRange.enaChannel = clamp((value or 2) - 2, 0, AUX_CHANNEL_COUNT_FALLBACK - 1)
            end
            state.dirty = true
            state.needsRender = true
        end
    )
    if enaChoice and enaChoice.enable then enaChoice:enable(true) end
    local enaLive = form.addStaticText(enaChannelLine, {x = xLive, y = y, w = wLive, h = h}, "--")
    if enaLive and enaLive.value then state.liveFields.ena = enaLive end

    local wNum = math.floor(width * 0.22)
    local xEnd = width - rightPadding - wNum
    local xStart = xEnd - gap - wNum

    local enaRangeLine = form.addLine("Enable range")
    local enaStart = form.addNumberField(
        enaRangeLine,
        {x = xStart, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return adjRange.enaRange.start end,
        function(value)
            local adjusted = quantizeUs(value)
            adjRange.enaRange.start = adjusted
            if adjRange.enaRange["end"] < adjusted then adjRange.enaRange["end"] = adjusted end
            state.dirty = true
        end
    )
    local enaEnd = form.addNumberField(
        enaRangeLine,
        {x = xEnd, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return adjRange.enaRange["end"] end,
        function(value)
            local adjusted = quantizeUs(value)
            adjRange.enaRange["end"] = adjusted
            if adjRange.enaRange.start > adjusted then adjRange.enaRange.start = adjusted end
            state.dirty = true
        end
    )
    if enaStart and enaStart.step then enaStart:step(RANGE_STEP) end
    if enaEnd and enaEnd.step then enaEnd:step(RANGE_STEP) end
    if enaStart and enaStart.suffix then enaStart:suffix("us") end
    if enaEnd and enaEnd.suffix then enaEnd:suffix("us") end

    local adjChannelLine = form.addLine("Adjust channel")
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
            state.dirty = true
        end
    )
    if adjChoice and adjChoice.enable then adjChoice:enable(true) end
    local adjLive = form.addStaticText(adjChannelLine, {x = xLive, y = y, w = wLive, h = h}, "--")
    if adjLive and adjLive.value then state.liveFields.adj = adjLive end

    local valueCfg = getFunctionById(adjRange.adjFunction)
    local valueMin = valueCfg and valueCfg.min or -32768
    local valueMax = valueCfg and valueCfg.max or 32767

    local valRangeLine = form.addLine("Value range")
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
            state.dirty = true
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
            state.dirty = true
        end
    )
    local adjType = getAdjustmentType(adjRange)
    if adjType ~= 1 then
        if valStart and valStart.enable then valStart:enable(false) end
        if valEnd and valEnd.enable then valEnd:enable(false) end
    end

    if adjType == 2 then
        local stepLine = form.addLine("Step size")
        local stepField = form.addNumberField(
            stepLine,
            {x = xEnd, y = y, w = wNum, h = h},
            ADJ_STEP_MIN,
            ADJ_STEP_MAX,
            function() return adjRange.adjStep end,
            function(value)
                adjRange.adjStep = clamp(math.floor(value), ADJ_STEP_MIN, ADJ_STEP_MAX)
                state.dirty = true
            end
        )
        if stepField and stepField.enable then stepField:enable(true) end
    end

    local range1Label = adjType == 2 and "Decrease range" or "Adjust range"
    local range1Line = form.addLine(range1Label)
    local range1Start = form.addNumberField(
        range1Line,
        {x = xStart, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return adjRange.adjRange1.start end,
        function(value)
            local adjusted = quantizeUs(value)
            adjRange.adjRange1.start = adjusted
            if adjRange.adjRange1["end"] < adjusted then adjRange.adjRange1["end"] = adjusted end
            state.dirty = true
        end
    )
    local range1End = form.addNumberField(
        range1Line,
        {x = xEnd, y = y, w = wNum, h = h},
        RANGE_MIN,
        RANGE_MAX,
        function() return adjRange.adjRange1["end"] end,
        function(value)
            local adjusted = quantizeUs(value)
            adjRange.adjRange1["end"] = adjusted
            if adjRange.adjRange1.start > adjusted then adjRange.adjRange1.start = adjusted end
            state.dirty = true
        end
    )
    if range1Start and range1Start.step then range1Start:step(RANGE_STEP) end
    if range1End and range1End.step then range1End:step(RANGE_STEP) end
    if range1Start and range1Start.suffix then range1Start:suffix("us") end
    if range1End and range1End.suffix then range1End:suffix("us") end

    if adjType == 2 then
        local range2Line = form.addLine("Increase range")
        local range2Start = form.addNumberField(
            range2Line,
            {x = xStart, y = y, w = wNum, h = h},
            RANGE_MIN,
            RANGE_MAX,
            function() return adjRange.adjRange2.start end,
            function(value)
                local adjusted = quantizeUs(value)
                adjRange.adjRange2.start = adjusted
                if adjRange.adjRange2["end"] < adjusted then adjRange.adjRange2["end"] = adjusted end
                state.dirty = true
            end
        )
        local range2End = form.addNumberField(
            range2Line,
            {x = xEnd, y = y, w = wNum, h = h},
            RANGE_MIN,
            RANGE_MAX,
            function() return adjRange.adjRange2["end"] end,
            function(value)
                local adjusted = quantizeUs(value)
                adjRange.adjRange2["end"] = adjusted
                if adjRange.adjRange2.start > adjusted then adjRange.adjRange2.start = adjusted end
                state.dirty = true
            end
        )
        if range2Start and range2Start.step then range2Start:step(RANGE_STEP) end
        if range2End and range2End.step then range2End:step(RANGE_STEP) end
        if range2Start and range2Start.suffix then range2Start:suffix("us") end
        if range2End and range2End.suffix then range2End:suffix("us") end
    end

    local previewLine = form.addLine("Current output")
    local preview = form.addStaticText(previewLine, {x = width - rightPadding - math.floor(width * 0.45), y = y, w = math.floor(width * 0.45), h = h}, "-")
    if preview and preview.value then state.liveFields.preview = preview end
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
    state.saving = true
    state.saveError = nil
    rfsuite.app.ui.progressDisplay("Adjustment Functions", "Saving adjustment ranges")

    local slot = 1
    local total = #state.adjustmentRanges

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

        queueSetAdjustmentRange(slot, function()
            slot = slot + 1
            writeNext()
        end, failed)
    end

    writeNext()
end

local function onSaveMenu()
    if state.loading or state.saving or not state.loaded then return end
    if not state.dirty then return end

    if hasActiveAutoDetect() then
        local buttons = {{label = "OK", action = function() return true end}}
        form.openDialog({
            width = nil,
            title = "Adjustment Functions",
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
    rfsuite.app.ui.openMainMenuSub("advanced")
    return true
end

local function wakeup()
    if state.needsRender then
        render()
        state.needsRender = false
    end

    if not state.loaded or state.loading then return end
    if state.saving then return end

    updateLiveFields()
end

local function openPage(opts)
    local idx = opts.idx
    state.title = opts.title or "Adjustment Functions"

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = state.title
    rfsuite.app.lastScript = opts.script
    rfsuite.session.lastPage = opts.script

    buildFunctionOptions(nil)
    startLoad()
    state.needsRender = true
end

return {
    title = "Adjustment Functions",
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
