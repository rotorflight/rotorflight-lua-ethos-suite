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

local API_NAME = "ESC_PARAMETERS_SCORPION"
local MSP_SIGNATURE = 0x53
local MSP_HEADER_BYTES = 2

local escMode = {"@i18n(api.ESC_PARAMETERS_SCORPION.tbl_heligov)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_helistore)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_vbargov)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_extgov)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_airplane)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_boat)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_quad)@"}
local rotation = {"@i18n(api.ESC_PARAMETERS_SCORPION.tbl_ccw)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_cw)@"}
local becVoltage = {"5.1 V", "6.1 V", "7.3 V", "8.3 V", "Disabled"}
local teleProtocol = {"@i18n(api.ESC_PARAMETERS_SCORPION.tbl_standard)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_vbar)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_exbus)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_unsolicited)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_futsbus)@"}
local onOff = {"@i18n(api.ESC_PARAMETERS_SCORPION.tbl_on)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_off)@"}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"escinfo_1", "U8"},
    {"escinfo_2", "U8"},
    {"escinfo_3", "U8"},
    {"escinfo_4", "U8"},
    {"escinfo_5", "U8"},
    {"escinfo_6", "U8"},
    {"escinfo_7", "U8"},
    {"escinfo_8", "U8"},
    {"escinfo_9", "U8"},
    {"escinfo_10", "U8"},
    {"escinfo_11", "U8"},
    {"escinfo_12", "U8"},
    {"escinfo_13", "U8"},
    {"escinfo_14", "U8"},
    {"escinfo_15", "U8"},
    {"escinfo_16", "U8"},
    {"escinfo_17", "U8"},
    {"escinfo_18", "U8"},
    {"escinfo_19", "U8"},
    {"escinfo_20", "U8"},
    {"escinfo_21", "U8"},
    {"escinfo_22", "U8"},
    {"escinfo_23", "U8"},
    {"escinfo_24", "U8"},
    {"escinfo_25", "U8"},
    {"escinfo_26", "U8"},
    {"escinfo_27", "U8"},
    {"escinfo_28", "U8"},
    {"escinfo_29", "U8"},
    {"escinfo_30", "U8"},
    {"escinfo_31", "U8"},
    {"escinfo_32", "U8"},
    {"esc_mode", "U16", 0, #escMode, nil, nil, nil, nil, nil, nil, escMode, -1},
    {"bec_voltage", "U16", 0, #becVoltage, nil, nil, nil, nil, nil, nil, becVoltage, -1},
    {"rotation", "U16", 0, #rotation, nil, nil, nil, nil, nil, nil, rotation, -1},
    {"telemetry_protocol", "U16", 0, #teleProtocol, nil, nil, nil, nil, nil, nil, teleProtocol, -1},
    {"protection_delay", "U16", 0, 5000, nil, "s", nil, 1000},
    {"min_voltage", "U16", 0, 7000, nil, "v", 1, 100},
    {"max_temperature", "U16", 0, 40000, nil, "°", nil, 100},
    {"max_current", "U16", 0, 30000, nil, "A", nil, 100},
    {"cutoff_handling", "U16", 0, 10000, nil, "%", nil, 100},
    {"max_used", "U16", 0, 6000, nil, "Ah", nil, 100},
    {"motor_startup_sound", "U16", 0, #onOff, nil, nil, nil, nil, nil, nil, onOff, -1},
    {"padding_1", "U16"},
    {"padding_2", "U16"},
    {"padding_3", "U16"},
    {"soft_start_time", "U16", 0, 60000, nil, "s", nil, 1000},
    {"runup_time", "U16", 0, 60000, nil, "s", nil, 1000},
    {"bailout", "U16", 0, 100000, nil, "s", nil, 1000},
    {"gov_proportional", "U32", 30, 180, nil, nil, nil, 100},
    {"gov_integral", "U32", 150, 250, nil, nil, nil, 100}
}

local SIM_RESPONSE = core.simResponse({
    83, -- esc_signature
    128, -- esc_command
    84, -- escinfo_1
    114, -- escinfo_2
    105, -- escinfo_3
    98, -- escinfo_4
    117, -- escinfo_5
    110, -- escinfo_6
    117, -- escinfo_7
    115, -- escinfo_8
    32, -- escinfo_9
    69, -- escinfo_10
    83, -- escinfo_11
    67, -- escinfo_12
    45, -- escinfo_13
    54, -- escinfo_14
    83, -- escinfo_15
    45, -- escinfo_16
    56, -- escinfo_17
    48, -- escinfo_18
    65, -- escinfo_19
    0, -- escinfo_20
    0, -- escinfo_21
    0, -- escinfo_22
    0, -- escinfo_23
    0, -- escinfo_24
    0, -- escinfo_25
    0, -- escinfo_26
    0, -- escinfo_27
    0, -- escinfo_28
    0, -- escinfo_29
    0, -- escinfo_30
    4, -- escinfo_31
    0, -- escinfo_32
    3, 0, -- esc_mode
    3, 0, -- bec_voltage
    1, 0, -- rotation
    3, 0, -- telemetry_protocol
    136, 19, -- protection_delay
    22, 3, -- min_voltage
    16, 39, -- max_temperature
    64, 31, -- max_current
    136, 19, -- cutoff_handling
    0, 0, -- max_used
    1, 0, -- motor_startup_sound
    7, 2, -- padding_1
    0, 6, -- padding_2
    63, 0, -- padding_3
    160, 15, -- soft_start_time
    64, 31, -- runup_time
    208, 7, -- bailout
    100, 0, 0, 0, -- gov_proportional
    200, 0, 0, 0 -- gov_integral
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
