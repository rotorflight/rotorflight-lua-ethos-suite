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

local API_NAME = "FILTER_CONFIG"
local MSP_API_CMD_READ = 92
local MSP_API_CMD_WRITE = 93

local TBL_GYRO_FILTER_TYPE = {
    [0] = "@i18n(api.FILTER_CONFIG.tbl_none)@",
    [1] = "@i18n(api.FILTER_CONFIG.tbl_1st)@",
    [2] = "@i18n(api.FILTER_CONFIG.tbl_2nd)@"
}
local TBL_RPM_PRESET = {
    "@i18n(api.FILTER_CONFIG.tbl_custom)@",
    "@i18n(api.FILTER_CONFIG.tbl_low)@",
    "@i18n(api.FILTER_CONFIG.tbl_medium)@",
    "@i18n(api.FILTER_CONFIG.tbl_high)@"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"gyro_hardware_lpf", "U8"},
    {"gyro_lpf1_type", "U8", 0, #TBL_GYRO_FILTER_TYPE, nil, nil, nil, nil, nil, nil, TBL_GYRO_FILTER_TYPE},
    {"gyro_lpf1_static_hz", "U16", 0, 4000, 100, "Hz"},
    {"gyro_lpf2_type", "U8", 0, #TBL_GYRO_FILTER_TYPE, nil, nil, nil, nil, nil, nil, TBL_GYRO_FILTER_TYPE},
    {"gyro_lpf2_static_hz", "U16", 0, 4000, nil, "Hz"},
    {"gyro_soft_notch_hz_1", "U16", 0, 4000, nil, "Hz"},
    {"gyro_soft_notch_cutoff_1", "U16", 0, 4000, nil, "Hz"},
    {"gyro_soft_notch_hz_2", "U16", 0, 4000, nil, "Hz"},
    {"gyro_soft_notch_cutoff_2", "U16", 0, 4000, nil, "Hz"},
    {"gyro_lpf1_dyn_min_hz", "U16", 0, 1000, nil, "Hz"},
    {"gyro_lpf1_dyn_max_hz", "U16", 0, 1000, nil, "Hz"},
    {"dyn_notch_count", "U8", 0, 8},
    {"dyn_notch_q", "U8", 0, 100, nil, nil, 1, 10},
    {"dyn_notch_min_hz", "U16", 10, 200, nil, "Hz"},
    {"dyn_notch_max_hz", "U16", 100, 500, nil, "Hz"}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"rpm_preset", "U8", nil, nil, nil, nil, nil, nil, nil, nil, TBL_RPM_PRESET, -1}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"rpm_min_hz", "U8", 1, 100, nil, "Hz"}
end

local SIM_RESPONSE = core.simResponse({
    0,       -- gyro_hardware_lpf
    1,       -- gyro_lpf1_type
    100, 0,  -- gyro_lpf1_static_hz
    0,       -- gyro_lpf2_type
    0, 0,    -- gyro_lpf2_static_hz
    0, 0,    -- gyro_soft_notch_hz_1
    0, 0,    -- gyro_soft_notch_cutoff_1
    0, 0,    -- gyro_soft_notch_hz_2
    0, 0,    -- gyro_soft_notch_cutoff_2
    0, 0,    -- gyro_lpf1_dyn_min_hz
    25, 0,   -- gyro_lpf1_dyn_max_hz
    0,       -- dyn_notch_count
    100,     -- dyn_notch_q
    0, 0,    -- dyn_notch_min_hz
    0, 0,    -- dyn_notch_max_hz
    1,       -- rpm_preset
    20       -- rpm_min_hz
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minApiVersion = {12, 0, 7},
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
