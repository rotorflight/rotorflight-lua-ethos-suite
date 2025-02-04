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
    { field = "governor_headspeed", type = "U16" },
    { field = "governor_gain", type = "U8" },
    { field = "governor_p_gain", type = "U8" },
    { field = "governor_i_gain", type = "U8" },
    { field = "governor_d_gain", type = "U8" },
    { field = "governor_f_gain", type = "U8" },
    { field = "governor_tta_gain", type = "U8" },
    { field = "governor_tta_limit", type = "U8" },
    { field = "governor_yaw_ff_weight", type = "U8" },
    { field = "governor_cyclic_ff_weight", type = "U8" },
    { field = "governor_collective_ff_weight", type = "U8" },
    { field = "governor_max_throttle", type = "U8" },
    { field = "governor_min_throttle", type = "U8" },
}

-- Export the shared MSP API structure
return {
    MSP_API_STRUCTURE = MSP_API_STRUCTURE
}