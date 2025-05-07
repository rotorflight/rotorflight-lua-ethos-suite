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

local clocksync = {}

local syncStartTime = nil

function clocksync.wakeup()
    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.clockSet == nil then
        -- Record the time when the sync attempt starts
        if syncStartTime == nil then
            syncStartTime = os.clock()
        end

        local API = rfsuite.tasks.msp.api.load("RTC", 1)
        API.setCompleteHandler(function(self, buf)
            -- Wait until at least 1 second has passed since syncStartTime
            if os.clock() - syncStartTime >= 1 then
                rfsuite.utils.log("Sync clock: " .. os.date("%Y-%m-%d %H:%M:%S"), "info")
                rfsuite.session.clockSet = true
            end
        end)

        API.setUUID("eaeb0028-219b-4cec-9f57-3c7f74dd49ac")
        API.write()
    end
end

function clocksync.reset()
    rfsuite.session.clockSet = nil
    syncStartTime = nil
end

function clocksync.isComplete()
    return rfsuite.session.clockSet ~= nil
end


return clocksync