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
        "Acro Trainer: How aggressively the heli tilts back to level when flying in Acro Trainer Mode.", 
        "Angle Mode: How aggressively the heli tilts back to level when flying in Angle Mode.",
        "Horizon Mode: How aggressively the heli tilts back to level when flying in Horizon Mode."
}

data['fields'] = {
    profilesAcroTrainerGain = {t = "Determines how aggressively the helicopter tilts back to the maximum angle (if exceeded) while in Acro Trainer Mode."},
    profilesAcroTrainerLimit = {t = "Limit the maximum angle the helicopter will pitch/roll to while in Acro Trainer Mode."},
    profilesAngleModeGain = {t = "Determines how aggressively the helicopter tilts back to level while in Angle Mode."},
    profilesAngleModeLimit = {t = "Limit the maximum angle the helicopter will pitch/roll to while in Angle mode."},
    profilesHorizonModeGain = {t = "Determines how aggressively the helicopter tilts back to level while in Horizon Mode."},
}

return data
