--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "ADJUSTMENT_RANGES"
local MSP_API_CMD_READ = 52
local MSP_MIN_BYTES = 0
local ADJUSTMENT_RANGE_BYTES = 14
local ADJUSTMENT_RANGE_MAX = 42

local mspData = nil
local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local function parseAdjustmentRanges(buf)
    local parsed = {}
    local ranges = {}
    local byteCount = #buf or 0

    -- Safety: adjustment ranges are fixed-size records (14 bytes each).
    -- Parse a bounded number of records to avoid instruction spikes on malformed payloads.
    local slotCount = math.floor(byteCount / ADJUSTMENT_RANGE_BYTES)
    if slotCount > ADJUSTMENT_RANGE_MAX then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ADJUSTMENT_RANGES slot count clamped from " .. tostring(slotCount) .. " to " .. tostring(ADJUSTMENT_RANGE_MAX), "info")
        end
        slotCount = ADJUSTMENT_RANGE_MAX
    end
    if (byteCount % ADJUSTMENT_RANGE_BYTES) ~= 0 and rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log("ADJUSTMENT_RANGES payload not aligned: " .. tostring(byteCount) .. " bytes", "debug")
    end

    buf.offset = 1
    for _ = 1, slotCount do
        local adjFunction = rfsuite.tasks.msp.mspHelper.readU8(buf)
        if adjFunction == nil then break end

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
            break
        end

        ranges[#ranges + 1] = {
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

    parsed.adjustment_ranges = ranges
    return {parsed = parsed, buffer = buf}
end

local function read()
    local message = {
        command = MSP_API_CMD_READ,
        apiname = API_NAME,
        processReply = function(self, buf)
            mspData = parseAdjustmentRanges(buf)
            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then completeHandler(self, buf) end
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = {},
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT
    }

    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData.parsed then return mspData.parsed[fieldName] end
    return nil
end

local function readComplete() return mspData ~= nil and #mspData.buffer >= MSP_MIN_BYTES end
local function data() return mspData end
local function setUUID(uuid) MSP_API_UUID = uuid end
local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end
local function setRebuildOnWrite(_) end

return {
    read = read,
    setRebuildOnWrite = setRebuildOnWrite,
    readComplete = readComplete,
    readValue = readValue,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}
