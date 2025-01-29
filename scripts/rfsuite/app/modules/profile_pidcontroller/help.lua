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

data['help']['default'] = {
        "Error decay ground: PID decay to help prevent heli from tipping over when on the ground.", 
        "Error limit: Angle limit for I-term.", "Offset limit: Angle limit for High Speed Integral (O-term).",
        "Error rotation: Allow errors to be shared between all axes.",
        "I-term relax: Limit accumulation of I-term during fast movements - helps reduce bounce back after fast stick movements. Generally needs to be lower for large helis and can be higher for small helis. Best to only reduce as much as is needed for your flying style."
}

data['fields'] = {
    profilesErrorDecayGround = {t = "Bleeds off the current controller error when the craft is not airborne to stop the craft tipping over."},
    profilesErrorDecayGroundCyclicTime = {t = "Time constant for bleeding off cyclic I-term. Higher will stabilize hover, lower will drift."},
    profilesErrorDecayGroundCyclicLimit = {t = "Maximum bleed-off speed for cyclic I-term."},
    profilesErrorDecayGroundYawTime = {t = "Time constant for bleeding off yaw I-term."},
    profilesErrorDecayGroundYawLimit = {t = "Maximum bleed-off speed for yaw I-term."},
    profilesErrorLimit = {t = "Hard limit for the angle error in the PID loop. The absolute error and thus the I-term will never go above these limits."},
    profilesErrorHSIOffsetLimit = {t = "Hard limit for the High Speed Integral offset angle in the PID loop. The O-term will never go over these limits."},
    profilesErrorRotation = {t = "Rotates the current roll and pitch error terms around taw when the craft rotates. This is sometimes called Piro Compensation."},
    profilesItermRelaxType = {t = "Choose the axes in which this is active. RP: Roll, Pitch. RPY: Roll, Pitch, Yaw."},
    profilesItermRelax = {t = "Helps reduce bounce back after fast stick movements. Can cause inconsistency in small stick movements if too low."},
}

return data
