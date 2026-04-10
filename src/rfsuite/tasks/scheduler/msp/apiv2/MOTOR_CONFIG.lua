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

local API_NAME = "MOTOR_CONFIG"
local MSP_API_CMD_READ = 131
local MSP_API_CMD_WRITE = 222

local pwmProtocol
if rfsuite.utils.apiVersionCompare(">=", {12, 0, 7}) then
    pwmProtocol = {"PWM", "ONESHOT125", "ONESHOT42", "MULTISHOT", "BRUSHED", "DSHOT150", "DSHOT300", "DSHOT600", "PROSHOT", "CASTLE", "DISABLED"}
else
    pwmProtocol = {"PWM", "ONESHOT125", "ONESHOT42", "MULTISHOT", "BRUSHED", "DSHOT150", "DSHOT300", "DSHOT600", "PROSHOT", "DISABLED"}
end

local onoff = {
    "@i18n(api.MOTOR_CONFIG.tbl_off)@",
    "@i18n(api.MOTOR_CONFIG.tbl_on)@"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"minthrottle", "U16", 50, 2250, 1070, "us"},
    {"maxthrottle", "U16", 50, 2250, 2000, "us"},
    {"mincommand", "U16", 50, 2250, 1000, "us"},
    {"motor_count_blheli", "U8"},
    {"motor_pole_count_blheli", "U8"},

    {"use_dshot_telemetry", "U8", nil, nil, nil, nil, nil, nil, nil, onoff, -1},
    {"motor_pwm_protocol", "U8", nil, nil, nil, nil, nil, nil, nil, pwmProtocol, -1},
    {"motor_pwm_rate", "U16", 50, 8000, 250, "Hz"},
    {"use_unsynced_pwm", "U8", nil, nil, nil, nil, nil, nil, nil, onoff, -1},

    {"motor_pole_count_0", "U8", 2, 256, 10, nil, nil, nil, 2},
    {"motor_pole_count_1", "U8"},
    {"motor_pole_count_2", "U8"},
    {"motor_pole_count_3", "U8"},

    {"motor_rpm_lpf_0", "U8"},
    {"motor_rpm_lpf_1", "U8"},
    {"motor_rpm_lpf_2", "U8"},
    {"motor_rpm_lpf_3", "U8"},

    {"main_rotor_gear_ratio_0", "U16", 1, 50000, 1},
    {"main_rotor_gear_ratio_1", "U16", 1, 50000, 1},
    {"tail_rotor_gear_ratio_0", "U16", 1, 50000, 1},
    {"tail_rotor_gear_ratio_1", "U16", 1, 50000, 1}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"minthrottle", "U16"},
    {"maxthrottle", "U16"},
    {"mincommand", "U16"},
    {"motor_pole_count_blheli", "U8"},

    {"use_dshot_telemetry", "U8", nil, nil, nil, nil, nil, nil, nil, onoff, -1},
    {"motor_pwm_protocol", "U8", nil, nil, nil, nil, nil, nil, nil, pwmProtocol, -1},
    {"motor_pwm_rate", "U16"},
    {"use_unsynced_pwm", "U8", nil, nil, nil, nil, nil, nil, nil, onoff, -1},

    {"motor_pole_count_0", "U8"},
    {"motor_pole_count_1", "U8"},
    {"motor_pole_count_2", "U8"},
    {"motor_pole_count_3", "U8"},

    {"motor_rpm_lpf_0", "U8"},
    {"motor_rpm_lpf_1", "U8"},
    {"motor_rpm_lpf_2", "U8"},
    {"motor_rpm_lpf_3", "U8"},

    {"main_rotor_gear_ratio_0", "U16"},
    {"main_rotor_gear_ratio_1", "U16"},
    {"tail_rotor_gear_ratio_0", "U16"},
    {"tail_rotor_gear_ratio_1", "U16"}
}

local SIM_RESPONSE = core.simResponse({
    45, 4,   -- minthrottle
    208, 7,  -- maxthrottle
    232, 3,  -- mincommand
    1,       -- motor_count_blheli
    6,       -- motor_pole_count_blheli

    0,       -- use_dshot_telemetry
    0,       -- motor_pwm_protocol
    250, 0,  -- motor_pwm_rate
    1,       -- use_unsynced_pwm

    6,       -- motor_pole_count_0
    4,       -- motor_pole_count_1
    2,       -- motor_pole_count_2
    1,       -- motor_pole_count_3

    8,       -- motor_rpm_lpf_0
    7,       -- motor_rpm_lpf_1
    7,       -- motor_rpm_lpf_2
    8,       -- motor_rpm_lpf_3

    20, 0,   -- main_rotor_gear_ratio_0
    50, 0,   -- main_rotor_gear_ratio_1
    9, 0,    -- tail_rotor_gear_ratio_0
    30, 0    -- tail_rotor_gear_ratio_1
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    initialRebuildOnWrite = true,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
