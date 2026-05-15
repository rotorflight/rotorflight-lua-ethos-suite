--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local elrslink = {}

local os_clock = os.clock
local string_find = string.find
local string_gmatch = string.gmatch
local string_lower = string.lower
local tonumber = tonumber
local tostring = tostring
local type = type

local CRSF_FRAMETYPE_DEVICE_PING = 0x28
local CRSF_FRAMETYPE_DEVICE_INFO = 0x29
local CRSF_FRAMETYPE_PARAMETER_SETTINGS_ENTRY = 0x2B
local CRSF_FRAMETYPE_PARAMETER_READ = 0x2C
local CRSF_FRAMETYPE_PARAMETER_WRITE = 0x2D

local CRSF_ADDRESS_BROADCAST = 0x00
local CRSF_ADDRESS_RADIO_TRANSMITTER = 0xEA
local CRSF_ADDRESS_CRSF_TRANSMITTER = 0xEE
local CRSF_ADDRESS_ELRS_LUA = 0xEF

local ELRS_SERIAL_ID = 0x454C5253
local TYPE_TEXT_SELECTION = 9

local DISCOVERY_TIMEOUT_SECONDS = 4.0
local READ_TIMEOUT_MAX_SECONDS = 8.0
local READ_TIMEOUT_SECONDS = 0.5
local PING_RETRY_SECONDS = 1.0
local WRITE_DELAY_SECONDS = 0.25
local STD_TLM_RATIO_BY_PACKET_RATE = {
    [25] = 8,
    [50] = 16,
    [100] = 32,
    [150] = 32,
    [200] = 64,
    [250] = 64,
    [333] = 128,
    [500] = 128,
    [1000] = 128
}

local taskComplete = false
local configWaitStartedAt = 0
local probeStartedAt = 0
local nextActionAt = 0
local state = "idle"

local sensor = nil
local deviceId = CRSF_ADDRESS_CRSF_TRANSMITTER
local fieldCount = 0
local currentField = 1
local currentChunk = 0
local expectedChunksRemain = -1
local fieldData = {}
local rateField = nil
local ratioField = nil
local moduleRateLabel = nil
local moduleRatioLabel = nil
local pendingWrites = {}
local pendingWriteCount = 0
local pendingWriteIndex = 1

local function clearFieldData()
    for i = #fieldData, 1, -1 do
        fieldData[i] = nil
    end
end

local function clearPendingWrites()
    for i = pendingWriteCount, 1, -1 do
        pendingWrites[i] = nil
    end
    pendingWriteCount = 0
    pendingWriteIndex = 1
end

local function getSensor()
    if sensor ~= nil then return sensor end
    if crsf and crsf.getSensor then
        sensor = crsf.getSensor()
    elseif crsf then
        sensor = {
            popFrame = function(_, ...)
                return crsf.popFrame(...)
            end,
            pushFrame = function(_, command, payload)
                return crsf.pushFrame(command, payload)
            end
        }
    end
    return sensor
end

