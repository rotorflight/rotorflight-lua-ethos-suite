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

local API_NAME = "ESC_PARAMETERS_FLYROTOR"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_REBUILD_ON_WRITE = false
local MSP_SIGNATURE = 0x73
local MSP_HEADER_BYTES = 2

local tblLed = {"CUSTOM", "OFF", "RED", "GREEN", "BLUE", "YELLOW", "MAGENTA", "CYAN", "WHITE", "ORANGE", "GRAY", "MAROON", "DARK_GREEN", "NAVY", "PURPLE", "TEAL", "SILVER", "PINK", "GOLD", "BROWN", "LIGHT_BLUE", "FL_PINK", "FL_ORANGE", "FL_LIME", "FL_MINT", "FL_CYAN", "FL_PURPLE", "FL_HOT_PINK", "FL_LIGHT_YELLOW", "FL_AQUAMARINE", "FL_GOLD", "FL_DEEP_PINK", "FL_NEON_GREEN", "FL_ORANGE_RED"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature", type = "U8", apiVersion = {12, 0, 7}, simResponse = {115}},
    {field = "esc_command", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}},
    {field = "esc_type", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}},
    {field = "esc_model", type = "U16", apiVersion = {12, 0, 7}, simResponse = {1, 24}, byteorder = "big"},
    {field = "esc_sn", type = "U64", apiVersion = {12, 0, 7}, simResponse = {231, 79, 190, 216, 78, 29, 169, 244}},
    {field = "esc_iap", type = "U24", apiVersion = {12, 0, 7}, simResponse = {1, 0, 0}},
    {field = "esc_fw", type = "U24", apiVersion = {12, 0, 7}, simResponse = {1, 0, 1}},
    {field = "esc_hardware", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}},
    {field = "throttle_min", type = "U16", apiVersion = {12, 0, 7}, simResponse = {4, 76}, byteorder = "big"},
    {field = "throttle_max", type = "U16", apiVersion = {12, 0, 7}, simResponse = {7, 148}, byteorder = "big"},
    {field = "esc_mode", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_escgov)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_linear_thr)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_rf_gov)@"}, tableIdxInc = -1},
    {field = "cell_count", type = "U8", apiVersion = {12, 0, 7}, simResponse = {6}, min = 4, max = 14, default = 6},
    {field = "low_voltage_protection", type = "U8", apiVersion = {12, 0, 7}, simResponse = {30}, min = 28, max = 38, scale = 10, default = 30, decimals = 1, unit = "V"},
    {field = "temperature_protection", type = "U8", apiVersion = {12, 0, 7}, simResponse = {125}, min = 50, max = 135, default = 125, unit = "°"},
    {field = "bec_voltage", type = "U8", apiVersion = {12, 0, 7}, simResponse = {1}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "7.5V", "8.0V", "8.5V", "12.0V"}, tableIdxInc = -1},
    {field = "electrical_angle", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_auto)@", "1°", "2°", "3°", "4°", "5°", "6°", "7°", "8°", "9°", "10°"}, tableIdxInc = -1},
    {field = "motor_direction", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_cw)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_ccw)@"}, tableIdxInc = -1},
    {field = "starting_torque", type = "U8", apiVersion = {12, 0, 7}, simResponse = {3}, min = 1, max = 15, default = 3},
    {field = "response_speed", type = "U8", apiVersion = {12, 0, 7}, simResponse = {5}, min = 1, max = 15, default = 5},
    {field = "buzzer_volume", type = "U8", apiVersion = {12, 0, 7}, simResponse = {1}, min = 1, max = 5, default = 2},
    {field = "current_gain", type = "S8", apiVersion = {12, 0, 7}, simResponse = {20}, min = 0, max = 40, default = 20, offset = -20},
    {field = "fan_control", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_automatic)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_alwayson)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_alwaysoff)@"}, tableIdxInc = -1},
    {field = "soft_start", type = "U8", apiVersion = {12, 0, 7}, simResponse = {15}, min = 5, max = 55, default = 15, unit = "s"},
    {field = "auto_restart_time", type = "U8", apiVersion = {12, 0, 7}, simResponse = {15}, min = 0, max = 100, default = 30, unit = "s"},
    {field = "restart_acc", type = "U8", apiVersion = {12, 0, 7}, simResponse = {15}, min = 1, max = 10, default = 5},
    {field = "gov_p", type = "U8", apiVersion = {12, 0, 7}, simResponse = {45}, min = 0, max = 100, default = 45},
    {field = "gov_i", type = "U8", apiVersion = {12, 0, 7}, simResponse = {35}, min = 0, max = 100, default = 35},
    {field = "active_freewheel", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, min = 0, max = 1, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_enabled)@"}, tableIdxInc = -1},
    {field = "drive_freq", type = "U8", apiVersion = {12, 0, 7}, simResponse = {16}, min = 10, max = 24, default = 16, unit = "KHz"},
    {field = "motor_erpm_max", type = "U24", apiVersion = {12, 0, 7}, simResponse = {2, 23, 40}, min = 0, max = 1000000, step = 100, byteorder = "big"},
    {field = "throttle_protocol", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, min = 0, max = 0, table = {"PWM"}, tableIdxInc = -1},
    {field = "telemetry_protocol", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, min = 0, max = 0, table = {"FLYROTOR"}, tableIdxInc = -1},
    {field = "led_color_index", type = "U8", apiVersion = {12, 0, 8}, simResponse = {3}, min = 0, max = #tblLed - 1, table = tblLed, tableIdxInc = -1},
    {field = "led_color_rgb", type = "U24", apiVersion = {12, 0, 8}, simResponse = {0, 0, 0}},
    {field = "motor_temp_sensor", type = "U8", apiVersion = {12, 0, 8}, simResponse = {0}, min = 0, max = 1, table = {"@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_disabled)@", "@i18n(api.ESC_PARAMETERS_FLYROTOR.tbl_enabled)@"}, tableIdxInc = -1},
    {field = "motor_temp", type = "U8", apiVersion = {12, 0, 8}, simResponse = {100}, min = 50, max = 150, unit = "°"},
    {field = "battery_capacity", type = "U16", apiVersion = {12, 0, 8}, simResponse = {0, 0}, min = 0, max = 50000, step = 100, unit = "mAh", byteorder = "big"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function processedData() rfsuite.utils.log("Processed data", "debug") end

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
        mspSignature = MSP_SIGNATURE,
        mspHeaderBytes = MSP_HEADER_BYTES,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
