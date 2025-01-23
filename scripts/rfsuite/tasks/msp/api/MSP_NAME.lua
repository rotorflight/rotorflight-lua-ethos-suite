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
		command = 10, -- MSP_NAME
		processReply = function(self, buf)
				mspData = buf
		end,
		simulatorResponse = {80, 105, 108, 111, 116}
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

local function getName()
	if mspData then

		if #mspData == 0 then
			return "NOT SET"
		end	

		local v = 0
		local craftName = ""
		for idx = 1, #mspData do craftName = craftName .. string.char(mspData[idx]) end
		return craftName
	end
end

return {
	isReady = isReady,
	get = get,
	set = set,
    data = data,
	getName = getName,
	isSet = isSet,
}
