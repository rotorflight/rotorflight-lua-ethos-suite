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

local API_NAME = "BATTERY_CONFIG"
local MSP_API_CMD_READ = 32
local MSP_API_CMD_WRITE = 33
local MSP_REBUILD_ON_WRITE = false

local tblBatterySource = {
    [1] = "@i18n(api.BATTERY_CONFIG.source_none)@",
    [2] = "@i18n(api.BATTERY_CONFIG.source_adc)@",
    [3] = "@i18n(api.BATTERY_CONFIG.source_esc)@",
}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "batteryCapacity", type = "U16", apiVersion = {12, 0, 6}, simResponse = {136, 19}, min = 0, max = 20000, step = 50, unit = "mAh", default = 0},
    {field = "batteryCellCount", type = "U8", apiVersion = {12, 0, 6}, simResponse = {6}, min = 0, max = 24, unit = nil, default = 6},
    {field = "voltageMeterSource", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1}, table = tblBatterySource, tableIdxInc = -1},
    {field = "currentMeterSource", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1}, table = tblBatterySource, tableIdxInc = -1},
    {field = "vbatmincellvoltage", type = "U16", apiVersion = {12, 0, 6}, simResponse = {74, 1}, min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 3.3},
    {field = "vbatmaxcellvoltage", type = "U16", apiVersion = {12, 0, 6}, simResponse = {164, 1}, min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 4.2},
    {field = "vbatfullcellvoltage", type = "U16", apiVersion = {12, 0, 6}, simResponse = {154, 1}, min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 4.1},
    {field = "vbatwarningcellvoltage", type = "U16", apiVersion = {12, 0, 6}, simResponse = {94, 1}, min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 3.5},
    {field = "lvcPercentage", type = "U8", apiVersion = {12, 0, 6}, simResponse = {100}},
    {field = "consumptionWarningPercentage", type = "U8", apiVersion = {12, 0, 6}, simResponse = {30}, min = 0, max = 50, default = 35, unit = "%"}
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
