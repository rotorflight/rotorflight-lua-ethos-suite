--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "PILOT_CONFIG"
local MSP_API_CMD_READ = 12
local MSP_API_CMD_WRITE = 13
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "model_id",               type = "U8",  apiVersion = {12, 0, 7}, simResponse = {3}},
    { field = "model_param1_type",      type = "U8",  apiVersion = {12, 0, 7}, simResponse = {0}},
    { field = "model_param1_value",     type = "U16", apiVersion = {12, 0, 7}, simResponse = {44, 1}, unit = "s", min = 0, max = 3600},
    { field = "model_param2_type",      type = "U8",  apiVersion = {12, 0, 7}, simResponse = {0}},
    { field = "model_param2_value",     type = "U16", apiVersion = {12, 0, 7}, simResponse = {20, 0}},
    { field = "model_param3_type",      type = "U8",  apiVersion = {12, 0, 7}, simResponse = {20}},
    { field = "model_param3_value",     type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 30}},
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function parseRead(buf)
    local result = nil
    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)
    if result == nil then
        return nil, "parse_failed"
    end
    return result
end

local function buildWritePayload(payloadData, _, _, state)
    local writeStructure = MSP_API_STRUCTURE_WRITE
    if writeStructure == nil then return {} end
    return core.buildWritePayload(API_NAME, payloadData, writeStructure, state.rebuildOnWrite == true)
end

return factory.create({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minBytes = MSP_MIN_BYTES or 0,
    readStructure = MSP_API_STRUCTURE_READ,
    writeStructure = MSP_API_STRUCTURE_WRITE,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE or {},
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = (MSP_REBUILD_ON_WRITE == true),
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
