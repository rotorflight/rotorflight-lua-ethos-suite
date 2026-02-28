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

local API_NAME = "SERVO_OVERRIDE"
local MSP_API_CMD_READ = 192
local MSP_API_CMD_WRITE = 193
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "servo_1", type = "U16", apiVersion = {12, 0, 6}, simResponse = {209, 7}, help = "@i18n(api.SERVO_OVERRIDE.servo_1)@"},
    {field = "servo_2", type = "U16", apiVersion = {12, 0, 6}, simResponse = {209, 7}, help = "@i18n(api.SERVO_OVERRIDE.servo_2)@"},
    {field = "servo_3", type = "U16", apiVersion = {12, 0, 6}, simResponse = {209, 7}, help = "@i18n(api.SERVO_OVERRIDE.servo_3)@"},
    {field = "servo_4", type = "U16", apiVersion = {12, 0, 6}, simResponse = {209, 7}, help = "@i18n(api.SERVO_OVERRIDE.servo_4)@"},
    {field = "servo_5", type = "U16", apiVersion = {12, 0, 6}, simResponse = {209, 7}, help = "@i18n(api.SERVO_OVERRIDE.servo_5)@"},
    {field = "servo_6", type = "U16", apiVersion = {12, 0, 6}, simResponse = {209, 7}, help = "@i18n(api.SERVO_OVERRIDE.servo_6)@"},
    {field = "servo_7", type = "U16", apiVersion = {12, 0, 6}, simResponse = {209, 7}, help = "@i18n(api.SERVO_OVERRIDE.servo_7)@"},
    {field = "servo_8", type = "U16", apiVersion = {12, 0, 6}, simResponse = {209, 7}, help = "@i18n(api.SERVO_OVERRIDE.servo_8)@"}
}

local MSP_API_STRUCTURE_WRITE = {
    {field = "servo_id", type = "U8"}, {field = "action", type = "U8"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ = core.filterByApiVersion(MSP_API_STRUCTURE_READ_DATA)

local MSP_MIN_BYTES = core.calculateMinBytes(MSP_API_STRUCTURE_READ)

local MSP_API_SIMULATOR_RESPONSE = core.buildSimResponse(MSP_API_STRUCTURE_READ)

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
