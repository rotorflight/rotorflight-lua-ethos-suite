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

local API_NAME = "OSD_CONFIG"
local MSP_API_CMD_READ = 84
local MSP_API_CMD_WRITE = 85
local OPTIONAL = false

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"osd_flags", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"video_system", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"units", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"rssi_alarm", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"cap_alarm", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"legacy_timer_lo", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"legacy_timer_hi", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"alt_alarm", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"addr", "U8"},
    {"video_system", "U8"},
    {"units", "U8"},
    {"rssi_alarm", "U8"},
    {"cap_alarm", "U16"},
    {"legacy_timer", "U16"},
    {"alt_alarm", "U16"},
    {"enabled_warnings_16", "U16"},
    {"enabled_warnings_32", "U32"},
    {"osd_profile_index", "U8"},
    {"overlay_radio_mode", "U8"},
    {"camera_frame_width", "U8"},
    {"camera_frame_height", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    0,    -- osd_flags
    0,    -- video_system
    0,    -- units
    0,    -- rssi_alarm
    0, 0, -- cap_alarm
    0,    -- legacy_timer_lo
    0,    -- legacy_timer_hi
    0, 0  -- alt_alarm
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    initialRebuildOnWrite = true,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
