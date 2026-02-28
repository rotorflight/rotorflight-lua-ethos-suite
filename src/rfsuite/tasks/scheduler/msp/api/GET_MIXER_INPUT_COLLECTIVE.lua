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

local API_NAME = "GET_MIXER_INPUT_COLLECTIVE"
local FIXED_INDEX = 4

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "rate_stabilized_collective", type = "U16", apiVersion = {12, 0, 9}, simResponse = { 250, 0 }},
    { field = "min_stabilized_collective",  type = "U16", apiVersion = {12, 0, 9}, simResponse = { 30, 251 } },
    { field = "max_stabilized_collective",  type = "U16", apiVersion = {12, 0, 9}, simResponse = { 226, 4 } },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "index", type = "U8" },
    { field = "rate_stabilized_collective",  type = "U16" },
    { field = "min_stabilized_collective",   type = "U16" },
    { field = "max_stabilized_collective",   type = "U16" },
}

local function parseRead(buf)
    local result = nil
    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)
    if result == nil then return nil, "parse_failed" end
    return result
end

local function buildReadPayload()
    return { FIXED_INDEX }
end

local function buildWritePayload(payloadData, mspData)
    local parsed = mspData and mspData.parsed or {}
    local v = {
        index = FIXED_INDEX,
        rate_stabilized_collective = (payloadData.rate_stabilized_collective ~= nil) and payloadData.rate_stabilized_collective or parsed.rate_stabilized_collective,
        min_stabilized_collective = (payloadData.min_stabilized_collective ~= nil) and payloadData.min_stabilized_collective or parsed.min_stabilized_collective,
        max_stabilized_collective = (payloadData.max_stabilized_collective ~= nil) and payloadData.max_stabilized_collective or parsed.max_stabilized_collective,
    }
    return core.buildFullPayload(API_NAME, v, MSP_API_STRUCTURE_WRITE)
end

local function resolveReadUUID(state)
    return (state.uuid or API_NAME) .. FIXED_INDEX
end

local function resolveWriteUUID(state)
    local base = state.uuid
    if not base then
        local utils = rfsuite and rfsuite.utils
        base = (utils and utils.uuid and utils.uuid()) or tostring(os.clock())
    end
    return base .. FIXED_INDEX
end

return factory.create({
    name = API_NAME,
    readCmd = 174,
    writeCmd = 171,
    minBytes = MSP_MIN_BYTES,
    readStructure = MSP_API_STRUCTURE_READ,
    writeStructure = MSP_API_STRUCTURE_WRITE,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE,
    parseRead = parseRead,
    buildReadPayload = buildReadPayload,
    buildWritePayload = buildWritePayload,
    resolveReadUUID = resolveReadUUID,
    resolveWriteUUID = resolveWriteUUID,
    initialRebuildOnWrite = true,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
