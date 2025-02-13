--[[
 * Copyright (C) Rotorflight Project
 *
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
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local data = {}

data['help'] = {}

data['help']['default'] = {"Adust swash plate geometry, phase angles, and limits."}

data['fields'] = {
    swash_tta_precomp = {t = "Mixer precomp for 0 yaw."}, 
    swash_geo_correction = {t = "Adjust if there is too much negative collective or too much positive collective."},
    swash_pitch_limit = {t = "Maximum amount of combined cyclic and collective blade pitch."},
    swash_phase = {t = "Phase offset for the swashplate controls."},
    tail_motor_idle = {t = "Minimum throttle signal sent to the tail motor. This should be set just high enough that the motor does not stop."},
    collective_tilt_correction_pos = {t = "Adjust the collective tilt correction scaling for postive or negative collective pitch."},
    collective_tilt_correction_neg = {t = "Adjust the collective tilt correction scaling for postive or negative collective pitch."}
}

return data
