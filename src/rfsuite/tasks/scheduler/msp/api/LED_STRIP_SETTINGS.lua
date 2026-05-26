--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local API_NAME = "LED_STRIP_SETTINGS"
local MSP_API_CMD_READ = 150
local MSP_API_CMD_WRITE = 151

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"ledstrip_beacon_armed_only", "U8"},
    {"ledstrip_beacon_color", "U8"},
    {"ledstrip_beacon_percent", "U8"},
    {"ledstrip_beacon_period_ms", "U16"},
    {"ledstrip_blink_period_ms", "U16"},
    {"ledstrip_brightness", "U8"},
    {"ledstrip_fade_rate", "U8"},
    {"ledstrip_flicker_rate", "U8"},
    {"ledstrip_grb_rgb", "U8"},
    {"ledstrip_profile", "U8"},
    {"ledstrip_race_color", "U8"},
    {"ledstrip_visual_beeper", "U8"},
    {"ledstrip_visual_beeper_color", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    0, -- ledstrip_beacon_armed_only
    0, -- ledstrip_beacon_color
    50, -- ledstrip_beacon_percent
    232, 3, -- ledstrip_beacon_period_ms
    232, 3, -- ledstrip_blink_period_ms
    100, -- ledstrip_brightness
    0, -- ledstrip_fade_rate
    0, -- ledstrip_flicker_rate
    0, -- ledstrip_grb_rgb
    0, -- ledstrip_profile
    0, -- ledstrip_race_color
    0, -- ledstrip_visual_beeper
    0  -- ledstrip_visual_beeper_color
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
