--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicorev2) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/core.lua"))()
if msp and not msp.apicorev2 then
    msp.apicorev2 = core
end
local legacyCore = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = legacyCore
end
local os_clock = os.clock

local API_NAME = "GET_MIXER_INPUT_COLLECTIVE"
local FIXED_INDEX = 4

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"rate_stabilized_collective", "U16"},
    {"min_stabilized_collective", "U16"},
    {"max_stabilized_collective", "U16"}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"index", "U8"},
    {"rate_stabilized_collective", "U16"},
    {"min_stabilized_collective", "U16"},
    {"max_stabilized_collective", "U16"}
}

local function buildReadPayload()
    return {FIXED_INDEX}
end

local function buildWritePayload(payloadData, mspData)
    local parsed = mspData and mspData.parsed or {}
    local values = {
        index = FIXED_INDEX,
        rate_stabilized_collective = (payloadData.rate_stabilized_collective ~= nil) and payloadData.rate_stabilized_collective or parsed.rate_stabilized_collective,
        min_stabilized_collective = (payloadData.min_stabilized_collective ~= nil) and payloadData.min_stabilized_collective or parsed.min_stabilized_collective,
        max_stabilized_collective = (payloadData.max_stabilized_collective ~= nil) and payloadData.max_stabilized_collective or parsed.max_stabilized_collective
    }
    return legacyCore.buildFullPayload(API_NAME, values, {
        {field = "index", type = "U8"},
        {field = "rate_stabilized_collective", type = "U16"},
        {field = "min_stabilized_collective", type = "U16"},
        {field = "max_stabilized_collective", type = "U16"},
    })
end

local function resolveReadUUID(state)
    return (state.uuid or API_NAME) .. FIXED_INDEX
end

local function resolveWriteUUID(state)
    local base = state.uuid
    if not base then
        local utils = rfsuite and rfsuite.utils
        base = (utils and utils.uuid and utils.uuid()) or tostring(os_clock())
    end
    return base .. FIXED_INDEX
end

local SIM_RESPONSE = core.simResponse({
    250, 0, -- rate_stabilized_collective
    30, 251, -- min_stabilized_collective
    226, 4  -- max_stabilized_collective
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = 174,
    writeCmd = 171,
    minApiVersion = {12, 0, 9},
    initialRebuildOnWrite = true,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    buildReadPayload = buildReadPayload,
    buildWritePayload = buildWritePayload,
    resolveReadUUID = resolveReadUUID,
    resolveWriteUUID = resolveWriteUUID,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true
})
