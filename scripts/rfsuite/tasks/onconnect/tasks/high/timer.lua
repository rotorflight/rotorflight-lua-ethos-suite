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

local timer = {}

local runOnce = false

function timer.wakeup()

    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if rfsuite.session.mspBusy then return end    

        rfsuite.session.timer = {}
        rfsuite.session.timer.start = nil -- this is used to store the start time of the timer
        rfsuite.session.timer.live = nil -- this is used to store the live timer value while inflight
        rfsuite.session.timer.lifetime = nil -- this is used to store the total flight time of a model and store it in the user ini file
        rfsuite.session.timer.session = 0 -- this is used to track flight time for the session
        runOnce = true

end

function timer.reset()
    runOnce = false
end

function timer.isComplete()
    return runOnce
end

return timer