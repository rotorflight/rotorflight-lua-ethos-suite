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

data['help']['default'] = {"@i18n(app.modules.rates.help_default_p1)@","@i18n(app.modules.rates.help_default_p2)@"}

-- Rates is a bit of an odd-ball because we show different help based one
-- the rate table selected.  This info is supplied below.

data["help"]["table"] = {}

-- RATE TABLE NONE
data["help"]["table"][0] = {"@i18n(app.modules.rates.help_table_0_p1)@"}

-- RATE TABLE BETAFLIGHT
data["help"]["table"][1] = {"@i18n(app.modules.rates.help_table_1_p1)@", "@i18n(app.modules.rates.help_table_1_p2)@", "@i18n(app.modules.rates.help_table_1_p3)@"}

-- RATE TABLE RACEFLIGHT
data["help"]["table"][2] = {"@i18n(app.modules.rates.help_table_2_p1)@", "@i18n(app.modules.rates.help_table_2_p2)@", "@i18n(app.modules.rates.help_table_2_p3)@"}

-- RATE TABLE KISS
data["help"]["table"][3] = {"@i18n(app.modules.rates.help_table_3_p1)@", "@i18n(app.modules.rates.help_table_3_p2)@", "@i18n(app.modules.rates.help_table_3_p3)@"}

-- RATE TABLE ACTUAL
data["help"]["table"][4] = {"@i18n(app.modules.rates.help_table_4_p1)@", "@i18n(app.modules.rates.help_table_4_p2)@", "@i18n(app.modules.rates.help_table_4_p3)@"}

-- RATE TABLE QUICK
data["help"]["table"][5] = {"@i18n(app.modules.rates.help_table_5_p1)@", "@i18n(app.modules.rates.help_table_5_p2)@", "@i18n(app.modules.rates.help_table_5_p3)@"}

return data
