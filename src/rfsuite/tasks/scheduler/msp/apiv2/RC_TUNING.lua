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

local API_NAME = "RC_TUNING"
local MSP_API_CMD_READ = 111
local MSP_API_CMD_WRITE = 204

local TBL_RATE_TABLE
if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    TBL_RATE_TABLE = {"NONE", "BETAFLIGHT", "RACEFLIGHT", "KISS", "ACTUAL", "QUICK", "ROTORFLIGHT"}
else
    TBL_RATE_TABLE = {"NONE", "BETAFLIGHT", "RACEFLIGHT", "KISS", "ACTUAL", "QUICK"}
end

local TBL_OFF_ON = {
    "@i18n(api.RC_TUNING.tbl_off)@",
    "@i18n(api.RC_TUNING.tbl_on)@"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"rates_type", "U8", 0, 6, 4, nil, nil, nil, nil, nil, TBL_RATE_TABLE, -1},
    {"rcRates_1", "U8"},
    {"rcExpo_1", "U8"},
    {"rates_1", "U8"},
    {"response_time_1", "U8", 0, 250, nil, "ms"},
    {"accel_limit_1", "U16", 0, 50000, nil, "°/s", nil, nil, 10, 10},
    {"rcRates_2", "U8"},
    {"rcExpo_2", "U8"},
    {"rates_2", "U8"},
    {"response_time_2", "U8", 0, 250, nil, "ms"},
    {"accel_limit_2", "U16", 0, 50000, nil, "°/s", nil, nil, 10, 10},
    {"rcRates_3", "U8"},
    {"rcExpo_3", "U8"},
    {"rates_3", "U8"},
    {"response_time_3", "U8", 0, 250, nil, "ms"},
    {"accel_limit_3", "U16", 0, 50000, nil, "°/s", nil, nil, 10, 10},
    {"rcRates_4", "U8"},
    {"rcExpo_4", "U8"},
    {"rates_4", "U8"},
    {"response_time_4", "U8", 0, 250, nil, "ms"},
    {"accel_limit_4", "U16", 0, 50000, nil, "°/s", nil, nil, 10, 10}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"setpoint_boost_gain_1", "U8", 0, 250, 0}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"setpoint_boost_cutoff_1", "U8", 0, 250, 15, "Hz"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"setpoint_boost_gain_2", "U8", 0, 250, 0}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"setpoint_boost_cutoff_2", "U8", 0, 250, 90, "Hz"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"setpoint_boost_gain_3", "U8", 0, 250, 0}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"setpoint_boost_cutoff_3", "U8", 0, 250, 15, "Hz"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"setpoint_boost_gain_4", "U8", 0, 250, 0}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"setpoint_boost_cutoff_4", "U8", 0, 250, 15, "Hz"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"yaw_dynamic_ceiling_gain", "U8", 0, 250, 30}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"yaw_dynamic_deadband_gain", "U8", 0, 250, 30}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"yaw_dynamic_deadband_filter", "U8", 0, 250, 60, "Hz", 1, 10}
end

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"cyclic_ring", "U8", 0, 250, 150, "%"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"cyclic_polarity", "U8", 0, 1, 0, nil, nil, nil, nil, nil, TBL_OFF_ON, -1}
end

local SIM_RESPONSE = core.simResponse({
    6,       -- rates_type
    18,      -- rcRates_1
    25,      -- rcExpo_1
    32,      -- rates_1
    20,      -- response_time_1
    0, 0,    -- accel_limit_1
    18,      -- rcRates_2
    25,      -- rcExpo_2
    32,      -- rates_2
    20,      -- response_time_2
    0, 0,    -- accel_limit_2
    32,      -- rcRates_3
    50,      -- rcExpo_3
    45,      -- rates_3
    10,      -- response_time_3
    0, 0,    -- accel_limit_3
    56,      -- rcRates_4
    0,       -- rcExpo_4
    56,      -- rates_4
    20,      -- response_time_4
    0, 0,    -- accel_limit_4
    0,       -- setpoint_boost_gain_1
    15,      -- setpoint_boost_cutoff_1
    0,       -- setpoint_boost_gain_2
    90,      -- setpoint_boost_cutoff_2
    0,       -- setpoint_boost_gain_3
    15,      -- setpoint_boost_cutoff_3
    0,       -- setpoint_boost_gain_4
    15,      -- setpoint_boost_cutoff_4
    30,      -- yaw_dynamic_ceiling_gain
    30,      -- yaw_dynamic_deadband_gain
    60,      -- yaw_dynamic_deadband_filter
    150,     -- cyclic_ring
    1        -- cyclic_polarity
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    initialRebuildOnWrite = true,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
