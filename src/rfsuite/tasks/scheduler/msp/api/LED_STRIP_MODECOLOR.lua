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

local API_NAME = "LED_STRIP_MODECOLOR"
local MSP_API_CMD_READ = 127
local MSP_API_CMD_WRITE = 221
local MSP_REBUILD_ON_WRITE = true
local MODE_COUNT = 4
local DIRECTION_COUNT = 6
local SPECIAL_COLOR_COUNT = 11

local MSP_API_STRUCTURE_READ_DATA = {}
for mode = 0, MODE_COUNT - 1 do
    for direction = 0, DIRECTION_COUNT - 1 do
        local idx = (mode * DIRECTION_COUNT) + direction + 1
        MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "mode_" .. idx, type = "U8", apiVersion = {12, 0, 6}, simResponse = {mode} }
        MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "fun_" .. idx,  type = "U8", apiVersion = {12, 0, 6}, simResponse = {direction} }
        MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "color_" .. idx,type = "U8", apiVersion = {12, 0, 6}, simResponse = {0} }
    end
end
for j = 0, SPECIAL_COLOR_COUNT - 1 do
    local idx = (MODE_COUNT * DIRECTION_COUNT) + j + 1
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "mode_" .. idx, type = "U8", apiVersion = {12, 0, 6}, simResponse = {MODE_COUNT} }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "fun_" .. idx,  type = "U8", apiVersion = {12, 0, 6}, simResponse = {j} }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "color_" .. idx,type = "U8", apiVersion = {12, 0, 6}, simResponse = {0} }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "aux_mode",  type = "U8", apiVersion = {12, 0, 6}, simResponse = {255} }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "aux_fun",   type = "U8", apiVersion = {12, 0, 6}, simResponse = {0} }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "aux_color", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0} }

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "mode",  type = "U8" },
    { field = "fun",   type = "U8" },
    { field = "color", type = "U8" },
}

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
    writeRequiresStructure = true,
    writeUuidFallback = true,
    initialRebuildOnWrite = (MSP_REBUILD_ON_WRITE == true),
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
