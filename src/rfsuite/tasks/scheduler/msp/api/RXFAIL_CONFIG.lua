--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "RXFAIL_CONFIG"
local MAX_SUPPORTED_RC_CHANNEL_COUNT = 18

local MSP_API_STRUCTURE_READ_DATA = {}
for i = 1, MAX_SUPPORTED_RC_CHANNEL_COUNT do
    local mandatory = (i == 1)
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = {
        field = "channel_" .. i .. "_mode",
        type = "U8",
        apiVersion = {12, 0, 6},
        mandatory = mandatory,
        simResponse = {0},
        table = {
            [0] = "@i18n(api.RXFAIL_CONFIG.tbl_auto)@",
            [1] = "@i18n(api.RXFAIL_CONFIG.tbl_hold)@",
            [2] = "@i18n(api.RXFAIL_CONFIG.tbl_set)@"
        },
        help = "@i18n(api.RXFAIL_CONFIG.channel_mode)@"
    }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = {
        field = "channel_" .. i .. "_value",
        type = "U16",
        apiVersion = {12, 0, 6},
        mandatory = mandatory,
        simResponse = {220, 5},
        min = 885,
        max = 2115,
        default = 1500,
        unit = "us",
        help = "@i18n(api.RXFAIL_CONFIG.channel_value)@"
    }
end

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "index", type = "U8" },
    { field = "mode",  type = "U8" },
    { field = "value", type = "U16" },
}

local function parseRead(buf)
    local result = nil
    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)
    if result == nil then return nil, "parse_failed" end
    return result
end

local function normalizeWriteItems(payloadData, parsed)
    local math_floor = math.floor
    local items = {}

    for channelIndex = 1, MAX_SUPPORTED_RC_CHANNEL_COUNT do
        local modeField = "channel_" .. channelIndex .. "_mode"
        local valueField = "channel_" .. channelIndex .. "_value"

        local mode = payloadData[modeField]
        if mode == nil and parsed then mode = parsed[modeField] end
        if mode == nil then mode = 0 end

        local value = payloadData[valueField]
        if value == nil and parsed then value = parsed[valueField] end
        if value == nil then value = 1500 end

        local modeNum = math_floor(tonumber(mode) or 0)
        local valueNum = math_floor(tonumber(value) or 1500)

        local changed = true
        if parsed then
            local prevMode = math_floor(tonumber(parsed[modeField]) or 0)
            local prevValue = math_floor(tonumber(parsed[valueField]) or 0)
            changed = not (prevMode == modeNum and prevValue == valueNum)
        end

        if changed then
            local writeData = {
                index = channelIndex - 1,
                mode = modeNum,
                value = valueNum
            }
            local payload = core.buildFullPayload(API_NAME, writeData, MSP_API_STRUCTURE_WRITE)
            items[#items + 1] = {
                index = channelIndex - 1,
                payload = payload
            }
        end
    end

    return items
end

return factory.create({
    name = API_NAME,
    readCmd = 77,
    minBytes = MSP_MIN_BYTES,
    readStructure = MSP_API_STRUCTURE_READ,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE,
    parseRead = parseRead,
    customWrite = function(suppliedPayload, state, emitComplete, emitError)
        local queue = rfsuite.tasks.msp.mspQueue
        local timeout = state.timeout

        local baseUuid = state.uuid
        if not baseUuid then
            local utils = rfsuite and rfsuite.utils
            baseUuid = (utils and utils.uuid and utils.uuid()) or tostring(os.clock())
        end

        state.mspWriteComplete = false

        if suppliedPayload then
            local message = {
                command = 78,
                apiname = API_NAME,
                payload = suppliedPayload,
                processReply = function(self, buf)
                    state.mspWriteComplete = true
                    emitComplete(self, buf)
                end,
                errorHandler = function(self, err)
                    emitError(self, err)
                end,
                simulatorResponse = {},
                uuid = baseUuid,
                timeout = timeout
            }
            return queue:add(message)
        end

        local parsed = state.mspData and state.mspData.parsed or nil
        local items = normalizeWriteItems(state.payloadData, parsed)

        if #items == 0 then
            state.mspWriteComplete = true
            emitComplete(nil, nil)
            return true
        end

        local idx = 1
        local function sendNext()
            local item = items[idx]
            if not item then
                state.mspWriteComplete = true
                emitComplete(nil, nil)
                return true
            end

            idx = idx + 1
            local message = {
                command = 78,
                apiname = API_NAME,
                payload = item.payload,
                processReply = function(self, buf)
                    sendNext()
                end,
                errorHandler = function(self, err)
                    emitError(self, err)
                end,
                simulatorResponse = {},
                uuid = tostring(baseUuid) .. "-" .. tostring(item.index + 1),
                timeout = timeout
            }

            local ok, reason = queue:add(message)
            if not ok then
                emitError(message, reason)
                return false, reason
            end

            return true
        end

        return sendNext()
    end,
    initialRebuildOnWrite = true,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
