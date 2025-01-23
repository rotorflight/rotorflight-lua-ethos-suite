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
		command = 246, -- MSP_SET_RTC
		payload = {},
		processReply = function(self, buf)
			rfsuite.utils.log("RTC set.")
			if callback then callback(callbackParam) end
		end,
		simulatorResponse = {}
	}

	-- generate message to send
	local now = os.time()
	-- format: seconds after the epoch / milliseconds
	for i = 1, 4 do
		rfsuite.bg.msp.mspHelper.writeU8(message.payload, now & 0xFF)
		now = now >> 8
	end
	rfsuite.bg.msp.mspHelper.writeU16(message.payload, 0)

	-- add msg to queue
	rfsuite.bg.msp.mspQueue:add(message)
end

local function get(callback, callbackParam)
	return nil
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
return {
	get = get,
	set = set,
    data = data,
	isReady = isReady
}
