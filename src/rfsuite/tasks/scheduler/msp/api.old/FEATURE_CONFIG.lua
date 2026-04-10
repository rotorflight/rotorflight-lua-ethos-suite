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

local API_NAME = "FEATURE_CONFIG"
local MSP_API_CMD_READ = 36
local MSP_API_CMD_WRITE = 37
local MSP_REBUILD_ON_WRITE = false

local pwmProtocol

local onoff = {"@i18n(api.MOTOR_CONFIG.tbl_off)@", "@i18n(api.MOTOR_CONFIG.tbl_on)@"}

-- IMPORTANT: keep entries ordered so index == bit number (bit0 first, bit1 second, etc)
local features_bitmap = {
  { field = "rx_ppm",          tableIdxInc = -1, table = onoff }, -- bit 0
  { field = "unused_1",        tableIdxInc = -1, table = onoff }, -- bit 1
  { field = "unused_2",        tableIdxInc = -1, table = onoff }, -- bit 2
  { field = "rx_serial",       tableIdxInc = -1, table = onoff }, -- bit 3
  { field = "unused_4",        tableIdxInc = -1, table = onoff }, -- bit 4
  { field = "unused_5",        tableIdxInc = -1, table = onoff }, -- bit 5
  { field = "softserial",      tableIdxInc = -1, table = onoff }, -- bit 6
  { field = "gps",             tableIdxInc = -1, table = onoff }, -- bit 7
  { field = "unused_8",        tableIdxInc = -1, table = onoff }, -- bit 8
  { field = "rangefinder",     tableIdxInc = -1, table = onoff }, -- bit 9
  { field = "telemetry",       tableIdxInc = -1, table = onoff }, -- bit 10
  { field = "unused_11",       tableIdxInc = -1, table = onoff }, -- bit 11
  { field = "unused_12",       tableIdxInc = -1, table = onoff }, -- bit 12
  { field = "rx_parallel_pwm", tableIdxInc = -1, table = onoff }, -- bit 13
  { field = "rx_msp",          tableIdxInc = -1, table = onoff }, -- bit 14
  { field = "rssi_adc",        tableIdxInc = -1, table = onoff }, -- bit 15
  { field = "led_strip",       tableIdxInc = -1, table = onoff }, -- bit 16
  { field = "dashboard",       tableIdxInc = -1, table = onoff }, -- bit 17
  { field = "osd",             tableIdxInc = -1, table = onoff }, -- bit 18
  { field = "cms",             tableIdxInc = -1, table = onoff }, -- bit 19
  { field = "unused_20",       tableIdxInc = -1, table = onoff }, -- bit 20
  { field = "unused_21",       tableIdxInc = -1, table = onoff }, -- bit 21
  { field = "unused_22",       tableIdxInc = -1, table = onoff }, -- bit 22
  { field = "unused_23",       tableIdxInc = -1, table = onoff }, -- bit 23
  { field = "unused_24",       tableIdxInc = -1, table = onoff }, -- bit 24
  { field = "rx_spi",          tableIdxInc = -1, table = onoff }, -- bit 25
  { field = "governor",        tableIdxInc = -1, table = onoff }, -- bit 26
  { field = "esc_sensor",      tableIdxInc = -1, table = onoff }, -- bit 27
  { field = "freq_sensor",     tableIdxInc = -1, table = onoff }, -- bit 28
  { field = "dyn_notch",       tableIdxInc = -1, table = onoff }, -- bit 29
  { field = "rpm_filter",      tableIdxInc = -1, table = onoff }, -- bit 30
}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
  { field = "enabledFeatures", type = "U32", apiVersion = {12, 0, 6}, simResponse = {0,0,0,0}, bitmap = features_bitmap },
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
