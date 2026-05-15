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

local taskComplete = false
local startAt = 0
local nextActionAt = 0
local state = "idle"

local sensor = nil
local deviceId = CRSF_ADDRESS_CRSF_TRANSMITTER
local fieldCount = 0
local currentField = 1
local currentChunk = 0
local fieldData = {}
local moduleRateLabel = nil
local moduleRatioLabel = nil

local function clearFieldData()
    for i = #fieldData, 1, -1 do
        fieldData[i] = nil
    end
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

local function parseTelemetryField()
    if #fieldData < 3 then return end

    local fieldType = bit32.band(fieldData[2] or 0, 0x7F)
    local hidden = bit32.band(fieldData[2] or 0, 0x80)
    if hidden ~= 0 or fieldType ~= TYPE_TEXT_SELECTION then return end

    local name, offset = readString(fieldData, 3)
    local value = parseChoiceValue(fieldData, offset)
    if not value then return end

    local lowerName = string_lower(name)
    if moduleRateLabel == nil and (string_find(lowerName, "packet rate", 1, true) or string_find(lowerName, "rf mode", 1, true)) then
        moduleRateLabel = value
        return
    end

    if moduleRatioLabel == nil and (string_find(lowerName, "telem ratio", 1, true) or string_find(lowerName, "telemetry ratio", 1, true)) then
        moduleRatioLabel = value
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

local function telemetryModeLabel(mode)
    if mode == 0 then return "native" end
    if mode == 1 then return "custom" end
    return tostring(mode)
end

local function finalize()
    local session = rfsuite.session
    local fcConfig = session and session.crsfTelemetryConfig

    local moduleRate = extractFirstInteger(moduleRateLabel)
    local moduleRatio, ratioKind = parseRatioLabel(moduleRatioLabel)

    session.elrsLinkConfig = {
        packetRateLabel = moduleRateLabel,
        packetRate = moduleRate,
        telemetryRatioLabel = moduleRatioLabel,
        telemetryRatio = moduleRatio,
        telemetryRatioKind = ratioKind
    }

    if moduleRateLabel and moduleRatioLabel then
        rfsuite.utils.log(
            "ELRS module link: rate=" .. tostring(moduleRateLabel) .. ", ratio=" .. tostring(moduleRatioLabel),
            "connect"
        )
    else
        rfsuite.utils.log("ELRS module link settings were not fully discovered", "info")
    end

    if fcConfig then
        rfsuite.utils.log(
            "Rotorflight CRSF telemetry: mode="
                .. telemetryModeLabel(fcConfig.mode)
                .. ", rate="
                .. tostring(fcConfig.linkRate)
                .. ", ratio=1:"
                .. tostring(fcConfig.linkRatio),
            "info"
        )

        if moduleRate and moduleRatio then
            if fcConfig.linkRate == moduleRate and fcConfig.linkRatio == moduleRatio then
                rfsuite.utils.log("ELRS module telemetry matches Rotorflight", "connect")
            else
                rfsuite.utils.log(
                    "ELRS telemetry mismatch: module "
                        .. tostring(moduleRateLabel)
                        .. " / "
                        .. tostring(moduleRatioLabel)
                        .. ", Rotorflight "
                        .. tostring(fcConfig.linkRate)
                        .. "Hz / 1:"
                        .. tostring(fcConfig.linkRatio),
                    "connect"
                )
            end
        elseif moduleRate and fcConfig.linkRate ~= moduleRate then
            rfsuite.utils.log(
                "ELRS packet-rate mismatch: module "
                    .. tostring(moduleRateLabel)
                    .. ", Rotorflight "
                    .. tostring(fcConfig.linkRate)
                    .. "Hz",
                "connect"
            )
        elseif ratioKind == "std" or ratioKind == "race" or ratioKind == "off" then
            rfsuite.utils.log(
                "ELRS telemetry ratio '" .. tostring(moduleRatioLabel) .. "' is not an explicit 1:n value, so it was not matched numerically",
                "info"
            )
        end
    end

    state = "done"
    taskComplete = true
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
    startAt = 0
    nextActionAt = 0
    state = "idle"
    sensor = nil
    deviceId = CRSF_ADDRESS_CRSF_TRANSMITTER
    fieldCount = 0
    currentField = 1
    currentChunk = 0
    moduleRateLabel = nil
    moduleRatioLabel = nil
    clearFieldData()
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
    clearFieldData()
    state = "read"
    nextActionAt = 0

    if fieldCount <= 0 then
        finalize()
    end
end

local function handleParameterEntry(data)
    if state ~= "read" then return end
    if data[2] ~= deviceId or data[3] ~= currentField then return end

    local chunksRemain = data[4] or 0
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
        if startAt == 0 then
            startAt = now
        elseif (now - startAt) >= DISCOVERY_TIMEOUT_SECONDS then
            rfsuite.utils.log("Skipping ELRS link probe because CRSF telemetry config was not ready", "info")
            taskComplete = true
        end
        return
    end

    if startAt == 0 then
        startAt = now
        state = "ping"
        nextActionAt = 0
    end

    processIncomingFrames()
    if taskComplete then return end

    if (now - startAt) >= DISCOVERY_TIMEOUT_SECONDS and state == "ping" then
        rfsuite.utils.log("No ELRS TX module responded to the CRSF parameter probe", "info")
        taskComplete = true
        return
    end

    if state == "read" and (now - startAt) >= READ_TIMEOUT_MAX_SECONDS then
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
