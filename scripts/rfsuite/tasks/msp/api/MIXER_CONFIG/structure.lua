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


local MSP_API_STRUCTURE = {{field = "main_rotor_dir", type = "U8"},
                           {field = "tail_rotor_mode", type = "U8"},
                           {field = "tail_motor_idle", type = "U8"},
                           {field = "tail_center_trim", type = "U16"},
                           {field = "swash_type", type = "U8"},
                           {field = "swash_ring", type = "U8"},
                           {field = "swash_phase", type = "U16"},
                           {field = "swash_pitch_limit", type = "U16"},
                           {field = "swash_trim_0", type = "S16"},
                           {field = "swash_trim_1", type = "S16"},
                           {field = "swash_trim_2", type = "S16"},
                           {field = "swash_tta_precomp", type = "U8"},
                           {field = "swash_geo_correction", type = "U8"},
                           --{field = "collective_geo_correction_pos", type = "S8"},    -- something odd is going on here. 
                           --{field = "collective_geo_correction_neg", type = "S8"}     -- these values are set; but dont seem to actually get sent in the msp
                        }

-- Export the shared MSP API structure
return {
    MSP_API_STRUCTURE = MSP_API_STRUCTURE
}