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

local servos = {}

local mspCall1Made = false
local mspCall2Made = false

function servos.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if rfsuite.session.mspBusy then return end


    if (rfsuite.session.servoCount == nil) and (mspCall1Made == false) then
        mspCall1Made = true
        local API = rfsuite.tasks.msp.api.load("STATUS")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.servoCount = API.readValue("servo_count")
            if rfsuite.session.servoCount then
                rfsuite.utils.log("Servo count: " .. rfsuite.session.servoCount, "info")
            end    
        end)
        API.setUUID("d7e0db36-ca3c-4e19-9a64-40e76c78329c")
        API.read()

    elseif (rfsuite.session.servoOverride == nil) and (mspCall2Made == false) then
        mspCall2Made = true
        local API = rfsuite.tasks.msp.api.load("SERVO_OVERRIDE")
        API.setCompleteHandler(function(self, buf)
            for i, v in pairs(API.data().parsed) do
                if v == 0 then
                    rfsuite.utils.log("Servo override: true (" .. i .. ")", "info")
                    rfsuite.session.servoOverride = true
                end
            end
            if rfsuite.session.servoOverride == nil then rfsuite.session.servoOverride = false end
        end)
        API.setUUID("b9617ec3-5e01-468e-a7d5-ec7460d277ef")
        API.read()
    end    

end

function servos.reset()
    rfsuite.session.servoCount = nil
    rfsuite.session.servoOverride = nil
    mspCall1Made = false
    mspCall2Made = false
end

function servos.isComplete()
    if rfsuite.session.servoCount ~= nil and rfsuite.session.servoOverride ~= nil then
        return true
    end
end

return servos