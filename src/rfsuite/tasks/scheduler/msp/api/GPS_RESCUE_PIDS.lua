--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "GPS_RESCUE_PIDS"
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "throttle_p", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "throttle_i", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "throttle_d", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "vel_p",      type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "vel_i",      type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "vel_d",      type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "yaw_p",      type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
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
    return core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, state.rebuildOnWrite == true)
end

return factory.create({
    name = API_NAME,
    readCmd = 136,
    writeCmd = 226,
    minBytes = MSP_MIN_BYTES,
    readStructure = MSP_API_STRUCTURE_READ,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE,
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    writeUuidFallback = true,
    initialRebuildOnWrite = MSP_REBUILD_ON_WRITE,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
