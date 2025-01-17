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
local arg = {...}

local config = arg[1]

local msp_poll = {}


function msp_poll.wakeup()

	local message = {
		command = 1, -- MIXER
		processReply = function(self, buf)
			if #buf >= 3 then
				local version = buf[2] + buf[3] / 100
				print("MSP Version: " .. rfsuite.config.apiVersion)
				system.playTone(4000,1)
			end
		end,
		simulatorResponse = rfsuite.config.simulatorApiVersionResponse
	}
	rfsuite.bg.msp.mspQueue:add(message)


end

return msp_poll
