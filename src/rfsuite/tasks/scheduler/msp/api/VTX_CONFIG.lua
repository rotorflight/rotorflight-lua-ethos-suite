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

local API_NAME = "VTX_CONFIG"
local MSP_API_CMD_READ = 88
local MSP_API_CMD_WRITE = 89
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "device_type",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "band",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "channel",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "power",            type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "pit_mode",         type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "freq",             type = "U16", apiVersion = {12, 0, 6}, simResponse = {108, 22} },
    { field = "device_ready",     type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "low_power_disarm", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "pit_mode_freq",    type = "U16", apiVersion = {12, 42}, simResponse = {0, 0} },
    { field = "vtxtable_available", type = "U8", apiVersion = {12, 42}, simResponse = {1} },
    { field = "vtxtable_bands",   type = "U8",  apiVersion = {12, 42}, simResponse = {5} },
    { field = "vtxtable_channels",type = "U8",  apiVersion = {12, 42}, simResponse = {8} },
    { field = "vtxtable_power_levels", type = "U8", apiVersion = {12, 42}, simResponse = {5} },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "freq_or_bandchan",  type = "U16" },
    { field = "power",             type = "U8"  },
    { field = "pit_mode",          type = "U8"  },
    { field = "low_power_disarm",  type = "U8"  },
    { field = "pit_mode_freq",     type = "U16" },
    { field = "band",              type = "U8"  },
    { field = "channel",           type = "U8"  },
    { field = "freq",              type = "U16" },
    { field = "vtxtable_bands",    type = "U8"  },
    { field = "vtxtable_channels", type = "U8"  },
    { field = "vtxtable_power_levels", type = "U8" },
    { field = "vtxtable_clear",    type = "U8"  },
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
