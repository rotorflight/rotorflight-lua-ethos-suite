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

data['help']['default'] = {"Configure your motor gear ratio, motor pole count, and throttle PWM values."}

data['fields'] = {
    minthrottle = {t = "This PWM value is sent to the ESC/Servo at low throttle"},
    maxthrottle = {t = "This PWM value is sent to the ESC/Servo at full throttle"},
    mincommand = {t = "This PWM value is sent when the motor is stopped"},
    motor_pole_count_0 = {t = "The number of magnets on the motor bell."},
    main_rotor_gear_ratio_0 = {t = "Motor Pinion Gear Tooth Count"},
    main_rotor_gear_ratio_1 = {t = "Main Gear Tooth Count"},
    tail_rotor_gear_ratio_0 = {t = "Tail Gear Tooth Count"},
    tail_rotor_gear_ratio_1 = {t = "Autorotation Gear Tooth Count"}
}

return data
