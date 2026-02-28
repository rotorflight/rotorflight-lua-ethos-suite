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

local API_NAME = "LED_STRIP_SETTINGS"
local MSP_API_CMD_READ = 150
local MSP_API_CMD_WRITE = 151
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "ledstrip_beacon_armed_only",   type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "ledstrip_beacon_color",        type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "ledstrip_beacon_percent",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {50} },
    { field = "ledstrip_beacon_period_ms",    type = "U16", apiVersion = {12, 0, 6}, simResponse = {232, 3} },
    { field = "ledstrip_blink_period_ms",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {232, 3} },
    { field = "ledstrip_brightness",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {100} },
    { field = "ledstrip_fade_rate",           type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "ledstrip_flicker_rate",        type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "ledstrip_grb_rgb",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "ledstrip_profile",             type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "ledstrip_race_color",          type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "ledstrip_visual_beeper",       type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "ledstrip_visual_beeper_color", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
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
