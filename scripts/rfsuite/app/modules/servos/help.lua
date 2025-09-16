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

data['help']['default'] = {"@i18n(app.modules.servos.help_default_p1)@","@i18n(app.modules.servos.help_default_p2)@","@i18n(app.modules.servos.help_default_p3)@"}

data['help']['servos_tool'] = {"@i18n(app.modules.servos.help_tool_p1)@","@i18n(app.modules.servos.help_tool_p2)@","@i18n(app.modules.servos.help_tool_p3)@",
"@i18n(app.modules.servos.help_tool_p4)@","@i18n(app.modules.servos.help_tool_p5)@","@i18n(app.modules.servos.help_tool_p6)@"}

data['fields'] = {
    servoMid = {t = "@i18n(app.modules.servos.help_fields_mid)@"},
    servoMin = {t = "@i18n(app.modules.servos.help_fields_min)@"},
    servoMax = {t = "@i18n(app.modules.servos.help_fields_max)@"},
    servoScaleNeg = {t = "@i18n(app.modules.servos.help_fields_scale_neg)@"},
    servoScalePos = {t = "@i18n(app.modules.servos.help_fields_scale_pos)@"},
    servoRate = {t = "@i18n(app.modules.servos.help_fields_rate)@"},
    servoSpeed = {t = "@i18n(app.modules.servos.help_fields_speed)@"},
    servoFlags = {t = "@i18n(app.modules.servos.help_fields_flags)@"}
}

return data