local function readString(data, offset)
    local parts = {}
    while data[offset] and data[offset] ~= 0 do
        parts[#parts + 1] = string.char(data[offset])
        offset = offset + 1
    end
    return table.concat(parts), offset + 1
end

local function readU32Be(data, offset)
    local value = 0
    for i = 0, 3 do
        value = value * 256 + (data[offset + i] or 0)
    end
    return value
end

local function parseChoiceValue(data, offset)
    local optionsStr
    optionsStr, offset = readString(data, offset)

    local selectedIndex = data[offset] or 0
    local idx = 0
    for part in string_gmatch(optionsStr .. ";", "([^;]*);") do
        if idx == selectedIndex then
            return part
        end
        idx = idx + 1
    end

    return nil
end

local function parseChoiceField(data, offset)
    local optionsStr
    local options = {}
    local selectedIndex = 0
    local selectedLabel = nil
    local idx = 0

    optionsStr, offset = readString(data, offset)
    selectedIndex = data[offset] or 0

    for part in string_gmatch(optionsStr .. ";", "([^;]*);") do
        options[#options + 1] = part
        if idx == selectedIndex then
            selectedLabel = part
        end
        idx = idx + 1
    end

    return options, selectedIndex, selectedLabel
end

local function optionLooksLikeRatio(text)
    local lowerText = string_lower(text or "")
    if string_find(lowerText, "std", 1, true) then return true end
    if string_find(lowerText, "race", 1, true) then return true end
    if string_find(lowerText, "1:", 1, true) then return true end
    return false
end

local function optionLooksLikeRate(text)
    local lowerText = string_lower(text or "")
    if string_find(lowerText, "hz", 1, true) then return true end
    if string_find(lowerText, "dbm", 1, true) then return true end
    if lowerText:match("^%s*[a-z]+%d") then return true end
    return false
end

local function classifyChoiceField(lowerName, options)
    local hasRateOptions = false
    local hasRatioOptions = false

    if string_find(lowerName, "packet rate", 1, true)
        or string_find(lowerName, "pkt rate", 1, true)
        or string_find(lowerName, "air rate", 1, true)
        or string_find(lowerName, "rf mode", 1, true) then
        return "rate"
    end

    if string_find(lowerName, "telem ratio", 1, true)
        or string_find(lowerName, "telemetry ratio", 1, true) then
        return "ratio"
    end

    for i = 1, #options do
        if optionLooksLikeRate(options[i]) then
            hasRateOptions = true
        end
        if optionLooksLikeRatio(options[i]) then
            hasRatioOptions = true
        end
    end

    if hasRateOptions and not hasRatioOptions then
        return "rate"
    end
    if hasRatioOptions and not hasRateOptions then
        return "ratio"
    end

    return nil
end

local function recordChoiceField(kind, fieldId, name, options, selectedIndex, selectedLabel)
    local field = {
        id = fieldId,
        name = name,
        options = options,
        selectedIndex = selectedIndex,
        selectedLabel = selectedLabel
    }

    if kind == "rate" then
        rateField = field
        moduleRateLabel = selectedLabel
    elseif kind == "ratio" then
        ratioField = field
        moduleRatioLabel = selectedLabel
    end
end

local function parseTelemetryField()
    if #fieldData < 3 then return end

    local fieldTypeByte = fieldData[2] or 0
    local fieldType = fieldTypeByte % 128
    local hidden = fieldTypeByte >= 128
    if hidden or fieldType ~= TYPE_TEXT_SELECTION then return end

    local name, offset = readString(fieldData, 3)
    local options, selectedIndex, selectedLabel = parseChoiceField(fieldData, offset)
    local lowerName = string_lower(name)
    local fieldKind = classifyChoiceField(lowerName, options)
    if selectedLabel == nil or fieldKind == nil then return end

    if fieldKind == "rate" and rateField == nil then
        recordChoiceField("rate", currentField, name, options, selectedIndex, selectedLabel)
        return
    end

    if fieldKind == "ratio" and ratioField == nil then
        recordChoiceField("ratio", currentField, name, options, selectedIndex, selectedLabel)
    end
end

local function extractFirstInteger(text)
    if type(text) ~= "string" then return nil end
    for digits in string_gmatch(text, "(%d+)") do
        return tonumber(digits)
    end
    return nil
end

local function parseRatioLabel(label)
    if type(label) ~= "string" or label == "" then
        return nil, "unknown"
    end

    local lowerLabel = string_lower(label)

    if string_find(lowerLabel, "std", 1, true) then
        return nil, "std"
    end
    if string_find(lowerLabel, "race", 1, true) then
        return nil, "race"
    end
    if string_find(lowerLabel, "off", 1, true) then
        return nil, "off"
    end

    local ratio = string_gmatch(lowerLabel, "1%s*:%s*(%d+)")
    local digits = ratio()
    if digits then
        return tonumber(digits), "explicit"
    end

    return nil, "unknown"
end

local function resolveStdRatioForRate(packetRate)
    if type(packetRate) ~= "number" then return nil end
    return STD_TLM_RATIO_BY_PACKET_RATE[packetRate]
end

local function resolveEffectiveRatio(packetRate, ratioKind, explicitRatio)
    if ratioKind == "explicit" then
        return explicitRatio
    end

    if ratioKind == "std" or ratioKind == "race" then
        return resolveStdRatioForRate(packetRate)
    end

    return nil
end

local function formatRatioSummary(ratioLabel, ratioKind, effectiveRatio)
    if type(ratioLabel) ~= "string" or ratioLabel == "" then
        return "unknown"
    end

    if ratioKind == "std" and effectiveRatio then
        return ratioLabel .. " (effective 1:" .. tostring(effectiveRatio) .. ")"
    end

    if ratioKind == "race" and effectiveRatio then
        return ratioLabel .. " (disarmed 1:" .. tostring(effectiveRatio) .. ", armed Off)"
    end

    return ratioLabel
end

local function getRateLabelStyle(label)
    local lowerLabel = string_lower(label or "")
    local prefix = lowerLabel:match("^%s*([a-z]+)%d") or ""
    local isFull = string_find(lowerLabel, "full", 1, true) ~= nil
    return prefix, isFull
end

local function findRateTarget(field, targetRate)
    if type(field) ~= "table" or type(field.options) ~= "table" then return nil, nil end

    local currentPrefix, currentIsFull = getRateLabelStyle(field.selectedLabel)
    local haveCurrentStyle = type(field.selectedLabel) == "string" and field.selectedLabel ~= ""
    local bestIndex = nil
    local bestLabel = nil
    local bestScore = nil

    for i = 1, #field.options do
        local label = field.options[i]
        if extractFirstInteger(label) == targetRate then
            local prefix, isFull = getRateLabelStyle(label)
            local score = 0

            if haveCurrentStyle then
                if prefix == currentPrefix then score = score + 4 end
                if isFull == currentIsFull then score = score + 2 end
            else
                if prefix == "" then score = score + 2 end
                if not isFull then score = score + 1 end
            end

            if string_find(string_lower(label), "dbm", 1, true) then
                score = score + 1
            end

            if bestScore == nil or score > bestScore then
                bestScore = score
                bestIndex = i - 1
                bestLabel = label
            end
        end
    end

    return bestIndex, bestLabel
end

local function findRatioTarget(field, targetRatio)
    if type(field) ~= "table" or type(field.options) ~= "table" then return nil, nil end

    for i = 1, #field.options do
        local label = field.options[i]
        local explicitRatio, ratioKind = parseRatioLabel(label)
        if ratioKind == "explicit" and explicitRatio == targetRatio then
            return i - 1, label
        end
    end

    return nil, nil
end

local function enqueueWrite(fieldKind, field, targetIndex, targetLabel)
    pendingWriteCount = pendingWriteCount + 1
    pendingWrites[pendingWriteCount] = {
        fieldKind = fieldKind,
        fieldId = field.id,
        fieldName = field.name,
        value = targetIndex,
        label = targetLabel
    }
end

local function completeTask()
    state = "done"
    taskComplete = true
end

local function telemetryModeLabel(mode)
    if mode == 0 then return "native" end
    if mode == 1 then return "custom" end
    return tostring(mode)
end

local function finalize()
    local session = rfsuite.session
    local fcConfig = session and session.crsfTelemetryConfig

    if rateField then moduleRateLabel = rateField.selectedLabel end
    if ratioField then moduleRatioLabel = ratioField.selectedLabel end

    local moduleRate = extractFirstInteger(moduleRateLabel)
    local explicitRatio, ratioKind = parseRatioLabel(moduleRatioLabel)
    local effectiveRatio = resolveEffectiveRatio(moduleRate, ratioKind, explicitRatio)
    local ratioSummary = formatRatioSummary(moduleRatioLabel, ratioKind, effectiveRatio)
    local rateTargetIndex = nil
    local rateTargetLabel = nil
    local ratioTargetIndex = nil
    local ratioTargetLabel = nil

    session.elrsLinkConfig = {
        packetRateLabel = moduleRateLabel,
        packetRate = moduleRate,
        telemetryRatioLabel = moduleRatioLabel,
        telemetryRatio = effectiveRatio,
        telemetryRatioEffective = effectiveRatio,
        telemetryRatioDisarmed = ratioKind == "race" and effectiveRatio or nil,
        telemetryRatioExplicit = explicitRatio,
        telemetryRatioKind = ratioKind
    }

    if moduleRateLabel and moduleRatioLabel then
        rfsuite.utils.log(
            "ELRS module link: rate=" .. tostring(moduleRateLabel) .. ", ratio=" .. ratioSummary,
            "connect"
        )
    else
        rfsuite.utils.log(
            "ELRS module link settings were not fully discovered (rate="
                .. tostring(moduleRateLabel or "?")
                .. ", ratio="
                .. tostring(moduleRatioLabel or "?")
                .. ")",
            "info"
        )
    end

    if fcConfig then
        clearPendingWrites()

        rfsuite.utils.log(
            "Rotorflight CRSF telemetry: mode="
                .. telemetryModeLabel(fcConfig.mode)
                .. ", rate="
                .. tostring(fcConfig.linkRate)
                .. ", ratio=1:"
                .. tostring(fcConfig.linkRatio),
            "info"
        )

        ratioTargetIndex, ratioTargetLabel = findRatioTarget(ratioField, fcConfig.linkRatio)
        rateTargetIndex, rateTargetLabel = findRateTarget(rateField, fcConfig.linkRate)

        if ratioField and ratioTargetIndex ~= nil and ratioField.selectedIndex ~= ratioTargetIndex then
            enqueueWrite("ratio", ratioField, ratioTargetIndex, ratioTargetLabel)
        end

        -- Write rate last because changing the air rate can briefly drop and re-establish the link.
        if rateField and rateTargetIndex ~= nil and rateField.selectedIndex ~= rateTargetIndex then
            enqueueWrite("rate", rateField, rateTargetIndex, rateTargetLabel)
        end

        if pendingWriteCount > 0 then
            local actions = {}
            for i = 1, pendingWriteCount do
                local action = pendingWrites[i]
                actions[#actions + 1] = tostring(action.fieldName) .. " -> " .. tostring(action.label)
            end

            rfsuite.utils.log(
                "Syncing ELRS module to Rotorflight: " .. table.concat(actions, ", "),
                "connect"
            )

            if ratioField == nil then
                rfsuite.utils.log("ELRS sync could not find the module telemetry-ratio field", "info")
            elseif ratioTargetIndex == nil then
                rfsuite.utils.log(
                    "ELRS sync could not map Rotorflight ratio 1:" .. tostring(fcConfig.linkRatio) .. " to a module option",
                    "info"
                )
            end

            if rateField == nil then
                rfsuite.utils.log("ELRS sync could not find the module packet-rate field", "info")
            elseif rateTargetIndex == nil then
                rfsuite.utils.log(
                    "ELRS sync could not map Rotorflight rate " .. tostring(fcConfig.linkRate) .. "Hz to a module option",
                    "info"
                )
            end

            state = "write"
            nextActionAt = 0
            return
        end

        if rateField == nil then
            rfsuite.utils.log("ELRS sync could not find the module packet-rate field", "info")
        elseif rateTargetIndex == nil then
            rfsuite.utils.log(
                "ELRS sync could not map Rotorflight rate " .. tostring(fcConfig.linkRate) .. "Hz to a module option",
                "info"
            )
        end

        if ratioField == nil then
            rfsuite.utils.log("ELRS sync could not find the module telemetry-ratio field", "info")
        elseif ratioTargetIndex == nil then
            rfsuite.utils.log(
                "ELRS sync could not map Rotorflight ratio 1:" .. tostring(fcConfig.linkRatio) .. " to a module option",
                "info"
            )
        end

        if rateField and ratioField and rateTargetIndex == rateField.selectedIndex and ratioTargetIndex == ratioField.selectedIndex then
            rfsuite.utils.log("ELRS module already follows Rotorflight", "connect")
        end
    end

    completeTask()
end

local function shouldSkip()
    local session = rfsuite.session

    if system and system.getVersion and system.getVersion().simulation == true then
        return true
    end
    if not session or session.telemetryType ~= "crsf" then
        return true
    end
    if not (crsf and (crsf.getSensor or crsf.popFrame)) then
        return true
    end
    return false
end

local function resetState()
    taskComplete = false
    configWaitStartedAt = 0
    probeStartedAt = 0
    nextActionAt = 0
    state = "idle"
    sensor = nil
    deviceId = CRSF_ADDRESS_CRSF_TRANSMITTER
    fieldCount = 0
    currentField = 1
    currentChunk = 0
    expectedChunksRemain = -1
    rateField = nil
    ratioField = nil
    moduleRateLabel = nil
    moduleRatioLabel = nil
    clearFieldData()
    clearPendingWrites()
end

local function handleDeviceInfo(data)
    if data[2] ~= CRSF_ADDRESS_CRSF_TRANSMITTER then return end

    local _, offset = readString(data, 3)
    local serial = readU32Be(data, offset)
    if serial ~= ELRS_SERIAL_ID then return end

    deviceId = data[2]
    fieldCount = data[offset + 12] or 0
    currentField = 1
    currentChunk = 0
    expectedChunksRemain = -1
    clearFieldData()
    state = "read"
    nextActionAt = 0

    if fieldCount <= 0 then
        finalize()
    end
end

local function handleParameterEntry(data)
    if state ~= "read" then return end
    if data[2] ~= deviceId or data[3] ~= currentField then
        currentChunk = 0
        expectedChunksRemain = -1
        clearFieldData()
        return
    end

    local chunksRemain = data[4] or 0
    if expectedChunksRemain >= 0 and #fieldData > 0 and chunksRemain ~= expectedChunksRemain then
        currentChunk = 0
        expectedChunksRemain = -1
        clearFieldData()
        nextActionAt = 0
        return
    end
    expectedChunksRemain = chunksRemain - 1

    for i = 5, #data do
        fieldData[#fieldData + 1] = data[i]
    end

    if chunksRemain > 0 then
        currentChunk = currentChunk + 1
        nextActionAt = 0
        return
    end

    parseTelemetryField()

    currentField = currentField + 1
    currentChunk = 0
    expectedChunksRemain = -1
    clearFieldData()
    nextActionAt = 0

    if (moduleRateLabel and moduleRatioLabel) or currentField > fieldCount then
        finalize()
    end
end

local function processIncomingFrames()
    local crsfSensor = getSensor()
    if not crsfSensor then return end

    while true do
        local command, data = crsfSensor:popFrame(CRSF_FRAMETYPE_DEVICE_INFO, CRSF_FRAMETYPE_PARAMETER_SETTINGS_ENTRY)
        if command == nil then
            break
        end

        if command == CRSF_FRAMETYPE_DEVICE_INFO then
            handleDeviceInfo(data)
        elseif command == CRSF_FRAMETYPE_PARAMETER_SETTINGS_ENTRY then
            handleParameterEntry(data)
        end
    end
end

function elrslink.wakeup()
    local session = rfsuite.session
    local now = os_clock()

    if taskComplete then return end

    if shouldSkip() then
        taskComplete = true
        return
    end

    if type(session.crsfTelemetryConfig) ~= "table" then
        if configWaitStartedAt == 0 then
            configWaitStartedAt = now
        elseif (now - configWaitStartedAt) >= DISCOVERY_TIMEOUT_SECONDS then
            rfsuite.utils.log("Skipping ELRS link probe because CRSF telemetry config was not ready", "info")
            taskComplete = true
        end
        return
    end

    if state == "idle" then
        configWaitStartedAt = 0
        probeStartedAt = now
        state = "ping"
        nextActionAt = 0
        rfsuite.utils.log("Starting ELRS link probe", "debug")
    end

    processIncomingFrames()
    if taskComplete then return end

    if state == "ping" and probeStartedAt > 0 and (now - probeStartedAt) >= DISCOVERY_TIMEOUT_SECONDS then
        rfsuite.utils.log("No ELRS TX module responded to the CRSF parameter probe", "info")
        taskComplete = true
        return
    end

    if state == "read" and probeStartedAt > 0 and (now - probeStartedAt) >= READ_TIMEOUT_MAX_SECONDS then
        rfsuite.utils.log("ELRS link probe timed out while reading module parameters", "info")
        finalize()
        return
    end

    local crsfSensor = getSensor()
    if not crsfSensor then
        rfsuite.utils.log("CRSF sensor unavailable for ELRS link probe", "info")
        taskComplete = true
        return
    end

    if now < nextActionAt then return end

    if state == "ping" then
        crsfSensor:pushFrame(CRSF_FRAMETYPE_DEVICE_PING, {CRSF_ADDRESS_BROADCAST, CRSF_ADDRESS_RADIO_TRANSMITTER})
        nextActionAt = now + PING_RETRY_SECONDS
        return
    end

    if state == "read" then
        crsfSensor:pushFrame(
            CRSF_FRAMETYPE_PARAMETER_READ,
            {deviceId, CRSF_ADDRESS_ELRS_LUA, currentField, currentChunk}
        )
        nextActionAt = now + READ_TIMEOUT_SECONDS
        return
    end

    if state == "write" then
        local action = pendingWrites[pendingWriteIndex]
        if not action then
            completeTask()
            return
        end

        crsfSensor:pushFrame(
            CRSF_FRAMETYPE_PARAMETER_WRITE,
            {deviceId, CRSF_ADDRESS_ELRS_LUA, action.fieldId, action.value}
        )

        rfsuite.utils.log(
            "ELRS sync: set " .. tostring(action.fieldName) .. " to " .. tostring(action.label),
            "connect"
        )

        if action.fieldKind == "rate" and rateField then
            rateField.selectedIndex = action.value
            rateField.selectedLabel = action.label
            moduleRateLabel = action.label
        elseif action.fieldKind == "ratio" and ratioField then
            ratioField.selectedIndex = action.value
            ratioField.selectedLabel = action.label
            moduleRatioLabel = action.label
        end

        pendingWriteIndex = pendingWriteIndex + 1
        if pendingWriteIndex > pendingWriteCount then
            if action.fieldKind == "rate" then
                rfsuite.utils.log("ELRS sync requested a packet-rate change; the link may reconnect briefly", "info")
            end
            completeTask()
        else
            nextActionAt = now + WRITE_DELAY_SECONDS
        end
    end
end

function elrslink.reset()
    resetState()
end

function elrslink.isComplete()
    return taskComplete
end

resetState()

return elrslink
