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
        "Please select the servo you would like to configure from the list below.", "Primary flight controls that use the rotoflight mixer will display in the section called 'mixer",
        "Any other servos that are not controlled by the primary flight mixer will be displayed in the section called 'Other servos'.",		
}

data['help']['servos_tool'] = {
        "Override: [*]  Enable override to allow real time updates of servo center point.", 
        "Center: Adjust the center position of the servo.",
        "Minimum/Maximum: Adjust the end points of the selected servo.", 
        "Scale: Adjust the amount the servo moves for a given input.",
        "Rate: The frequency the servo runs best at - check with manufacturer.",
        "Speed: The speed the servo moves. Generally only used for the cyclic servos to help the swash move evenly. Optional - leave all at 0 if unsure."
}

data['fields'] = {
    servoMid = {t = "Servo center position pulse width."},
    servoMin = {t = "Servo negative travel limit."},
    servoMax = {t = "Servo positive travel limit."},
    servoScaleNeg = {t = "Servo negative scaling."},
    servoScalePos = {t = "Servo positive scaling."},
    servoRate = {t = "Servo PWM rate."},
    servoSpeed = {t = "Servo motion speed in milliseconds."},
    servoFlags = {t = "0 = Default, 1=Reverse, 2 = Geo Correction, 3 = Reverse + Geo Correction"},
}

return data
