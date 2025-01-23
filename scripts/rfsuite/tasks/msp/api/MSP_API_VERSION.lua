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

local function set(callback, callbackParam)
	-- this is a read only command so nothing to do here
end

local function get()
	local message = {
		command = 1, -- MIXER
		processReply = function(self, buf)
			if #buf >= 3 then
				mspData = buf
			end			
		end,
		simulatorResponse = rfsuite.config.simulatorApiVersionResponse
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

local function getVersion()
	if mspData then
		local version = mspData[2] + mspData[3] / 100
		return version
	end
end

return {
	get = get,
	set = set,
    data = data,
	isReady = isReady,
	getVersion = getVersion
}
