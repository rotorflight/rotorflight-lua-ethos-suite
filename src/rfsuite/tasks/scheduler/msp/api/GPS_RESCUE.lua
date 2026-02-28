--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "GPS_RESCUE"
local MSP_API_CMD_READ = 135
local MSP_API_CMD_WRITE = 225
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "angle",                    type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "initial_altitude_m",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {100, 0} },
    { field = "descent_distance_m",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {100, 0} },
    { field = "rescue_groundspeed",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {200, 0} },
    { field = "throttle_min",             type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "throttle_max",             type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "throttle_hover",           type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "sanity_checks",            type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "min_sats",                 type = "U8",  apiVersion = {12, 0, 6}, simResponse = {6} },
    { field = "ascend_rate",              type = "U16", apiVersion = {12, 43}, simResponse = {0, 0} },
    { field = "descend_rate",             type = "U16", apiVersion = {12, 43}, simResponse = {0, 0} },
    { field = "allow_arming_without_fix", type = "U8",  apiVersion = {12, 43}, simResponse = {0} },
    { field = "altitude_mode",            type = "U8",  apiVersion = {12, 43}, simResponse = {0} },
    { field = "min_rescue_dth",           type = "U16", apiVersion = {12, 44}, simResponse = {0, 0} },
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
    writeRequiresStructure = true,
    writeUuidFallback = true,
    initialRebuildOnWrite = (MSP_REBUILD_ON_WRITE == true),
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
