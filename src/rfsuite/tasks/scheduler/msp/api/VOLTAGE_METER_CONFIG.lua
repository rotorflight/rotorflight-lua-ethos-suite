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

local API_NAME = "VOLTAGE_METER_CONFIG"
local MSP_API_CMD_READ = 56
local MSP_API_CMD_WRITE = 57
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "meter_count",   type = "U8",  apiVersion = {12, 0, 6}, simResponse = {4} },
    { field = "frame_length_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "meter_id_1",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "meter_type_1",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "scale_1",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "divider_1",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {1, 0} },
    { field = "divmul_1",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "frame_length_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "meter_id_2",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "meter_type_2",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "scale_2",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "divider_2",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {1, 0} },
    { field = "divmul_2",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "frame_length_3", type = "U8", apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "meter_id_3",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {2} },
    { field = "meter_type_3",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "scale_3",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "divider_3",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {1, 0} },
    { field = "divmul_3",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "frame_length_4", type = "U8", apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "meter_id_4",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {3} },
    { field = "meter_type_4",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "scale_4",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "divider_4",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {1, 0} },
    { field = "divmul_4",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "meter_id", type = "U8"  },
    { field = "scale",    type = "U16" },
    { field = "divider",  type = "U16" },
    { field = "divmul",   type = "U8"  },
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
