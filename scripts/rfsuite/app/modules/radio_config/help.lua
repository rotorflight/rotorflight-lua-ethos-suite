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
        "Configure your radio settings. Stick center, arm, throttle hold, and throttle cut.",
}

data['fields'] = {
    radioCenter = {t = "Stick center in microseconds (us)."},
    radioDeflection = {t = "Stick deflection from center in microseconds (us)."},
    radioArmThrottle = {t = "Throttle must be at or below this value in microseconds (us) to allow arming. Must be at least 10us lower than minimum throttle."},
    radioMinThrottle = {t = "Minimum throttle (0% throttle output) expected from radio, in microseconds (us)."},
    radioMaxThrottle = {t = "Maximum throttle (100% throttle output) expected from radio, in microseconds (us)."},
    radioCycDeadband = {t = "Deadband for cyclic control in microseconds (us)."},
    radioYawDeadband = {t = "Deadband for yaw control in microseconds (us)."},
}

return data
