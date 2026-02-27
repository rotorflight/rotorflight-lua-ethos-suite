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

local API_NAME = "ESC_PARAMETERS_SCORPION"
local MSP_API_CMD_READ = 217
local MSP_API_CMD_WRITE = 218
local MSP_REBUILD_ON_WRITE = false
local MSP_SIGNATURE = 0x53
local MSP_HEADER_BYTES = 2

local escMode = {"@i18n(api.ESC_PARAMETERS_SCORPION.tbl_heligov)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_helistore)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_vbargov)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_extgov)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_airplane)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_boat)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_quad)@"}
local rotation = {"@i18n(api.ESC_PARAMETERS_SCORPION.tbl_ccw)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_cw)@"}
local becVoltage = {"5.1 V", "6.1 V", "7.3 V", "8.3 V", "Disabled"}
local teleProtocol = {"@i18n(api.ESC_PARAMETERS_SCORPION.tbl_standard)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_vbar)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_exbus)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_unsolicited)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_futsbus)@"}
local onOff = {"@i18n(api.ESC_PARAMETERS_SCORPION.tbl_on)@", "@i18n(api.ESC_PARAMETERS_SCORPION.tbl_off)@"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature", type = "U8", apiVersion = {12, 0, 7}, simResponse = {83}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.esc_signature)@"},
    {field = "esc_command", type = "U8", apiVersion = {12, 0, 7}, simResponse = {128}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.esc_command)@"},
    {field = "escinfo_1", type = "U8", apiVersion = {12, 0, 7}, simResponse = {84}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_1)@"},
    {field = "escinfo_2", type = "U8", apiVersion = {12, 0, 7}, simResponse = {114}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_2)@"},
    {field = "escinfo_3", type = "U8", apiVersion = {12, 0, 7}, simResponse = {105}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_3)@"},
    {field = "escinfo_4", type = "U8", apiVersion = {12, 0, 7}, simResponse = {98}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_4)@"},
    {field = "escinfo_5", type = "U8", apiVersion = {12, 0, 7}, simResponse = {117}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_5)@"},
    {field = "escinfo_6", type = "U8", apiVersion = {12, 0, 7}, simResponse = {110}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_6)@"},
    {field = "escinfo_7", type = "U8", apiVersion = {12, 0, 7}, simResponse = {117}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_7)@"},
    {field = "escinfo_8", type = "U8", apiVersion = {12, 0, 7}, simResponse = {115}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_8)@"},
    {field = "escinfo_9", type = "U8", apiVersion = {12, 0, 7}, simResponse = {32}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_9)@"},
    {field = "escinfo_10", type = "U8", apiVersion = {12, 0, 7}, simResponse = {69}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_10)@"},
    {field = "escinfo_11", type = "U8", apiVersion = {12, 0, 7}, simResponse = {83}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_11)@"},
    {field = "escinfo_12", type = "U8", apiVersion = {12, 0, 7}, simResponse = {67}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_12)@"},
    {field = "escinfo_13", type = "U8", apiVersion = {12, 0, 7}, simResponse = {45}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_13)@"},
    {field = "escinfo_14", type = "U8", apiVersion = {12, 0, 7}, simResponse = {54}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_14)@"},
    {field = "escinfo_15", type = "U8", apiVersion = {12, 0, 7}, simResponse = {83}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_15)@"},
    {field = "escinfo_16", type = "U8", apiVersion = {12, 0, 7}, simResponse = {45}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_16)@"},
    {field = "escinfo_17", type = "U8", apiVersion = {12, 0, 7}, simResponse = {56}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_17)@"},
    {field = "escinfo_18", type = "U8", apiVersion = {12, 0, 7}, simResponse = {48}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_18)@"},
    {field = "escinfo_19", type = "U8", apiVersion = {12, 0, 7}, simResponse = {65}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_19)@"},
    {field = "escinfo_20", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_20)@"},
    {field = "escinfo_21", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_21)@"},
    {field = "escinfo_22", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_22)@"},
    {field = "escinfo_23", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_23)@"},
    {field = "escinfo_24", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_24)@"},
    {field = "escinfo_25", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_25)@"},
    {field = "escinfo_26", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_26)@"},
    {field = "escinfo_27", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_27)@"},
    {field = "escinfo_28", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_28)@"},
    {field = "escinfo_29", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_29)@"},
    {field = "escinfo_30", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_30)@"},
    {field = "escinfo_31", type = "U8", apiVersion = {12, 0, 7}, simResponse = {4}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_31)@"},
    {field = "escinfo_32", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.escinfo_32)@"},
    {field = "esc_mode", type = "U16", apiVersion = {12, 0, 7}, simResponse = {3, 0}, min = 0, max = #escMode, tableIdxInc = -1, table = escMode, help = "@i18n(api.ESC_PARAMETERS_SCORPION.esc_mode)@"},
    {field = "bec_voltage", type = "U16", apiVersion = {12, 0, 7}, simResponse = {3, 0}, min = 0, max = #becVoltage, tableIdxInc = -1, table = becVoltage, help = "@i18n(api.ESC_PARAMETERS_SCORPION.bec_voltage)@"},
    {field = "rotation", type = "U16", apiVersion = {12, 0, 7}, simResponse = {1, 0}, min = 0, max = #rotation, tableIdxInc = -1, table = rotation, help = "@i18n(api.ESC_PARAMETERS_SCORPION.rotation)@"},
    {field = "telemetry_protocol", type = "U16", apiVersion = {12, 0, 7}, simResponse = {3, 0}, min = 0, max = #teleProtocol, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_SCORPION.telemetry_protocol)@", table = teleProtocol},
    {field = "protection_delay", type = "U16", apiVersion = {12, 0, 7}, simResponse = {136, 19}, min = 0, max = 5000, unit = "s", scale = 1000, help = "@i18n(api.ESC_PARAMETERS_SCORPION.protection_delay)@"},
    {field = "min_voltage", type = "U16", apiVersion = {12, 0, 7}, simResponse = {22, 3}, min = 0, max = 7000, unit = "v", decimals = 1, scale = 100, help = "@i18n(api.ESC_PARAMETERS_SCORPION.min_voltage)@"},
    {field = "max_temperature", type = "U16", apiVersion = {12, 0, 7}, simResponse = {16, 39}, min = 0, max = 40000, unit = "°", scale = 100, help = "@i18n(api.ESC_PARAMETERS_SCORPION.max_temperature)@"},
    {field = "max_current", type = "U16", apiVersion = {12, 0, 7}, simResponse = {64, 31}, min = 0, max = 30000, unit = "A", scale = 100, help = "@i18n(api.ESC_PARAMETERS_SCORPION.max_current)@"},
    {field = "cutoff_handling", type = "U16", apiVersion = {12, 0, 7}, simResponse = {136, 19}, min = 0, max = 10000, unit = "%", scale = 100, help = "@i18n(api.ESC_PARAMETERS_SCORPION.cutoff_handling)@"},
    {field = "max_used", type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0}, min = 0, max = 6000, unit = "Ah", scale = 100, help = "@i18n(api.ESC_PARAMETERS_SCORPION.max_used)@"},
    {field = "motor_startup_sound", type = "U16", apiVersion = {12, 0, 7}, simResponse = {1, 0}, min = 0, max = #onOff, tableIdxInc = -1, table = onOff, help = "@i18n(api.ESC_PARAMETERS_SCORPION.motor_startup_sound)@"},
    {field = "padding_1", type = "U16", apiVersion = {12, 0, 7}, simResponse = {7, 2}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.padding_1)@"},
    {field = "padding_2", type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 6}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.padding_2)@"},
    {field = "padding_3", type = "U16", apiVersion = {12, 0, 7}, simResponse = {63, 0}, help = "@i18n(api.ESC_PARAMETERS_SCORPION.padding_3)@"},
    {field = "soft_start_time", type = "U16", apiVersion = {12, 0, 7}, simResponse = {160, 15}, unit = "s", min = 0, max = 60000, scale = 1000, help = "@i18n(api.ESC_PARAMETERS_SCORPION.soft_start_time)@"},
    {field = "runup_time", type = "U16", apiVersion = {12, 0, 7}, simResponse = {64, 31}, unit = "s", min = 0, max = 60000, scale = 1000, help = "@i18n(api.ESC_PARAMETERS_SCORPION.runup_time)@"},
    {field = "bailout", type = "U16", apiVersion = {12, 0, 7}, simResponse = {208, 7}, unit = "s", min = 0, max = 100000, scale = 1000, help = "@i18n(api.ESC_PARAMETERS_SCORPION.bailout)@"},
    {field = "gov_proportional", type = "U32", apiVersion = {12, 0, 7}, simResponse = {100, 0, 0, 0}, min = 30, max = 180, scale = 100, help = "@i18n(api.ESC_PARAMETERS_SCORPION.gov_proportional)@"},
    {field = "gov_integral", type = "U32", apiVersion = {12, 0, 7}, simResponse = {200, 0, 0, 0}, min = 150, max = 250, scale = 100, help = "@i18n(api.ESC_PARAMETERS_SCORPION.gov_integral)@"}
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
