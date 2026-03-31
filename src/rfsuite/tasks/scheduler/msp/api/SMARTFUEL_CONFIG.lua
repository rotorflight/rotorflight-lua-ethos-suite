--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then msp.apicore = core end
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "SMARTFUEL_CONFIG"
local MSP_API_CMD_READ = 0x3006
local MSP_API_CMD_WRITE = 0x3007

local sourceTable = {
    "@i18n(api.BATTERY_INI.tbl_off)@",
    "@i18n(api.BATTERY_INI.tbl_on)@"
}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "smartfuel_source",       type = "U8",  tableIdxInc = -1, table = sourceTable, default = 0, min = 0, max = 1, simResponse = {0} },
    { field = "stabilize_delay",        type = "U16", default = 1500, min = 0, max = 10000, decimals = 1, scale = 1000, unit = "s", simResponse = {220, 5} },
    { field = "stable_window",          type = "U16", default = 15,   min = 0, max = 100, decimals = 2, scale = 100, unit = "V", simResponse = {15, 0} },
    { field = "voltage_fall_limit",     type = "U16", default = 5,    min = 0, max = 100, decimals = 2, scale = 100, unit = "V/s", simResponse = {5, 0} },
    { field = "fuel_drop_rate",         type = "U16", default = 10,   min = 0, max = 500, decimals = 1, scale = 10, unit = "%/s", simResponse = {10, 0} },
    { field = "fuel_rise_rate",         type = "U16", default = 2,    min = 0, max = 500, decimals = 1, scale = 10, unit = "%/s", simResponse = {2, 0} },
    { field = "sag_multiplier_percent", type = "U16", default = 70,   min = 0, max = 200, unit = "%", simResponse = {70, 0} },
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
    return core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, state.rebuildOnWrite == true)
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
    writeRequiresStructure = true,
    writeUuidFallback = true,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
