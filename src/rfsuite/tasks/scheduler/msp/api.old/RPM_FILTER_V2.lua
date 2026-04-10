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

local API_NAME = "RPM_FILTER_V2"
local RPM_FILTER_NOTCH_COUNT = 16

local MSP_API_STRUCTURE_READ_DATA = {}
for i = 1, RPM_FILTER_NOTCH_COUNT do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "notch_source_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0} }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "notch_center_" .. i, type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "notch_q_" .. i,      type = "U8", apiVersion = {12, 0, 6}, simResponse = {0} }
end

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "axis", type = "U8" },
}
for i = 1, RPM_FILTER_NOTCH_COUNT do
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "notch_source_" .. i, type = "U8" }
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "notch_center_" .. i, type = "U16" }
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "notch_q_" .. i,      type = "U8" }
end

local function parseRead(buf)
    local result = nil
    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(parsed)
        result = parsed
    end)
    if result == nil then return nil, "parse_failed" end
    return result
end

local function buildReadPayload(payloadData, _, _, _, axis)
    local readAxis = tonumber(axis)
    if readAxis == nil then readAxis = tonumber(payloadData.axis) end
    if readAxis == nil then readAxis = 0 end
    return {readAxis}
end

local function buildWritePayload(payloadData, _, _, state)
    return core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, state.rebuildOnWrite == true)
end

return factory.create({
    name = API_NAME,
    readCmd = 154,
    writeCmd = 155,
    minBytes = MSP_MIN_BYTES,
    readStructure = MSP_API_STRUCTURE_READ,
    writeStructure = MSP_API_STRUCTURE_WRITE,
    simulatorResponseRead = MSP_API_SIMULATOR_RESPONSE,
    parseRead = parseRead,
    buildReadPayload = buildReadPayload,
    buildWritePayload = buildWritePayload,
    writeRequiresStructure = true,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
