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

local API_NAME = "ESC_PARAMETERS_ZTW"
local MSP_SIGNATURE = 0xDD
local MSP_HEADER_BYTES = 2

local govMode = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_escgov)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_extgov)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_fwgov)@"}
local lowVoltage = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_off)@", "2.7V", "3.0V", "3.2V", "3.4V", "3.6V", "3.8V"}
local timing = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_auto)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_low)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_medium)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_high)@"}
local becLvVoltage = {"6.0V", "7.4V", "8.4V"}
local motorDirection = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_ccw)@"}
local accel = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_fast)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_slow)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_vslow)@"}
local autoRestart = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_off)@", "90s"}
local becHvVoltage = {"6.0V", "6.2V", "6.4V", "6.6V", "6.8V", "7.0V", "7.2V", "7.4V", "7.6V", "7.8V", "8.0V", "8.2V", "8.4V", "8.6V", "8.8V", "9.0V", "9.2V", "9.4V", "9.6V", "9.8V", "10.0V", "10.2V", "10.4V", "10.6V", "10.8V", "11.0V", "11.2V", "11.4V", "11.6V", "11.8V", "12.0V"}
local startupPower = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_low)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_medium)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_high)@"}
local brakeType = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_reverse)@"}
local srFunc = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_on)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_off)@"}
local ledColor = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_red)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_yellow)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_orange)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_green)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_jadegreen)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_blue)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_cyan)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_purple)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_pink)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_white)@"}
local fanControl = {"@i18n(api.ESC_PARAMETERS_ZTW.tbl_on)@", "@i18n(api.ESC_PARAMETERS_ZTW.tbl_off)@"}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"esc_model", "U8"},
    {"esc_version", "U8"},
    {"governor", "U16", nil, nil, nil, nil, nil, nil, nil, nil, govMode, -1},
    {"cell_cutoff", "U16", nil, nil, nil, nil, nil, nil, nil, nil, lowVoltage, -1},
    {"timing", "U16", nil, nil, nil, nil, nil, nil, nil, nil, timing, -1},
    {"lv_bec_voltage", "U16", nil, nil, nil, nil, nil, nil, nil, nil, becLvVoltage, -1},
    {"motor_direction", "U16", nil, nil, nil, nil, nil, nil, nil, nil, motorDirection, -1},
    {"gov_p", "U16", 1, 10, 5, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1},
    {"gov_i", "U16", 1, 10, 5, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1},
    {"acceleration", "U16", nil, nil, nil, nil, nil, nil, nil, nil, accel, -1},
    {"auto_restart_time", "U16", nil, nil, nil, nil, nil, nil, nil, nil, autoRestart, -1},
    {"hv_bec_voltage", "U16", nil, nil, nil, nil, nil, nil, nil, nil, becHvVoltage, -1},
    {"startup_power", "U16", nil, nil, nil, nil, nil, nil, nil, nil, startupPower, -1},
    {"brake_type", "U16", nil, nil, nil, nil, nil, nil, nil, nil, brakeType, -1},
    {"brake_force", "U16", 0, 100, 0, "%"},
    {"sr_function", "U16", nil, nil, nil, nil, nil, nil, nil, nil, srFunc, -1},
    {"capacity_correction", "U16", 0, 20, 10, "%", nil, nil, nil, nil, nil, nil, nil, nil, nil, -10},
    {"motor_poles", "U16", 1, 55, 10, nil, nil, nil, 1, nil, nil, nil, nil, nil, nil, 1},
    {"led_color", "U16", nil, nil, nil, nil, nil, nil, nil, nil, ledColor, -1},
    {"smart_fan", "U16", nil, nil, nil, nil, nil, nil, nil, nil, fanControl, -1},
    {"activefields", "U32"}
}

local SIM_RESPONSE = core.simResponse({
    221, -- esc_signature
    0, -- esc_command
    23, -- esc_model
    3, -- esc_version
    0, 0, -- governor
    0, 0, -- cell_cutoff
    0, 0, -- timing
    0, 0, -- lv_bec_voltage
    0, 0, -- motor_direction
    4, 0, -- gov_p
    3, 0, -- gov_i
    0, 0, -- acceleration
    0, 0, -- auto_restart_time
    0, 0, -- hv_bec_voltage
    0, 0, -- startup_power
    0, 0, -- brake_type
    0, 0, -- brake_force
    0, 0, -- sr_function
    0, 0, -- capacity_correction
    9, 0, -- motor_poles
    0, 0, -- led_color
    0, 0, -- smart_fan
    238, 255, 1, 0 -- activefields
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
