--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note. Some icons have been sourced from https://www.flaticon.com/
]] --

local MSP_API_STRUCTURE = {
    { field = "pid_mode", type = "U8" },
    { field = "error_decay_time_ground", type = "U8" },
    { field = "error_decay_time_cyclic", type = "U8" },
    { field = "error_decay_time_yaw", type = "U8" },
    { field = "error_decay_limit_cyclic", type = "U8" },
    { field = "error_decay_limit_yaw", type = "U8" },
    { field = "error_rotation", type = "U8" },
    { field = "error_limit_0", type = "U8" },
    { field = "error_limit_1", type = "U8" },
    { field = "error_limit_2", type = "U8" },
    { field = "gyro_cutoff_0", type = "U8" },
    { field = "gyro_cutoff_1", type = "U8" },
    { field = "gyro_cutoff_2", type = "U8" },
    { field = "dterm_cutoff_0", type = "U8" },
    { field = "dterm_cutoff_1", type = "U8" },
    { field = "dterm_cutoff_2", type = "U8" },
    { field = "iterm_relax_type", type = "U8" },
    { field = "iterm_relax_cutoff_0", type = "U8" },
    { field = "iterm_relax_cutoff_1", type = "U8" },
    { field = "iterm_relax_cutoff_2", type = "U8" },
    { field = "yaw_cw_stop_gain", type = "U8" },
    { field = "yaw_ccw_stop_gain", type = "U8" },
    { field = "yaw_precomp_cutoff", type = "U8" },
    { field = "yaw_cyclic_ff_gain", type = "U8" },
    { field = "yaw_collective_ff_gain", type = "U8" },
    { field = "yaw_collective_dynamic_gain", type = "U8" }, 
    { field = "yaw_collective_dynamic_decay", type = "U8" }, 
    { field = "pitch_collective_ff_gain", type = "U8" },
    { field = "angle_level_strength", type = "U8" },
    { field = "angle_level_limit", type = "U8" },
    { field = "horizon_level_strength", type = "U8" },
    { field = "trainer_gain", type = "U8" },
    { field = "trainer_angle_limit", type = "U8" },
    { field = "cyclic_cross_coupling_gain", type = "U8" },
    { field = "cyclic_cross_coupling_ratio", type = "U8" },
    { field = "cyclic_cross_coupling_cutoff", type = "U8" },
    { field = "offset_limit_0", type = "U8" },
    { field = "offset_limit_1", type = "U8" },
    { field = "bterm_cutoff_0", type = "U8" },
    { field = "bterm_cutoff_1", type = "U8" },
    { field = "bterm_cutoff_2", type = "U8" },
    { field = "yaw_inertia_precomp_gain", type = "U8" },
    { field = "yaw_inertia_precomp_cutoff", type = "U8" },
}

-- Export the shared MSP API structure
return {
    MSP_API_STRUCTURE = MSP_API_STRUCTURE
}