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

data['help']['default'] = {"Error decay ground: PID decay to help prevent heli from tipping over when on the ground.", "Error limit: Angle limit for I-term.", "Offset limit: Angle limit for High Speed Integral (O-term).", "Error rotation: Allow errors to be shared between all axes.",
                           "I-term relax: Limit accumulation of I-term during fast movements - helps reduce bounce back after fast stick movements. Generally needs to be lower for large helis and can be higher for small helis. Best to only reduce as much as is needed for your flying style."}

data['fields'] = {}

return data
