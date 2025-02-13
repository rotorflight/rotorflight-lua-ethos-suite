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

data['help']['default'] = {"Configure your radio settings. Stick center, arm, throttle hold, and throttle cut."}

data['fields'] = {
    rc_center = {t = "Stick center in microseconds (us)."},
    rc_deflection = {t = "Stick deflection from center in microseconds (us)."},
    rc_arm_throttle = {t = "Throttle must be at or below this value in microseconds (us) to allow arming. Must be at least 10us lower than minimum throttle."},
    rc_min_throttle = {t = "Minimum throttle (0% throttle output) expected from radio, in microseconds (us)."},
    rc_max_throttle = {t = "Maximum throttle (100% throttle output) expected from radio, in microseconds (us)."},
    rc_deadband = {t = "Deadband for cyclic control in microseconds (us)."},
    rc_yaw_deadband = {t = "Deadband for yaw control in microseconds (us)."}
}

return data
