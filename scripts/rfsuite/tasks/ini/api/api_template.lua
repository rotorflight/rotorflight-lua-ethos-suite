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
local rfsuite = require("rfsuite")

--[[
This is an example of the api structure for an INI file API.

The code in the api translates to:

[TEST_API]
pitch = 50
roll = 100

The fields for min,max,unit etc are uses by the forms library to set then
constraints on the fields in the form.

]]--

local API_NAME  = "TEST_API"

-- Define your structure once:
local API_STRUCTURE = {
  { field = "pitch", min = -300, max = 300, default = 0, unit = "°" },
  { field = "roll",  min = -300, max = 300, default = 0, unit = "°" },
}


return {
  API_STRUCTURE = API_STRUCTURE,
}