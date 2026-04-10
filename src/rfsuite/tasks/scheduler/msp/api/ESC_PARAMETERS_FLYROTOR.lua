--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local API_NAME = "ESC_PARAMETERS_FLYROTOR"
local MSP_SIGNATURE = 0x73
local MSP_HEADER_BYTES = 2

local tblLed = {"CUSTOM", "OFF", "RED", "GREEN", "BLUE", "YELLOW", "MAGENTA", "CYAN", "WHITE", "ORANGE", "GRAY", "MAROON", "DARK_GREEN", "NAVY", "PURPLE", "TEAL", "SILVER", "PINK", "GOLD", "BROWN", "LIGHT_BLUE", "FL_PINK", "FL_ORANGE", "FL_LIME", "FL_MINT", "FL_CYAN", "FL_PURPLE", "FL_HOT_PINK", "FL_LIGHT_YELLOW", "FL_AQUAMARINE", "FL_GOLD", "FL_DEEP_PINK", "FL_NEON_GREEN", "FL_ORANGE_RED"}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"esc_type", "U8"},
    {"esc_model", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "big"},
    {"esc_sn", "U64"},
    {"esc_iap", "U24"},
    {"esc_fw", "U24"},
    {"esc_hardware", "U8"},
    {"throttle_min", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "big"},
    {"throttle_max", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "big"},
    {"esc_mode", "U8", nil, nil, nil, nil, nil, nil, nil, nil, {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_escgov)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_linear_thr)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_rf_gov)@"}, -1},
    {"cell_count", "U8", 4, 14, 6},
    {"low_voltage_protection", "U8", 28, 38, 30, "V", 1, 10},
    {"temperature_protection", "U8", 50, 135, 125, "°"},
    {"bec_voltage", "U8", nil, nil, nil, nil, nil, nil, nil, nil, {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "7.5V", "8.0V", "8.5V", "12.0V"}, -1},
    {"electrical_angle", "U8", nil, nil, nil, nil, nil, nil, nil, nil, {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_auto)@", "1°", "2°", "3°", "4°", "5°", "6°", "7°", "8°", "9°", "10°"}, -1},
    {"motor_direction", "U8", nil, nil, nil, nil, nil, nil, nil, nil, {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_ccw)@"}, -1},
    {"starting_torque", "U8", 1, 15, 3},
    {"response_speed", "U8", 1, 15, 5},
    {"buzzer_volume", "U8", 1, 5, 2},
    {"current_gain", "S8", 0, 40, 20, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, -20},
    {"fan_control", "U8", nil, nil, nil, nil, nil, nil, nil, nil, {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_automatic)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_alwayson)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_alwaysoff)@"}, -1},
    {"soft_start", "U8", 5, 55, 15, "s"},
    {"auto_restart_time", "U8", 0, 100, 30, "s"},
    {"restart_acc", "U8", 1, 10, 5},
    {"gov_p", "U8", 0, 100, 45},
    {"gov_i", "U8", 0, 100, 35}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"active_freewheel", "U8", 0, 1, nil, nil, nil, nil, nil, nil, {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_enabled)@"}, -1}
end

FIELD_SPEC[#FIELD_SPEC + 1] = {"drive_freq", "U8", 10, 24, 16, "KHz"}
FIELD_SPEC[#FIELD_SPEC + 1] = {"motor_erpm_max", "U24", 0, 1000000, nil, nil, nil, nil, 100, nil, nil, nil, nil, "big"}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"throttle_protocol", "U8", 0, 0, nil, nil, nil, nil, nil, nil, {"PWM"}, -1}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"telemetry_protocol", "U8", 0, 0, nil, nil, nil, nil, nil, nil, {"FLYROTOR"}, -1}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"led_color_index", "U8", 0, #tblLed - 1, nil, nil, nil, nil, nil, nil, tblLed, -1}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"led_color_rgb", "U24"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"motor_temp_sensor", "U8", 0, 1, nil, nil, nil, nil, nil, nil, {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_enabled)@"}, -1}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"motor_temp", "U8", 50, 150, nil, "°"}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"battery_capacity", "U16", 0, 50000, nil, "mAh", nil, nil, 100, nil, nil, nil, nil, "big"}
end

local SIM_RESPONSE = core.simResponse({
    115, -- esc_signature
    0, -- esc_command
    0, -- esc_type
    1, 24, -- esc_model
    231, 79, 190, 216, 78, 29, 169, 244, -- esc_sn
    1, 0, 0, -- esc_iap
    1, 0, 1, -- esc_fw
    0, -- esc_hardware
    4, 76, -- throttle_min
    7, 148, -- throttle_max
    0, -- esc_mode
    6, -- cell_count
    30, -- low_voltage_protection
    125, -- temperature_protection
    1, -- bec_voltage
    0, -- electrical_angle
    0, -- motor_direction
    3, -- starting_torque
    5, -- response_speed
    1, -- buzzer_volume
    20, -- current_gain
    0, -- fan_control
    15, -- soft_start
    15, -- auto_restart_time
    15, -- restart_acc
    45, -- gov_p
    35, -- gov_i
    0, -- active_freewheel
    16, -- drive_freq
    2, 23, 40, -- motor_erpm_max
    0, -- throttle_protocol
    0, -- telemetry_protocol
    3, -- led_color_index
    0, 0, 0, -- led_color_rgb
    0, -- motor_temp_sensor
    100, -- motor_temp
    0, 0 -- battery_capacity
})

return core.createConfigAPI({
    name = API_NAME,
    minApiVersion = {12, 0, 7},
    readCmd = 217,
    writeCmd = 218,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = false,
    readCompleteOnErrorReplyAttempt = 2,
    exports = {
        mspSignature = MSP_SIGNATURE,
        mspHeaderBytes = MSP_HEADER_BYTES,
        simulatorResponse = SIM_RESPONSE
    }
})
