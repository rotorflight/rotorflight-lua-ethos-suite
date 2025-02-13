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

data['help']['default'] = {"These parameters apply globally to the governor regardless of the profile in use.", "Each parameter is simply a time value in seconds for each governor action."}

data['fields'] = {
    gov_handover_throttle = {t = "Governor activates above this %. Below this the input throttle is passed to the ESC."},
    gov_startup_time = {t = "Time constant for slow startup, in seconds, measuring the time from zero to full headspeed."},
    gov_spoolup_time = {t = "Time constant for slow spoolup, in seconds, measuring the time from zero to full headspeed."},
    gov_tracking_time = {t = "Time constant for headspeed changes, in seconds, measuring the time from zero to full headspeed."},
    gov_recovery_time = {t = "Time constant for recovery spoolup, in seconds, measuring the time from zero to full headspeed."},
    gov_spoolup_min_throttle = {t = "Minimum throttle to use for slow spoolup, in percent. For electric motors the default is 5%, for nitro this should be set so the clutch starts to engage for a smooth spoolup 10-15%."}
}

return data
