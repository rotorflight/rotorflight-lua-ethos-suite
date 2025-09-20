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

local tailmode = {}

local mspCallMade = false

function tailmode.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if rfsuite.session.mspBusy then return end

    if (rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil)  and mspCallMade == false then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load("MIXER_CONFIG")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.tailMode = API.readValue("tail_rotor_mode")
            rfsuite.session.swashMode = API.readValue("swash_type")
            if rfsuite.session.tailMode and rfsuite.session.swashMode then
                rfsuite.utils.log("Tail mode: " .. rfsuite.session.tailMode, "info")
                rfsuite.utils.log("Swash mode: " .. rfsuite.session.swashMode, "info")
            end
        end)
        API.setUUID("fbccd634-c9b7-4b48-8c02-08ef560dc515")
        API.read()  
    end

end

function tailmode.reset()
    rfsuite.session.tailMode = nil
    rfsuite.session.swashMode = nil
    mspCallMade = false
end

function tailmode.isComplete()
    if rfsuite.session.tailMode ~= nil and rfsuite.session.swashMode ~= nil then
        return true
    end
end

return tailmode