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

data['help']['default'] = {"Configure parameters related to your battery setup.", "These settings are used to calculate your fuel capacity."}

data['fields'] = {
--    vbatmaxcellvoltage = {help = "Maximum voltage each cell can be charged to."},
--    vbatfullcellvoltage = {help = "The nomimal voltage of a fully charged cell."},
--    vbatwarningcellvoltage = {help = "The voltage per cell when we trigger an alarm."},
--    vbatmincellvoltage = {help = "The minimum voltage a cell is safe to discharge to."},
--    batteryCapacity = {help = "The milliamp hour capacity of your battery."},
--    batteryCellCounhelp = {help = "The number of cells in your battery pack."}
}

return data
