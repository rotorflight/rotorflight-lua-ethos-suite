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
local legacyCore = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = legacyCore
end

local API_NAME = "GET_MIXER_INPUT_ROLL"
local FIXED_INDEX = 1

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"rate_stabilized_roll", "U16"},
    {"min_stabilized_roll", "U16"},
    {"max_stabilized_roll", "U16"}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"index", "U8"},
    {"rate_stabilized_roll", "U16"},
    {"min_stabilized_roll", "U16"},
    {"max_stabilized_roll", "U16"}
}

local function buildReadPayload()
    return {FIXED_INDEX}
end

local function buildWritePayload(payloadData, mspData, helper)
    local parsed = mspData and mspData.parsed or {}
    local values = {
        index = FIXED_INDEX,
        rate_stabilized_roll = (payloadData.rate_stabilized_roll ~= nil) and payloadData.rate_stabilized_roll or parsed.rate_stabilized_roll,
        min_stabilized_roll = (payloadData.min_stabilized_roll ~= nil) and payloadData.min_stabilized_roll or parsed.min_stabilized_roll,
        max_stabilized_roll = (payloadData.max_stabilized_roll ~= nil) and payloadData.max_stabilized_roll or parsed.max_stabilized_roll
    }
    return legacyCore.buildFullPayload(API_NAME, values, {
        {field = "index", type = "U8"},
        {field = "rate_stabilized_roll", type = "U16"},
        {field = "min_stabilized_roll", type = "U16"},
        {field = "max_stabilized_roll", type = "U16"},
    })
end

local SIM_RESPONSE = core.simResponse({
    250, 0, -- rate_stabilized_roll
    30, 251, -- min_stabilized_roll
    226, 4  -- max_stabilized_roll
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
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true
})
