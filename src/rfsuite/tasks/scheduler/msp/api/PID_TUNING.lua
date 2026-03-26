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

local API_NAME = "PID_TUNING"
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "pid_0_P", type = "U16", apiVersion = {12, 0, 6}, simResponse = {50, 0}, min = 0, max = 1000, default = 50},
    {field = "pid_0_I", type = "U16", apiVersion = {12, 0, 6}, simResponse = {100, 0}, min = 0, max = 1000, default = 100},
    {field = "pid_0_D", type = "U16", apiVersion = {12, 0, 6}, simResponse = {20, 0}, min = 0, max = 1000, default = 0},
    {field = "pid_0_F", type = "U16", apiVersion = {12, 0, 6}, simResponse = {100, 0}, min = 0, max = 1000, default = 100},

    {field = "pid_1_P", type = "U16", apiVersion = {12, 0, 6}, simResponse = {50, 0}, min = 0, max = 1000, default = 50},
    {field = "pid_1_I", type = "U16", apiVersion = {12, 0, 6}, simResponse = {100, 0}, min = 0, max = 1000, default = 100},
    {field = "pid_1_D", type = "U16", apiVersion = {12, 0, 6}, simResponse = {50, 0}, min = 0, max = 1000, default = 40},
    {field = "pid_1_F", type = "U16", apiVersion = {12, 0, 6}, simResponse = {100, 0}, min = 0, max = 1000, default = 100},

    {field = "pid_2_P", type = "U16", apiVersion = {12, 0, 6}, simResponse = {80, 0}, min = 0, max = 1000, default = 80},
    {field = "pid_2_I", type = "U16", apiVersion = {12, 0, 6}, simResponse = {120, 0}, min = 0, max = 1000, default = 120},
    {field = "pid_2_D", type = "U16", apiVersion = {12, 0, 6}, simResponse = {40, 0}, min = 0, max = 1000, default = 10},
    {field = "pid_2_F", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 1000, default = 0},

    {field = "pid_0_B", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 1000, default = 0},
    {field = "pid_1_B", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 1000, default = 0},
    {field = "pid_2_B", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 1000, default = 0},

    {field = "pid_0_O", type = "U16", apiVersion = {12, 0, 6}, simResponse = {45, 0}, min = 0, max = 1000, default = 45},
    {field = "pid_1_O", type = "U16", apiVersion = {12, 0, 6}, simResponse = {45, 0}, min = 0, max = 1000, default = 45}
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
    readCmd = 112,
    writeCmd = 202,
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
