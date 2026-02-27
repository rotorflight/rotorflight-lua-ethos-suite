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

local API_NAME = "ESC_SENSOR_CONFIG"
local MSP_API_CMD_READ = 123
local MSP_API_CMD_WRITE = 216
local MSP_REBUILD_ON_WRITE = false

local escTypes = {"NONE", "BLHELI32", "HOBBYWING V4", "HOBBYWING V5", "SCORPION", "KONTRONIK", "OMP", "ZTW", "APD", "OPENYGE", "FLYROTOR", "GRAUPNER", "XDFLY", "RECORD"}
local onOff = {"@i18n(api.ESC_SENSOR_CONFIG.tbl_off)@", "@i18n(api.ESC_SENSOR_CONFIG.tbl_on)@"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "protocol", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, table = escTypes, tableIdxInc = -1, help = "@i18n(api.ESC_SENSOR_CONFIG.protocol)@" },
    { field = "half_duplex", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, default = 0, min = 1, max = 2, table = onOff, tableIdxInc = -1, help = "@i18n(api.ESC_SENSOR_CONFIG.half_duplex)@" },
    { field = "update_hz", type = "U16", apiVersion = {12, 0, 6}, simResponse = {200, 0}, default = 200, min = 10, max = 500, unit = "Hz", help = "@i18n(api.ESC_SENSOR_CONFIG.update_hz)@" },
    { field = "current_offset", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 15}, min = 0, max = 1000, default = 0, help = "@i18n(api.ESC_SENSOR_CONFIG.current_offset)@" },
    { field = "hw4_current_offset", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, min = 0, max = 1000, default = 0, help = "@i18n(api.ESC_SENSOR_CONFIG.hw4_current_offset)@" },
    { field = "hw4_current_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.ESC_SENSOR_CONFIG.hw4_current_gain)@" },
    { field = "hw4_voltage_gain", type = "U8", apiVersion = {12, 0, 6}, simResponse = {30}, min = 0, max = 250, default = 30, help = "@i18n(api.ESC_SENSOR_CONFIG.hw4_voltage_gain)@" },
    { field = "pin_swap", type = "U8", apiVersion = {12, 0, 7}, simResponse = {0}, table = onOff, tableIdxInc = -1, help = "@i18n(api.ESC_SENSOR_CONFIG.pin_swap)@" },
    { field = "voltage_correction", mandatory = false, type = "S8", apiVersion = {12, 0, 8}, simResponse = {0}, unit = "%", default = 1, min = -99, max = 125, help = "@i18n(api.ESC_SENSOR_CONFIG.voltage_correction)@" },
    { field = "current_correction", mandatory = false, type = "S8", apiVersion = {12, 0, 8}, simResponse = {0}, unit = "%", default = 1, min = -99, max = 125, help = "@i18n(api.ESC_SENSOR_CONFIG.current_correction)@" },
    { field = "consumption_correction", mandatory = false, type = "S8", apiVersion = {12, 0, 8}, simResponse = {0}, unit = "%", default = 1, min = -99, max = 125, help = "@i18n(api.ESC_SENSOR_CONFIG.consumption_correction)@" },
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
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
