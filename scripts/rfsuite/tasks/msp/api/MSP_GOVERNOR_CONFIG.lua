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
		command = 142, -- MSP_GOVERNOR_CONFIG
		processReply = function(self, buf)
			if #buf >= 24 then 
				mspData = buf
			end
		end,
		simulatorResponse = {3, 100, 0, 100, 0, 20, 0, 20, 0, 30, 0, 10, 0, 0, 0, 0, 0, 50, 0, 10, 5, 10, 0, 10}
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

local function getMode()
	if mspData then
		local mode = rfsuite.bg.msp.mspHelper.readU8(mspData)
		return mode
	end
end

return {
	isReady = isReady,
	get = get,
	set = set,
    data = data,
	getMode = getMode,
	isSet = isSet,
}
