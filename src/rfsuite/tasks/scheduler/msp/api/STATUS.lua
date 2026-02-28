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

local API_NAME = "STATUS"
local MSP_API_CMD_READ = 101
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "task_delta_time_pid", type = "U16", apiVersion = {12, 0, 6}, simResponse = {252, 1}},
    {field = "task_delta_time_gyro", type = "U16", apiVersion = {12, 0, 6}, simResponse = {127, 0}},
    {field = "sensor_status", type = "U16", apiVersion = {12, 0, 6}, simResponse = {35, 0}},
    {field = "flight_mode_flags", type = "U32", apiVersion = {12, 0, 6}, simResponse = {0, 0, 0, 0}},
    {field = "profile_number", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}},
    {field = "max_real_time_load", type = "U16", apiVersion = {12, 0, 6}, simResponse = {122, 1}},
    {field = "average_cpu_load", type = "U16", apiVersion = {12, 0, 6}, simResponse = {182, 0}},
    {field = "extra_flight_mode_flags_count", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}},
    {field = "arming_disable_flags_count", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}},
    {field = "arming_disable_flags", type = "U32", apiVersion = {12, 0, 6}, simResponse = {0, 0, 0, 0}},
    {field = "reboot_required", type = "U8", apiVersion = {12, 0, 6}, simResponse = {2}},
    {field = "configuration_state", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}},
    {field = "current_pid_profile_index", type = "U8", apiVersion = {12, 0, 6}, simResponse = {5}, table = {"1", "2", "3", "4", "5", "6"}, tableIdxInc = -1},
    {field = "pid_profile_count", type = "U8", apiVersion = {12, 0, 6}, simResponse = {6}},
    {field = "current_control_rate_profile_index", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1}, table = {"1", "2", "3", "4", "5", "6"}, tableIdxInc = -1},
    {field = "control_rate_profile_count", type = "U8", apiVersion = {12, 0, 6}, simResponse = {4}},
    {field = "motor_count", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1}},
    {field = "servo_count", type = "U8", apiVersion = {12, 0, 6}, simResponse = {4}},
    {field = "gyro_detection_flags", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1}}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

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
    local writeStructure = MSP_API_STRUCTURE_READ
    if writeStructure == nil then return {} end
    return core.buildWritePayload(API_NAME, payloadData, writeStructure, state.rebuildOnWrite == true)
end

return factory.create({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = nil,
    minBytes = MSP_MIN_BYTES or 0,
    readStructure = MSP_API_STRUCTURE_READ,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE or {},
    parseRead = parseRead,
    buildWritePayload = buildWritePayload,
    initialRebuildOnWrite = (MSP_REBUILD_ON_WRITE == true),
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
