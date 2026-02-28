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

local API_NAME = "OSD_CONFIG"
local MSP_API_CMD_READ = 84
local MSP_API_CMD_WRITE = 85
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "osd_flags",       type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "video_system",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "units",           type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "rssi_alarm",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "cap_alarm",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, mandatory = false },
    { field = "legacy_timer_lo", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "legacy_timer_hi", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "alt_alarm",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, mandatory = false },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "addr",              type = "U8"  }, -- 255 for general settings
    { field = "video_system",      type = "U8"  },
    { field = "units",             type = "U8"  },
    { field = "rssi_alarm",        type = "U8"  },
    { field = "cap_alarm",         type = "U16" },
    { field = "legacy_timer",      type = "U16" },
    { field = "alt_alarm",         type = "U16" },
    { field = "enabled_warnings_16", type = "U16" },
    { field = "enabled_warnings_32", type = "U32" },
    { field = "osd_profile_index", type = "U8"  },
    { field = "overlay_radio_mode",type = "U8"  },
    { field = "camera_frame_width",type = "U8"  },
    { field = "camera_frame_height",type = "U8" },
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
    writeUuidFallback = true,
    initialRebuildOnWrite = (MSP_REBUILD_ON_WRITE == true),
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end,
    exports = {
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
    }
})
