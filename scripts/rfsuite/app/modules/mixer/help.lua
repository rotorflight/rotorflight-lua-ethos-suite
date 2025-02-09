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
    mixerTTAPrecomp = {t = "Mixer precomp for 0 yaw."}, -- ??? this is not named well in any of the RF LUAs
    mixerCollectiveGeoCorrection = {t = "Adjust if there is too much negative collective or too much positive collective."},
    mixerTotalPitchLimit = {t = "Maximum amount of combined cyclic and collective blade pitch."},
    mixerSwashPhase = {t = "Phase offset for the swashplate controls."},
    mixerTailMotorIdle = {t = "Minimum throttle signal sent to the tail motor. This should be set just high enough that the motor does not stop."},
    collectiveTiltCorrection = {t = "Adjust the collective tilt correction scaling for postive or negative collective pitch."}
    
}

return data
