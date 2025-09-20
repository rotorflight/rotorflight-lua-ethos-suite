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

local fcversion = {}

local mspCallMade = false

function fcversion.wakeup()

    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    
    if rfsuite.session.mspBusy then return end

    if mspCallMade == false then

        mspCallMade = true

        local API = rfsuite.tasks.msp.api.load("FC_VERSION")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.fcVersion = API.readVersion()
            rfsuite.session.rfVersion = API.readRfVersion()
            if rfsuite.session.fcVersion then
                rfsuite.utils.log("FC version: " .. rfsuite.session.fcVersion, "info")
            end
        end)
        API.setUUID("22a683cb-dj0e-439f-8d04-04687c9360fu")
        API.read()
    end    
end

function fcversion.reset()
    rfsuite.session.fcVersion = nil
    rfsuite.session.rfVersion = nil
    mspCallMade = false
end

function fcversion.isComplete()
    if rfsuite.session.fcVersion~= nil then
        return true
    end
end

return fcversion