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

local API_NAME = "BOARD_INFO"
local MSP_API_CMD_READ = 4
local MSP_API_CMD_WRITE = 248
local MSP_REBUILD_ON_WRITE = true
local TARGET_NAME_MAX = 32
local BOARD_NAME_MAX = 20
local BOARD_DESIGN_MAX = 12
local MANUFACTURER_ID_MAX = 4

local MSP_API_STRUCTURE_READ_DATA = {
    { field = "board_identifier_1", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {82}, mandatory = false },
    { field = "board_identifier_2", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {70}, mandatory = false },
    { field = "board_identifier_3", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {76}, mandatory = false },
    { field = "board_identifier_4", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {84}, mandatory = false },
    { field = "hardware_revision",  type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, mandatory = false },
    { field = "fc_type",            type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "target_capabilities",type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "target_name_length", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
}
for i = 1, TARGET_NAME_MAX do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "target_name_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "board_name_length", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
for i = 1, BOARD_NAME_MAX do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "board_name_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "board_design_length", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
for i = 1, BOARD_DESIGN_MAX do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "board_design_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "manufacturer_id_length", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
for i = 1, MANUFACTURER_ID_MAX do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "manufacturer_id_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
for i = 1, 32 do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "signature_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "mcu_type_id", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "configuration_state", type = "U8", apiVersion = {12, 42}, simResponse = {0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "gyro_sample_rate_hz", type = "U16", apiVersion = {12, 43}, simResponse = {0, 0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "configuration_problems", type = "U32", apiVersion = {12, 43}, simResponse = {0, 0, 0, 0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "spi_device_count", type = "U8", apiVersion = {12, 44}, simResponse = {0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "i2c_device_count", type = "U8", apiVersion = {12, 44}, simResponse = {0}, mandatory = false }

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "board_name_length", type = "U8" },
}
for i = 1, BOARD_NAME_MAX do
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "board_name_" .. i, type = "U8" }
end
MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "board_design_length", type = "U8" }
for i = 1, BOARD_DESIGN_MAX do
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "board_design_" .. i, type = "U8" }
end
MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "manufacturer_id_length", type = "U8" }
for i = 1, MANUFACTURER_ID_MAX do
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "manufacturer_id_" .. i, type = "U8" }
end

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
