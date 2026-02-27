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

local API_NAME = "FILTER_CONFIG"
local MSP_API_CMD_READ = 92
local MSP_API_CMD_WRITE = 93
local MSP_REBUILD_ON_WRITE = false

local gyroFilterType = {[0] = "@i18n(api.FILTER_CONFIG.tbl_none)@", [1] = "@i18n(api.FILTER_CONFIG.tbl_1st)@", [2] = "@i18n(api.FILTER_CONFIG.tbl_2nd)@"}
local rpmPreset = {"@i18n(api.FILTER_CONFIG.tbl_custom)@", "@i18n(api.FILTER_CONFIG.tbl_low)@", "@i18n(api.FILTER_CONFIG.tbl_medium)@", "@i18n(api.FILTER_CONFIG.tbl_high)@"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "gyro_hardware_lpf",         type = "U8",  apiVersion = {12, 0, 7}, simResponse = {0},           help = "@i18n(api.FILTER_CONFIG.gyro_hardware_lpf)@" },
    { field = "gyro_lpf1_type",            type = "U8",  apiVersion = {12, 0, 7}, simResponse = {1},           min = 0,  max = #gyroFilterType, table = gyroFilterType, help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_type)@" },
    { field = "gyro_lpf1_static_hz",       type = "U16", apiVersion = {12, 0, 7}, simResponse = {100, 0},    min = 0,  max = 4000, unit = "Hz", default = 100, help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_static_hz)@" },
    { field = "gyro_lpf2_type",            type = "U8",  apiVersion = {12, 0, 7}, simResponse = {0},           min = 0,  max = #gyroFilterType, table = gyroFilterType, help = "@i18n(api.FILTER_CONFIG.gyro_lpf2_type)@" },
    { field = "gyro_lpf2_static_hz",       type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0},      min = 0,  max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_lpf2_static_hz)@" },
    { field = "gyro_soft_notch_hz_1",      type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0},      min = 0,  max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_hz_1)@" },
    { field = "gyro_soft_notch_cutoff_1",  type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0},      min = 0,  max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_cutoff_1)@" },
    { field = "gyro_soft_notch_hz_2",      type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0},      min = 0,  max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_hz_2)@" },
    { field = "gyro_soft_notch_cutoff_2",  type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0},      min = 0,  max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_cutoff_2)@" },
    { field = "gyro_lpf1_dyn_min_hz",      type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0},      min = 0,  max = 1000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_dyn_min_hz)@" },
    { field = "gyro_lpf1_dyn_max_hz",      type = "U16", apiVersion = {12, 0, 7}, simResponse = {25, 0},     min = 0,  max = 1000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_dyn_max_hz)@" },
    { field = "dyn_notch_count",           type = "U8",  apiVersion = {12, 0, 7}, simResponse = {0},           min = 0,  max = 8, help = "@i18n(api.FILTER_CONFIG.dyn_notch_count)@" },
    { field = "dyn_notch_q",               type = "U8",  apiVersion = {12, 0, 7}, simResponse = {100},         min = 0,  max = 100, decimals = 1, scale = 10, help = "@i18n(api.FILTER_CONFIG.dyn_notch_q)@" },
    { field = "dyn_notch_min_hz",          type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0},      min = 10, max = 200, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.dyn_notch_min_hz)@" },
    { field = "dyn_notch_max_hz",          type = "U16", apiVersion = {12, 0, 7}, simResponse = {0, 0},      min = 100, max = 500, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.dyn_notch_max_hz)@" },
    { field = "rpm_preset",                type = "U8",  apiVersion = {12, 0, 8}, simResponse = {1},           table = rpmPreset, tableIdxInc = -1, help = "@i18n(api.FILTER_CONFIG.rpm_preset)@" },
    { field = "rpm_min_hz",                type = "U8",  apiVersion = {12, 0, 8}, simResponse = {20},          min = 1,  max = 100, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.rpm_min_hz)@" },
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
