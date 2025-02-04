--[[
 * Copyright (C) Rotorflight Project
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
 *
 * Note. Some icons have been sourced from https://www.flaticon.com/
]] --

local MSP_API_STRUCTURE = {
    { field = "rates_type", type = "U8" },
    { field = "rcRates_1", type = "U8" },
    { field = "rcExpo_1", type = "U8" },
    { field = "rates_1", type = "U8" },
    { field = "response_time_1", type = "U8" },
    { field = "accel_limit_1", type = "U16" },
    { field = "rcRates_2", type = "U8" },
    { field = "rcExpo_2", type = "U8" },
    { field = "rates_2", type = "U8" },
    { field = "response_time_2", type = "U8" },
    { field = "accel_limit_2", type = "U16" },
    { field = "rcRates_3", type = "U8" },
    { field = "rcExpo_3", type = "U8" },
    { field = "rates_3", type = "U8" },
    { field = "response_time_3", type = "U8" },
    { field = "accel_limit_3", type = "U16" },
    { field = "rcRates_4", type = "U8" },
    { field = "rcExpo_4", type = "U8" },
    { field = "rates_4", type = "U8" },
    { field = "response_time_4", type = "U8" },
    { field = "accel_limit_4", type = "U16" }
}

-- Export the shared MSP API structure
return {
    MSP_API_STRUCTURE = MSP_API_STRUCTURE
}