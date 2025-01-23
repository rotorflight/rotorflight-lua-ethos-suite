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

local mspData

local function set()
	-- we still need to do this
end

local function get()

	local message = {
		command = 120, -- MSP_SERVO_CONFIGURATIONS
		processReply = function(self, buf)
			if #buf >= 20 then
				mspData = buf
			end
		end,
		simulatorResponse = {4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0}
	}

	rfsuite.bg.msp.mspQueue:add(message)
end

local function data(data)
	if mspData then
		return mspData
	end
end

local function isReady()
	if mspData then
		return true
	end
	return false
end

local function isSet()
	-- to be implemented
	return true
end

local function getServoCount()
	if mspData then
		local servoCount = rfsuite.bg.msp.mspHelper.readU8(mspData)
		return servoCount
	end
end


return {
	isReady = isReady,
	get = get,
	set = set,
    data = data,
	getServoCount = getServoCount,
	isSet = isSet,
}
