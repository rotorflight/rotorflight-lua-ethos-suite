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

local API_NAME = "RC_TUNING"
local MSP_API_CMD_READ = 111
local MSP_API_CMD_WRITE = 204
local MSP_REBUILD_ON_WRITE = true

local rateTable
local rateSimResponse
if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    rateTable = {"NONE", "BETAFLIGHT", "RACEFLIGHT", "KISS", "ACTUAL", "QUICK", "ROTORFLIGHT"}
    rateSimResponse = {6}
else
    rateTable = {"NONE", "BETAFLIGHT", "RACEFLIGHT", "KISS", "ACTUAL", "QUICK"}   
    rateSimResponse = {6} 
end

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rates_type", type = "U8", apiVersion = {12, 0, 6}, simResponse = rateSimResponse, min = 0, max = 6, default = 4, tableIdxInc = -1, table = rateTable, help = "@i18n(api.RC_TUNING.rates_type)@"},
    {field = "rcRates_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {18}, help = "@i18n(api.RC_TUNING.rcRates_1)@"},
    {field = "rcExpo_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {25}, help = "@i18n(api.RC_TUNING.rcExpo_1)@"},
    {field = "rates_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {32}, help = "@i18n(api.RC_TUNING.rates_1)@"},
    {field = "response_time_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_1)@"},
    {field = "accel_limit_1", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_1)@"},
    {field = "rcRates_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {18}, help = "@i18n(api.RC_TUNING.rcRates_2)@"},
    {field = "rcExpo_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {25}, help = "@i18n(api.RC_TUNING.rcExpo_2)@"},
    {field = "rates_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {32}, help = "@i18n(api.RC_TUNING.rates_2)@"},
    {field = "response_time_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_2)@"},
    {field = "accel_limit_2", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_2)@"},
    {field = "rcRates_3", type = "U8", apiVersion = {12, 0, 6}, simResponse = {32}, help = "@i18n(api.RC_TUNING.rcRates_3)@"},
    {field = "rcExpo_3", type = "U8", apiVersion = {12, 0, 6}, simResponse = {50}, help = "@i18n(api.RC_TUNING.rcExpo_3)@"},
    {field = "rates_3", type = "U8", apiVersion = {12, 0, 6}, simResponse = {45}, help = "@i18n(api.RC_TUNING.rates_3)@"},
    {field = "response_time_3", type = "U8", apiVersion = {12, 0, 6}, simResponse = {10}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_3)@"},
    {field = "accel_limit_3", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_3)@"},
    {field = "rcRates_4", type = "U8", apiVersion = {12, 0, 6}, simResponse = {56}, help = "@i18n(api.RC_TUNING.rcRates_4)@"},
    {field = "rcExpo_4", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, help = "@i18n(api.RC_TUNING.rcExpo_4)@"},
    {field = "rates_4", type = "U8", apiVersion = {12, 0, 6}, simResponse = {56}, help = "@i18n(api.RC_TUNING.rates_4)@"},
    {field = "response_time_4", type = "U8", apiVersion = {12, 0, 6}, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_4)@"},
    {field = "accel_limit_4", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_4)@"},
    {field = "setpoint_boost_gain_1", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_1)@"},
    {field = "setpoint_boost_cutoff_1", type = "U8", apiVersion = {12, 0, 8}, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_1)@"},
    {field = "setpoint_boost_gain_2", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_2)@"},
    {field = "setpoint_boost_cutoff_2", type = "U8", apiVersion = {12, 0, 8}, simResponse = {90}, min = 0, max = 250, unit = "Hz", default = 90, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_2)@"},
    {field = "setpoint_boost_gain_3", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_3)@"},
    {field = "setpoint_boost_cutoff_3", type = "U8", apiVersion = {12, 0, 8}, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_3)@"},
    {field = "setpoint_boost_gain_4", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_4)@"},
    {field = "setpoint_boost_cutoff_4", type = "U8", apiVersion = {12, 0, 8}, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_4)@"},
    {field = "yaw_dynamic_ceiling_gain", type = "U8", apiVersion = {12, 0, 8}, simResponse = {30}, default = 30, min = 0, max = 250, help = "@i18n(api.RC_TUNING.yaw_dynamic_ceiling_gain)@"},
    {field = "yaw_dynamic_deadband_gain", type = "U8", apiVersion = {12, 0, 8}, simResponse = {30}, default = 30, min = 0, max = 250, help = "@i18n(api.RC_TUNING.yaw_dynamic_deadband_gain)@"},
    {field = "yaw_dynamic_deadband_filter", type = "U8", apiVersion = {12, 0, 8}, simResponse = {60}, scale = 10, decimals = 1, default = 60, min = 0, max = 250, unit = "Hz", help = "@i18n(api.RC_TUNING.yaw_dynamic_deadband_filter)@"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

MSP_API_SIMULATOR_RESPONSE = {6  , 49 , 2  , 24 , 0  , 0  , 0  , 49 , 0  , 24 , 0  , 0  , 0  , 100, 0  , 24 , 0  , 0  , 0  , 100, 0  , 0  , 0  , 0  , 0  , 0  , 15 , 0  , 15 , 0  , 90 , 0  , 15 , 30 , 30 , 60 }

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
