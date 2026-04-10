--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "BLACKBOX_CONFIG"
local MSP_API_CMD_READ = 80
local MSP_API_CMD_WRITE = 81
local MSP_REBUILD_ON_WRITE = true

local offOn = {
    "@i18n(api.MOTOR_CONFIG.tbl_off)@",
    "@i18n(api.MOTOR_CONFIG.tbl_on)@"
}

local blackbox_fields_bitmap = {
    { field = "command",  tableIdxInc = -1, table = offOn }, -- bit 0
    { field = "setpoint", tableIdxInc = -1, table = offOn }, -- bit 1
    { field = "mixer",    tableIdxInc = -1, table = offOn }, -- bit 2
    { field = "pid",      tableIdxInc = -1, table = offOn }, -- bit 3
    { field = "attitude", tableIdxInc = -1, table = offOn }, -- bit 4
    { field = "gyroraw",  tableIdxInc = -1, table = offOn }, -- bit 5
    { field = "gyro",     tableIdxInc = -1, table = offOn }, -- bit 6
    { field = "acc",      tableIdxInc = -1, table = offOn }, -- bit 7
    { field = "mag",      tableIdxInc = -1, table = offOn }, -- bit 8
    { field = "alt",      tableIdxInc = -1, table = offOn }, -- bit 9
    { field = "battery",  tableIdxInc = -1, table = offOn }, -- bit 10
    { field = "rssi",     tableIdxInc = -1, table = offOn }, -- bit 11
    { field = "gps",      tableIdxInc = -1, table = offOn }, -- bit 12
    { field = "rpm",      tableIdxInc = -1, table = offOn }, -- bit 13
    { field = "motors",   tableIdxInc = -1, table = offOn }, -- bit 14
    { field = "servos",   tableIdxInc = -1, table = offOn }, -- bit 15
    { field = "vbec",     tableIdxInc = -1, table = offOn }, -- bit 16
    { field = "vbus",     tableIdxInc = -1, table = offOn }, -- bit 17
    { field = "temps",    tableIdxInc = -1, table = offOn }, -- bit 18
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 7}) then
    blackbox_fields_bitmap[#blackbox_fields_bitmap + 1] = { field = "esc", tableIdxInc = -1, table = offOn }   -- bit 19
    blackbox_fields_bitmap[#blackbox_fields_bitmap + 1] = { field = "bec", tableIdxInc = -1, table = offOn }   -- bit 20
    blackbox_fields_bitmap[#blackbox_fields_bitmap + 1] = { field = "esc2", tableIdxInc = -1, table = offOn }  -- bit 21
end

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    blackbox_fields_bitmap[#blackbox_fields_bitmap + 1] = { field = "governor", tableIdxInc = -1, table = offOn } -- bit 22
end

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    -- Sim values aligned to observed payload:
    -- READ [80]{1,1,1,8,0,127,238,7,0,0,0,0,5}
    { field = "blackbox_supported", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "device", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "mode", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "denom", type = "U16", apiVersion = {12, 0, 6}, simResponse = {8,0}, unit = "1/x" },
    { field = "fields", type = "U32", apiVersion = {12, 0, 6}, simResponse = {127,238,7,0}, bitmap = blackbox_fields_bitmap },
    { field = "initialEraseFreeSpaceKiB", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0,0}, mandatory = false, unit = "KiB" },
    { field = "rollingErase", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "gracePeriod", type = "U8", apiVersion = {12, 0, 6}, simResponse = {5}, mandatory = false, unit = "s" },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    { field = "device", type = "U8" },
    { field = "mode", type = "U8" },
    { field = "denom", type = "U16" },
    { field = "fields", type = "U32" },
    { field = "initialEraseFreeSpaceKiB", type = "U16", mandatory = false },
    { field = "rollingErase", type = "U8", mandatory = false },
    { field = "gracePeriod", type = "U8", mandatory = false },
}
-- LuaFormatter on

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
