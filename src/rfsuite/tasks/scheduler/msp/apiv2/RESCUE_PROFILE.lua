--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicorev2) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/core.lua"))()
if msp and not msp.apicorev2 then
    msp.apicorev2 = core
end

local API_NAME = "RESCUE_PROFILE"
local MSP_API_CMD_READ = 146
local MSP_API_CMD_WRITE = 147

local TBL_RESCUE_MODE = {
    [0] = "@i18n(api.RESCUE_PROFILE.tbl_off)@",
    "@i18n(api.RESCUE_PROFILE.tbl_on)@"
}

local TBL_RESCUE_FLIP = {
    [0] = "@i18n(api.RESCUE_PROFILE.tbl_noflip)@",
    "@i18n(api.RESCUE_PROFILE.tbl_flip)@"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"rescue_mode", "U8", 0, 1, 0, nil, nil, nil, nil, TBL_RESCUE_MODE},
    {"rescue_flip_mode", "U8", 0, 1, 0, nil, nil, nil, nil, TBL_RESCUE_FLIP},
    {"rescue_flip_gain", "U8", 5, 250, 200},
    {"rescue_level_gain", "U8", 5, 250, 100},
    {"rescue_pull_up_time", "U8", 0, 250, 0.3, "s", 1, 10},
    {"rescue_climb_time", "U8", 0, 250, 1, "s", 1, 10},
    {"rescue_flip_time", "U8", 0, 250, 2, "s", 1, 10},
    {"rescue_exit_time", "U8", 0, 250, 0.5, "s", 1, 10},
    {"rescue_pull_up_collective", "U16", 0, 100, 65, "%", nil, 10},
    {"rescue_climb_collective", "U16", 0, 100, 45, "%", nil, 10},
    {"rescue_hover_collective", "U16", 0, 100, 35, "%", nil, 10},
    {"rescue_hover_altitude", "U16", 0, 500, 20, "m"},
    {"rescue_alt_p_gain", "U16", 0, 1000, 20},
    {"rescue_alt_i_gain", "U16", 0, 1000, 20},
    {"rescue_alt_d_gain", "U16", 0, 1000, 10},
    {"rescue_max_collective", "U16", 0, 100, 90, "%", nil, 10},
    {"rescue_max_setpoint_rate", "U16", 5, 1000, 300, "°/s"},
    {"rescue_max_setpoint_accel", "U16", 0, 10000, 3000, "°/s^2"}
}

local SIM_RESPONSE = core.simResponse({
    1,        -- rescue_mode
    0,        -- rescue_flip_mode
    200,      -- rescue_flip_gain
    100,      -- rescue_level_gain
    5,        -- rescue_pull_up_time
    3,        -- rescue_climb_time
    10,       -- rescue_flip_time
    5,        -- rescue_exit_time
    182, 3,   -- rescue_pull_up_collective
    188, 2,   -- rescue_climb_collective
    194, 1,   -- rescue_hover_collective
    244, 1,   -- rescue_hover_altitude
    20, 0,    -- rescue_alt_p_gain
    20, 0,    -- rescue_alt_i_gain
    10, 0,    -- rescue_alt_d_gain
    232, 3,   -- rescue_max_collective
    44, 1,    -- rescue_max_setpoint_rate
    184, 11   -- rescue_max_setpoint_accel
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
