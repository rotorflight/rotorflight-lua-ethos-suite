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

local apiversion = {}

local mspCallMade = false

function apiversion.wakeup()
    if rfsuite.session.apiVersion == nil and mspCallMade == false then

        mspCallMade = true

        local API = rfsuite.tasks.msp.api.load("API_VERSION")
        API.setCompleteHandler(function(self, buf)
            local version = API.readVersion()

            if version then
                local apiVersionString = tostring(version)
                if not rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiVersionString) then
                    rfsuite.utils.log("Incompatible API version detected: " .. apiVersionString, "info")
                    rfsuite.session.apiVersionInvalid = true
                    return
                end
            end

            rfsuite.session.apiVersion = version
            rfsuite.session.apiVersionInvalid = false

            if rfsuite.session.apiVersion  then
                rfsuite.utils.log("API version: " .. rfsuite.session.apiVersion, "info")
            end
        end)
        API.setUUID("22a683cb-db0e-439f-8d04-04687c9360f3")
        API.read()
    end    
end

function apiversion.reset()
    rfsuite.session.apiVersion = nil
    rfsuite.session.apiVersionInvalid = nil
    mspCallMade = false
end

function apiversion.isComplete()
    if rfsuite.session.apiVersion ~= nil then
        return true
    end
end

return apiversion