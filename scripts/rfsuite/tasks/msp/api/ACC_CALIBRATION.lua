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
local function set(callback, callbackParam)
    local message = {
        command = 205, -- MSP_ACC_CALIBRATION
        processReply = function(self, buf)
            if callback then callback(callbackParam) end
        end,
        simulatorResponse = {}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

local function get(callback, callbackParam)
	return nil
end

local function data(data)
	return nil
end

return {
	get = get,
	set = set,
    data = data,
}
