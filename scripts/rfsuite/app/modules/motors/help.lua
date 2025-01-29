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
        "Configure your motor gear ratio, motor pole count, and throttle PWM values.",
}

data['fields'] = {
    motorMinThrottle = {t = "This PWM value is sent to the ESC/Servo at low throttle"},
    motorMaxThrottle = {t = "This PWM value is sent to the ESC/Servo at full throttle"},
    motorMinCommand = {t = "This PWM value is sent when the motor is stopped"},
    motorPollCount = {t = "The number of magnets on the motor bell."},
    motorGearRatioPinion = {t = "Motor Pinion Gear Tooth Count"},
    motorGearRatioMain = {t = "Main Gear Tooth Count"},
    motorGearRatioTailRear = {t = "Tail Gear Tooth Count"},
    motorGearRatioTailFront = {t = "Autorotation Gear Tooth Count"},
}

return data
