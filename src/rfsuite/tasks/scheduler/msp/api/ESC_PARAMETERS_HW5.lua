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

local API_NAME = "ESC_PARAMETERS_HW5"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_REBUILD_ON_WRITE = false
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

-- LuaFormatter off
local voltage_lookup = {
    ["HW1104_V100456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["HW1106_V100456NB"] = {"5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4"},
    ["HW1106_V200456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["HW1106_V300456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["HW1121_V100456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["HW198_V1.00456NB"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "9.0", "9.1", "9.2", "9.3", "9.4", "9.5", "9.6", "9.7", "9.8", "9.9", "10.0", "10.1", "10.2", "10.3", "10.4", "10.5", "10.6", "10.7", "10.8", "10.9", "11.0", "11.1", "11.2", "11.3", "11.4", "11.5", "11.6", "11.7", "11.8", "11.9", "12.0"},
    ["default"] = {"5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4"}
}
-- LuaFormatter on

local voltages = voltage_lookup["default"]

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "esc_signature", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 253 }},
    { field = "esc_command", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }},
    { field = "firmware_version", type = "U128", apiVersion = {12, 0, 7}, simResponse = { 32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32 }},
    { field = "hardware_version", type = "U128", apiVersion = {12, 0, 7}, simResponse = { 72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66 }},
    { field = "esc_type", type = "U128", apiVersion = {12, 0, 7}, simResponse = { 80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32, 32, 32, 32, 32 }},
    { field = "com_version", type = "U120", apiVersion = {12, 0, 7}, simResponse = { 80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32 }},
    { field = "flight_mode", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, default = 0, min = 0, max = #flightMode, tableIdxInc = -1, table = flightMode},
    { field = "lipo_cell_count", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, default = 0, min = 0, max = #lipoCellCount, tableIdxInc = -1, table = lipoCellCount},
    { field = "volt_cutoff_type", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, default = 0, min = 0, max = #cutoffType, tableIdxInc = -1, table = cutoffType},
    { field = "cutoff_voltage", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 3 }, default = 3, min = 0, max = #cutoffVoltage, tableIdxInc = -1, table = cutoffVoltage},
    { field = "bec_voltage", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, default = 0, min = 0, max = #voltages, tableIdxInc = -1, table = voltages},
    { field = "startup_time", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 11 }, default = 0, min = 4, max = 25, unit = "s"},
    { field = "gov_p_gain", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 6 }, default = 0, min = 0, max = 9},
    { field = "gov_i_gain", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 5 }, default = 0, min = 0, max = 9},
    { field = "auto_restart", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 25 }, default = 25, units = "s", min = 0, max = 90},
    { field = "restart_time", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 1 }, default = 1, tableIdxInc = -1, min = 0, max = #restartTime, table = restartTime},
    { field = "brake_type", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, default = 0, min = 0, max = #brakeType, xvals = { 76 }, table = brakeType, tableIdxInc = -1},
    { field = "brake_force", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, default = 0, min = 0, max = 100},
    { field = "timing", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 24 }, default = 0, min = 0, max = 30},
    { field = "rotation", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, default = 0, min = 0, max = #rotation, tableIdxInc = -1, table = rotation},
    { field = "active_freewheel", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, min = 0, max = #enabledDisabled, table = enabledDisabled, tableIdxInc = -1, default = 0},
    { field = "startup_power", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 2 }, default = 2, min = 0, max = #startupPower, tableIdxInc = -1, table = startupPower},
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

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
        mspSignature = MSP_SIGNATURE,
        mspHeaderBytes = MSP_HEADER_BYTES,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        voltageTable = voltage_lookup,
    }
})
