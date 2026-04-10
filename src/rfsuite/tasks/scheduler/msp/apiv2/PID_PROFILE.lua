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

local API_NAME = "PID_PROFILE"
local MSP_API_CMD_READ = 94
local MSP_API_CMD_WRITE = 95

local TBL_OFF_ON = {[0] = "@i18n(api.PID_PROFILE.tbl_off)@", "@i18n(api.PID_PROFILE.tbl_on)@"}
local TBL_ITERM_RELAX = {
    [0] = "@i18n(api.PID_PROFILE.tbl_off)@",
    "@i18n(api.PID_PROFILE.tbl_rp)@",
    "@i18n(api.PID_PROFILE.tbl_rpy)@"
}

-- Tuple layout:
--   field, type, api major, api minor, api revision, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"pid_mode", "U8", 12, 0, 6},
    {"error_decay_time_ground", "U8", 12, 0, 6, 0, 250, 2.5, "s", 1, 10},
    {"error_decay_time_cyclic", "U8", 12, 0, 6, 0, 250, 25, "s", 1, 10},
    {"error_decay_time_yaw", "U8", 12, 0, 6},
    {"error_decay_limit_cyclic", "U8", 12, 0, 6, 0, 25, 12, "°"},
    {"error_decay_limit_yaw", "U8", 12, 0, 6},
    {"error_rotation", "U8", 12, 0, 6, 0, 1, nil, nil, nil, nil, nil, nil, TBL_OFF_ON},
    {"error_limit_0", "U8", 12, 0, 6, 0, 180, 45, "°"},
    {"error_limit_1", "U8", 12, 0, 6, 0, 180, 45, "°"},
    {"error_limit_2", "U8", 12, 0, 6, 0, 180, 60, "°"},
    {"gyro_cutoff_0", "U8", 12, 0, 6, 0, 250, 50},
    {"gyro_cutoff_1", "U8", 12, 0, 6, 0, 250, 50},
    {"gyro_cutoff_2", "U8", 12, 0, 6, 0, 250, 100},
    {"dterm_cutoff_0", "U8", 12, 0, 6, 0, 250, 15},
    {"dterm_cutoff_1", "U8", 12, 0, 6, 0, 250, 15},
    {"dterm_cutoff_2", "U8", 12, 0, 6, 0, 250, 20},
    {"iterm_relax_type", "U8", 12, 0, 6, 0, 2, nil, nil, nil, nil, nil, nil, TBL_ITERM_RELAX},
    {"iterm_relax_cutoff_0", "U8", 12, 0, 6, 1, 100, 10},
    {"iterm_relax_cutoff_1", "U8", 12, 0, 6, 1, 100, 10},
    {"iterm_relax_cutoff_2", "U8", 12, 0, 6, 1, 100, 10},
    {"yaw_cw_stop_gain", "U8", 12, 0, 6, 25, 250, 120},
    {"yaw_ccw_stop_gain", "U8", 12, 0, 6, 25, 250, 80},
    {"yaw_precomp_cutoff", "U8", 12, 0, 6, 0, 250, 5, "Hz"},
    {"yaw_cyclic_ff_gain", "U8", 12, 0, 6, 0, 250, 0},
    {"yaw_collective_ff_gain", "U8", 12, 0, 6, 0, 250, 30},
    {"yaw_collective_dynamic_gain", "U8", 12, 0, 6, 0, 125, 0},
    {"yaw_collective_dynamic_decay", "U8", 12, 0, 6, 0, 250, 25, "s"},
    {"pitch_collective_ff_gain", "U8", 12, 0, 6, 0, 250, 0},
    {"angle_level_strength", "U8", 12, 0, 6, 0, 200, 40},
    {"angle_level_limit", "U8", 12, 0, 6, 10, 90, 55, "°"},
    {"horizon_level_strength", "U8", 12, 0, 6, 0, 200, 40},
    {"trainer_gain", "U8", 12, 0, 6, 25, 255, 75},
    {"trainer_angle_limit", "U8", 12, 0, 6, 10, 80, 20, "°"},
    {"cyclic_cross_coupling_gain", "U8", 12, 0, 6, 0, 250, 50},
    {"cyclic_cross_coupling_ratio", "U8", 12, 0, 6, 0, 200, 0, "%"},
    {"cyclic_cross_coupling_cutoff", "U8", 12, 0, 6, 1, 250, 2.5, "Hz", 1, 10},
    {"offset_limit_0", "U8", 12, 0, 6, 0, 180, 90, "°"},
    {"offset_limit_1", "U8", 12, 0, 6, 0, 180, 90, "°"},
    {"bterm_cutoff_0", "U8", 12, 0, 6, 0, 250, 15},
    {"bterm_cutoff_1", "U8", 12, 0, 6, 0, 250, 15},
    {"bterm_cutoff_2", "U8", 12, 0, 6, 0, 250, 20},
    {"yaw_inertia_precomp_gain", "U8", 12, 0, 8, 0, 250, 0},
    {"yaw_inertia_precomp_cutoff", "U8", 12, 0, 8, 0, 250, 2.5, "Hz", 1, 10}
}

local SIM_RESPONSE = core.simResponse({
    3,    -- pid_mode
    25,   -- error_decay_time_ground
    250,  -- error_decay_time_cyclic
    0,    -- error_decay_time_yaw
    12,   -- error_decay_limit_cyclic
    0,    -- error_decay_limit_yaw
    1,    -- error_rotation
    45,   -- error_limit_0
    45,   -- error_limit_1
    60,   -- error_limit_2
    50,   -- gyro_cutoff_0
    50,   -- gyro_cutoff_1
    100,  -- gyro_cutoff_2
    15,   -- dterm_cutoff_0
    15,   -- dterm_cutoff_1
    20,   -- dterm_cutoff_2
    2,    -- iterm_relax_type
    10,   -- iterm_relax_cutoff_0
    10,   -- iterm_relax_cutoff_1
    15,   -- iterm_relax_cutoff_2
    100,  -- yaw_cw_stop_gain
    100,  -- yaw_ccw_stop_gain
    6,    -- yaw_precomp_cutoff
    0,    -- yaw_cyclic_ff_gain
    30,   -- yaw_collective_ff_gain
    0,    -- yaw_collective_dynamic_gain
    0,    -- yaw_collective_dynamic_decay
    0,    -- pitch_collective_ff_gain
    40,   -- angle_level_strength
    55,   -- angle_level_limit
    0,    -- horizon_level_strength
    75,   -- trainer_gain
    20,   -- trainer_angle_limit
    25,   -- cyclic_cross_coupling_gain
    0,    -- cyclic_cross_coupling_ratio
    15,   -- cyclic_cross_coupling_cutoff
    90,   -- offset_limit_0
    90,   -- offset_limit_1
    15,   -- bterm_cutoff_0
    15,   -- bterm_cutoff_1
    20,   -- bterm_cutoff_2
    10,   -- yaw_inertia_precomp_gain
    20    -- yaw_inertia_precomp_cutoff
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true
})
