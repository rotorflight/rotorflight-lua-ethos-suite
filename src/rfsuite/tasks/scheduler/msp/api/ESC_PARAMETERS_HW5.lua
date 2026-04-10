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

local API_NAME = "ESC_PARAMETERS_HW5"
local MSP_SIGNATURE = 0xFD
local MSP_HEADER_BYTES = 2

local flightMode = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_fixedwing)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_heliext)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_heligov)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_helistore)@"}
local rotation = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_ccw)@"}
local lipoCellCount = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_autocalculate)@", "3S", "4S", "5S", "6S", "7S", "8S", "9S", "10S", "11S", "12S", "13S", "14S"}
local cutoffType = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_softcutoff)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_hardcutoff)@"}
local cutoffVoltage = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "2.8", "2.9", "3.0", "3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8"}
local restartTime = {"1s", "1.5s", "2s", "2.5s", "3s"}
local startupPower = {"1", "2", "3", "4", "5", "6", "7"}
local enabledDisabled = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_enabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@"}
local brakeType = {"@i18n(api.ESC_PARAMETERS_HW5.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_proportional)@", "@i18n(api.ESC_PARAMETERS_HW5.tbl_reverse)@"}

--[[
    Maintenance note:
    Keep this API module focused on the raw HW5 MSP payload and generic field bounds.

    Model-specific option lists and field availability are owned by the client/page layer
    in app/modules/esc_tools/tools/escmfg/hw5/profile.lua.
]] --

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos, offset, xvals
local FIELD_SPEC = {
    {"esc_signature", "U8"},
    {"esc_command", "U8"},
    {"firmware_version", "U128"},
    {"hardware_version", "U128"},
    {"esc_type", "U128"},
    {"com_version", "U120"},
    {"flight_mode", "U8", 0, #flightMode, 0, nil, nil, nil, nil, nil, flightMode, -1},
    {"lipo_cell_count", "U8", 0, #lipoCellCount, 0, nil, nil, nil, nil, nil, lipoCellCount, -1},
    {"volt_cutoff_type", "U8", 0, #cutoffType, 0, nil, nil, nil, nil, nil, cutoffType, -1},
    {"cutoff_voltage", "U8", 0, #cutoffVoltage, 3, nil, nil, nil, nil, nil, cutoffVoltage, -1},
    {"bec_voltage", "U8", 0, 70, 0},
    {"startup_time", "U8", 4, 25, 0, "s"},
    {"gov_p_gain", "U8", 0, 9, 0},
    {"gov_i_gain", "U8", 0, 9, 0},
    {"auto_restart", "U8", 0, 90, 25},
    {"restart_time", "U8", 0, #restartTime, 1, nil, nil, nil, nil, nil, restartTime, -1},
    {"brake_type", "U8", 0, #brakeType, 0, nil, nil, nil, nil, nil, brakeType, -1, nil, nil, nil, nil, {76}},
    {"brake_force", "U8", 0, 100, 0},
    {"timing", "U8", 0, 30, 0},
    {"rotation", "U8", 0, #rotation, 0, nil, nil, nil, nil, nil, rotation, -1},
    {"active_freewheel", "U8", 0, #enabledDisabled, 0, nil, nil, nil, nil, nil, enabledDisabled, -1},
    {"startup_power", "U8", 0, #startupPower, 2, nil, nil, nil, nil, nil, startupPower, -1}
}

local SIM_RESPONSE = core.simResponse({
    253, -- esc_signature
    0, -- esc_command
    32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32, -- firmware_version
    72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66, -- hardware_version
    80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32, 32, 32, 32, 32, -- esc_type
    80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32, -- com_version
    0, -- flight_mode
    0, -- lipo_cell_count
    0, -- volt_cutoff_type
    3, -- cutoff_voltage
    0, -- bec_voltage
    11, -- startup_time
    6, -- gov_p_gain
    5, -- gov_i_gain
    25, -- auto_restart
    1, -- restart_time
    0, -- brake_type
    0, -- brake_force
    24, -- timing
    0, -- rotation
    0, -- active_freewheel
    2 -- startup_power
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
