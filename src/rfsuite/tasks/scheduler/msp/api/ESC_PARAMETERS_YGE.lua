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

local API_NAME = "ESC_PARAMETERS_YGE"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_REBUILD_ON_WRITE = false
local MSP_SIGNATURE = 0xA5
local MSP_HEADER_BYTES = 2

local escMode = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_modefree)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeext)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeheli)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modestore)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeglider)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeair)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modef3a)@"}
local direction = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_reverse)@"}
local cuttoff = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_slowdown)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_cutoff)@"}
local cuttoffVoltage = {"2.9 V", "3.0 V", "3.1 V", "3.2 V", "3.3 V", "3.4 V"}
local offOn = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_on)@"}
local startupResponse = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_smooth)@"}
local throttleResponse = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_slow)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_medium)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_fast)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_custom)@"}
local motorTiming = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_autonorm)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autoefficient)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autopower)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autoextreme)@", "0°", "6°", "12°", "18°", "24°", "30°"}
local motorTimingToUI = {0, 4, 5, 6, 7, 8, 9, [16] = 0, [17] = 1, [18] = 2, [19] = 3}
local motorTimingFromUI = {0, 17, 18, 19, 1, 2, 3, 4, 5, 6}
local freewheel = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_auto)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_unused)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_alwayson)@"}

local flags_bitmap = {{field = "direction", tableIdxInc = -1, table = direction}, {field = "f3cauto", tableIdxInc = -1, table = offOn}, {field = "keepmah", tableIdxInc = -1, table = offOn}, {field = "bec12v", tableIdxInc = -1, table = offOn}}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature", type = "U8", apiVersion = {12, 0, 7}, simResponse = {165}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_signature)@"},
    {field = "esc_command", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_command)@"},
    {field = "esc_model", type = "U8", apiVersion = {12, 0, 7}, simResponse = {32}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_model)@"},
    {field = "esc_version", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_version)@"},
    {field = "governor", type = "U16", apiVersion = {12, 0, 7}, simResponse = {3, 0}, min = 1, max = #escMode, table = escMode, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_YGE.governor)@"},
    {field = "lv_bec_voltage", type = "U16", apiVersion = {12, 0, 7}, simResponse = {55, 0}, unit = "v", min = 55, max = 84, scale = 10, decimals = 1, help = "@i18n(api.ESC_PARAMETERS_YGE.lv_bec_voltage)@"},
    {field = "timing", type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0}, min = 0, max = #motorTiming, tableIdxInc = -1, table = motorTiming, help = "@i18n(api.ESC_PARAMETERS_YGE.timing)@"},
    {field = "acceleration", type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.acceleration)@"},
    {field = "gov_p", type = "U16", apiVersion = {12, 0, 7}, simResponse = {4, 0}, min = 1, max = 10, help = "@i18n(api.ESC_PARAMETERS_YGE.gov_p)@"},
    {field = "gov_i", type = "U16", apiVersion = {12, 0, 7}, simResponse = {3, 0}, min = 1, max = 10, help = "@i18n(api.ESC_PARAMETERS_YGE.gov_i)@"},
    {field = "throttle_response", type = "U16", apiVersion = {12, 0, 7}, simResponse = {1, 0}, min = 0, max = #throttleResponse, tableIdxInc = -1, table = throttleResponse, help = "@i18n(api.ESC_PARAMETERS_YGE.throttle_response)@"},
    {field = "auto_restart_time", type = "U16", apiVersion = {12, 0, 7}, simResponse = {1, 0}, min = 0, max = #cuttoff, tableIdxInc = -1, table = cuttoff, help = "@i18n(api.ESC_PARAMETERS_YGE.auto_restart_time)@"},
    {field = "cell_cutoff", type = "U16", apiVersion = {12, 0, 7}, simResponse = {2, 0}, min = 0, max = #cuttoffVoltage, tableIdxInc = -1, table = cuttoffVoltage, help = "@i18n(api.ESC_PARAMETERS_YGE.cell_cutoff)@"},
    {field = "active_freewheel", type = "U16", apiVersion = {12, 0, 7}, simResponse = {3, 0}, min = 0, max = #freewheel, tableIdxInc = -1, table = freewheel, help = "@i18n(api.ESC_PARAMETERS_YGE.active_freewheel)@"},
    {field = "esc_type", type = "U16", apiVersion = {12, 0, 7}, simResponse = {80, 3}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_type)@"},
    {field = "firmware_version", type = "U32", apiVersion = {12, 0, 7}, simResponse = {131, 148, 1, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.firmware_version)@"},
    {field = "serial_number", type = "U32", apiVersion = {12, 0, 7}, simResponse = {30, 170, 0, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.serial_number)@"},
    {field = "unknown_1", type = "U16", apiVersion = {12, 0, 7}, simResponse = {3, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.unknown_1)@"},
    {field = "stick_zero_us", type = "U16", apiVersion = {12, 0, 7}, simResponse = {86, 4}, min = 900, max = 1900, unit = "us", help = "@i18n(api.ESC_PARAMETERS_YGE.stick_zero_us)@"},
    {field = "stick_range_us", type = "U16", apiVersion = {12, 0, 7}, simResponse = {22, 3}, min = 600, max = 1500, unit = "us", help = "@i18n(api.ESC_PARAMETERS_YGE.stick_range_us)@"},
    {field = "unknown_2", type = "U16", apiVersion = {12, 0, 7}, simResponse = {163, 15}, help = "@i18n(api.ESC_PARAMETERS_YGE.unknown_2)@"},
    {field = "motor_poll_pairs", type = "U16", apiVersion = {12, 0, 7}, simResponse = {1, 0}, min = 1, max = 100, help = "@i18n(api.ESC_PARAMETERS_YGE.motor_poll_pairs)@"},
    {field = "pinion_teeth", type = "U16", apiVersion = {12, 0, 7}, simResponse = {2, 0}, min = 1, max = 255, help = "@i18n(api.ESC_PARAMETERS_YGE.pinion_teeth)@"},
    {field = "main_teeth", type = "U16", apiVersion = {12, 0, 7}, simResponse = {2, 0}, min = 1, max = 1800, help = "@i18n(api.ESC_PARAMETERS_YGE.main_teeth)@"},
    {field = "min_start_power", type = "U16", apiVersion = {12, 0, 7}, simResponse = {20, 0}, min = 0, max = 26, unit = "%", help = "@i18n(api.ESC_PARAMETERS_YGE.min_start_power)@"},
    {field = "max_start_power", type = "U16", apiVersion = {12, 0, 7}, simResponse = {20, 0}, min = 0, max = 31, unit = "%", help = "@i18n(api.ESC_PARAMETERS_YGE.max_start_power)@"},
    {field = "unknown_3", type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.unknown_3)@"},
    {field = "flags", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, bitmap = flags_bitmap, help = "@i18n(api.ESC_PARAMETERS_YGE.flags)@"},
    {field = "unknown_4", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, min = 0, max = 1, tableIdxInc = -1, table = offOn, help = "@i18n(api.ESC_PARAMETERS_YGE.unknown_4)@"},
    {field = "current_limit", type = "U16", apiVersion = {12, 0, 7}, simResponse = {2, 19}, unit = "A", min = 1, max = 65500, decimals = 2, scale = 100, help = "@i18n(api.ESC_PARAMETERS_YGE.current_limit)@"}
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
    }
})
