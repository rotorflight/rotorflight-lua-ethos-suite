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

local API_NAME = "EXPERIMENTAL"
local MSP_API_CMD_READ = 158
local MSP_API_CMD_WRITE = 159
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "exp_uint1",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {255}, help = "@i18n(api.EXPERIMENTAL.exp_uint1)@"},
    {field = "exp_uint2",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {10},  help = "@i18n(api.EXPERIMENTAL.exp_uint2)@"},
    {field = "exp_uint3",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {60},  help = "@i18n(api.EXPERIMENTAL.exp_uint3)@"},
    {field = "exp_uint4",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {200}, help = "@i18n(api.EXPERIMENTAL.exp_uint4)@"},
    {field = "exp_uint5",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {20},  help = "@i18n(api.EXPERIMENTAL.exp_uint5)@"},
    {field = "exp_uint6",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {255}, help = "@i18n(api.EXPERIMENTAL.exp_uint6)@"},
    {field = "exp_uint7",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {6},   help = "@i18n(api.EXPERIMENTAL.exp_uint7)@"},
    {field = "exp_uint8",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {10},  help = "@i18n(api.EXPERIMENTAL.exp_uint8)@"},
    {field = "exp_uint9",  mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {20},  help = "@i18n(api.EXPERIMENTAL.exp_uint9)@"},
    {field = "exp_uint10", mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {40},  help = "@i18n(api.EXPERIMENTAL.exp_uint10)@"},
    {field = "exp_uint11", mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {255}, help = "@i18n(api.EXPERIMENTAL.exp_uint11)@"},
    {field = "exp_uint12", mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {6},   help = "@i18n(api.EXPERIMENTAL.exp_uint12)@"},
    {field = "exp_uint13", mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {10},  help = "@i18n(api.EXPERIMENTAL.exp_uint13)@"},
    {field = "exp_uint14", mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {20},  help = "@i18n(api.EXPERIMENTAL.exp_uint14)@"},
    {field = "exp_uint15", mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {20},  help = "@i18n(api.EXPERIMENTAL.exp_uint15)@"},
    {field = "exp_uint16", mandatory = false, type = "U8", apiVersion = {12, 0, 7}, simResponse = {20},  help = "@i18n(api.EXPERIMENTAL.exp_uint16)@"}
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
