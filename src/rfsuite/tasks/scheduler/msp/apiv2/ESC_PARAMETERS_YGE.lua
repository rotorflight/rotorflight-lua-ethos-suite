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

local API_NAME = "ESC_PARAMETERS_YGE"
local MSP_SIGNATURE = 0xA5
local MSP_HEADER_BYTES = 2

local escMode = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_modefree)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeext)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeheli)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modestore)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeglider)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeair)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modef3a)@"}
local rotation = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_reverse)@"}
local cutoff = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_slowdown)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_cutoff)@"}
local cutoffVoltage = {"2.9 V", "3.0 V", "3.1 V", "3.2 V", "3.3 V", "3.4 V"}
local offOn = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_on)@"}
local throttleResponse = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_slow)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_medium)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_fast)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_custom)@"}
local motorTiming = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_autonorm)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autoefficient)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autopower)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autoextreme)@", "0°", "6°", "12°", "18°", "24°", "30°"}
local freewheel = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_auto)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_unused)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_alwayson)@"}
local flagsBitmap = {
    {field = "direction", table = rotation, tableIdxInc = -1},
    {field = "f3cauto", table = offOn, tableIdxInc = -1},
    {field = "keepmah", table = offOn, tableIdxInc = -1},
    {field = "bec12v", table = offOn, tableIdxInc = -1}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"esc_model", "U8"},
    {"esc_version", "U8"},
    {"governor", "U16", 1, #escMode, nil, nil, nil, nil, nil, nil, escMode, -1},
    {"lv_bec_voltage", "U16", 55, 84, nil, "v", 1, 10},
    {"timing", "U16", 0, #motorTiming, nil, nil, nil, nil, nil, nil, motorTiming, -1},
    {"acceleration", "U16"},
    {"gov_p", "U16", 1, 10},
    {"gov_i", "U16", 1, 10},
    {"throttle_response", "U16", 0, #throttleResponse, nil, nil, nil, nil, nil, nil, throttleResponse, -1},
    {"auto_restart_time", "U16", 0, #cutoff, nil, nil, nil, nil, nil, nil, cutoff, -1},
    {"cell_cutoff", "U16", 0, #cutoffVoltage, nil, nil, nil, nil, nil, nil, cutoffVoltage, -1},
    {"active_freewheel", "U16", 0, #freewheel, nil, nil, nil, nil, nil, nil, freewheel, -1},
    {"esc_type", "U16"},
    {"firmware_version", "U32"},
    {"serial_number", "U32"},
    {"unknown_1", "U16"},
    {"stick_zero_us", "U16", 900, 1900, nil, "us"},
    {"stick_range_us", "U16", 600, 1500, nil, "us"},
    {"unknown_2", "U16"},
    {"motor_poll_pairs", "U16", 1, 100},
    {"pinion_teeth", "U16", 1, 255},
    {"main_teeth", "U16", 1, 1800},
    {"min_start_power", "U16", 0, 26, nil, "%"},
    {"max_start_power", "U16", 0, 31, nil, "%"},
    {"unknown_3", "U16"},
    {"flags", "U8"},
    {"unknown_4", "U8", 0, 1, nil, nil, nil, nil, nil, nil, offOn, -1},
    {"current_limit", "U16", 1, 65500, nil, "A", 2, 100}
}

local SIM_RESPONSE = core.simResponse({
    165, -- esc_signature
    0, -- esc_command
    32, -- esc_model
    0, -- esc_version
    3, 0, -- governor
    55, 0, -- lv_bec_voltage
    0, 0, -- timing
    0, 0, -- acceleration
    4, 0, -- gov_p
    3, 0, -- gov_i
    1, 0, -- throttle_response
    1, 0, -- auto_restart_time
    2, 0, -- cell_cutoff
    3, 0, -- active_freewheel
    80, 3, -- esc_type
    131, 148, 1, 0, -- firmware_version
    30, 170, 0, 0, -- serial_number
    3, 0, -- unknown_1
    86, 4, -- stick_zero_us
    22, 3, -- stick_range_us
    163, 15, -- unknown_2
    1, 0, -- motor_poll_pairs
    2, 0, -- pinion_teeth
    2, 0, -- main_teeth
    20, 0, -- min_start_power
    20, 0, -- max_start_power
    0, 0, -- unknown_3
    0, -- flags
    0, -- unknown_4
    2, 19 -- current_limit
})

local api = core.createConfigAPI({
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

for _, entry in ipairs(api.__rfReadStructure) do
    if entry.field == "flags" then
        entry.bitmap = flagsBitmap
        break
    end
end

for _, entry in ipairs(api.__rfWriteStructure) do
    if entry.field == "flags" then
        entry.bitmap = flagsBitmap
        break
    end
end

return api
