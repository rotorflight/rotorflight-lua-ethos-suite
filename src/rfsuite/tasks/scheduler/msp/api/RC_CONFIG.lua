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

local API_NAME = "RC_CONFIG"
local MSP_API_CMD_READ = 66
local MSP_API_CMD_WRITE = 67
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rc_center", type = "U16", apiVersion = {12, 0, 6}, simResponse = {220, 5}, min = 1400, max = 1600, default = 1500, unit = "us", help = "@i18n(api.RC_CONFIG.rc_center)@"},
    {field = "rc_deflection", type = "U16", apiVersion = {12, 0, 6}, simResponse = {254, 1}, min = 200, max = 700, default = 510, unit = "us", help = "@i18n(api.RC_CONFIG.rc_deflection)@"},
    {field = "rc_arm_throttle", type = "U16", apiVersion = {12, 0, 6}, simResponse = {232, 3}, min = 850, max = 1500, default = 1050, unit = "us", help = "@i18n(api.RC_CONFIG.rc_arm_throttle)@"},
    {field = "rc_min_throttle", type = "U16", apiVersion = {12, 0, 6}, simResponse = {242, 3}, min = 860, max = 1500, default = 1100, unit = "us", help = "@i18n(api.RC_CONFIG.rc_min_throttle)@"},
    {field = "rc_max_throttle", type = "U16", apiVersion = {12, 0, 6}, simResponse = {208, 7}, min = 1510, max = 2150, default = 1900, unit = "us", help = "@i18n(api.RC_CONFIG.rc_max_throttle)@"},
    {field = "rc_deadband", type = "U8", apiVersion = {12, 0, 6}, simResponse = {4}, min = 0, max = 100, default = 2, unit = "us", help = "@i18n(api.RC_CONFIG.rc_deadband)@"},
    {field = "rc_yaw_deadband", type = "U8", apiVersion = {12, 0, 6}, simResponse = {4}, min = 0, max = 100, default = 2, unit = "us", help = "@i18n(api.RC_CONFIG.rc_yaw_deadband)@"},
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
