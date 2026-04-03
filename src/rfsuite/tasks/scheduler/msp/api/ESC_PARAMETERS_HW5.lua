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

--[[
    Maintenance note:
    Keep this API module focused on the raw HW5 MSP payload and generic field bounds.

    Model-specific option lists and field availability are owned by the client/page layer
    in app/modules/esc_tools/tools/escmfg/hw5/profile.lua.

    When aligning HW5 variants, use the HobbyWing USB Link INI files as the reference:
      C:\Program Files (x86)\HobbyWing USB Link\Lcd
      /mnt/c/Program Files (x86)/HobbyWing USB Link/Lcd

    In particular, the Platinum_V5 *.ini files define per-model choices such as:
    LiPo cell options, BEC voltage ranges, brake modes, cutoff ranges, and unsupported fields.
]] --

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
    { field = "bec_voltage", type = "U8", apiVersion = {12, 0, 7}, simResponse = { 0 }, default = 0, min = 0, max = 70},
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
    readRetryOnErrorReply = true,
    readRetryBackoff = 0.35,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        mspSignature = MSP_SIGNATURE,
        mspHeaderBytes = MSP_HEADER_BYTES,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
