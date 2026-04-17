--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local API_NAME = "RXFAIL_CONFIG"
local MAX_SUPPORTED_RC_CHANNEL_COUNT = 18

local modeTable = {
    [0] = "@i18n(api.RXFAIL_CONFIG.tbl_auto)@",
    [1] = "@i18n(api.RXFAIL_CONFIG.tbl_hold)@",
    [2] = "@i18n(api.RXFAIL_CONFIG.tbl_set)@"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local READ_FIELD_SPEC = {}
for i = 1, MAX_SUPPORTED_RC_CHANNEL_COUNT do
    local mandatory = (i == 1)
    READ_FIELD_SPEC[#READ_FIELD_SPEC + 1] = {"channel_" .. i .. "_mode", "U8", nil, nil, nil, nil, nil, nil, nil, nil, modeTable, nil, mandatory}
    READ_FIELD_SPEC[#READ_FIELD_SPEC + 1] = {"channel_" .. i .. "_value", "U16", 885, 2115, 1500, "us", nil, nil, nil, nil, nil, nil, mandatory}
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local WRITE_FIELD_SPEC = {
    {"index", "U8"},
    {"mode", "U8"},
    {"value", "U16"}
}

local READ_STRUCT, MIN_BYTES = core.buildStructure(READ_FIELD_SPEC)
local WRITE_STRUCT = select(1, core.buildStructure(WRITE_FIELD_SPEC))

local function buildSimResponse()
    local bytes = {}
    for _ = 1, MAX_SUPPORTED_RC_CHANNEL_COUNT do
        bytes[#bytes + 1] = 0    -- mode
        bytes[#bytes + 1] = 220  -- value lo (1500us)
        bytes[#bytes + 1] = 5    -- value hi
    end
    return bytes
end

local SIM_RESPONSE = core.simResponse(buildSimResponse())

local function parseRead(buf)
    return core.parseStructure(API_NAME, buf, READ_STRUCT)
end

local function normalizeWriteItems(payloadData, parsed)
    local items = {}

    for channelIndex = 1, MAX_SUPPORTED_RC_CHANNEL_COUNT do
        local modeField = "channel_" .. channelIndex .. "_mode"
        local valueField = "channel_" .. channelIndex .. "_value"
        local parsedMode = parsed and parsed[modeField] or nil
        local parsedValue = parsed and parsed[valueField] or nil
        local channelAvailable = (not parsed) or (parsedMode ~= nil) or (parsedValue ~= nil)

        if channelAvailable then
            local mode = payloadData[modeField]
            if mode == nil and parsed then mode = parsedMode end
            if mode == nil then mode = 0 end

            local value = payloadData[valueField]
            if value == nil and parsed then value = parsedValue end
            if value == nil then value = 1500 end

            local modeNum = math.floor(tonumber(mode) or 0)
            local valueNum = math.floor(tonumber(value) or 1500)

            local changed = true
            if parsed then
                local prevMode = math.floor(tonumber(parsedMode) or modeNum)
                local prevValue = math.floor(tonumber(parsedValue) or valueNum)
                changed = not (prevMode == modeNum and prevValue == valueNum)
            end

            if changed then
                local writeData = {
                    index = channelIndex - 1,
                    mode = modeNum,
                    value = valueNum
                }
                items[#items + 1] = {
                    index = channelIndex - 1,
                    payload = core.buildFullPayload(API_NAME, writeData, WRITE_STRUCT)
                }
            end
        end
    end

    return items
end

return core.createCustomAPI({
    name = API_NAME,
    readCmd = 77,
    writeCmd = 78,
    minBytes = MIN_BYTES,
    readStructure = READ_STRUCT,
    writeStructure = WRITE_STRUCT,
    simulatorResponseRead = SIM_RESPONSE,
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
            return queue:add({
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
            })
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
                processReply = function()
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
    end,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
