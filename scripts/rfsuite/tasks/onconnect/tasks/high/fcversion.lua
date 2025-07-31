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

function fcversion.wakeup()

    -- we defer to FBL_CONFIG api to retrieve this
    local apiVersion = tonumber(rfsuite.session.apiVersion)
    if apiVersion == nil or apiVersion >= 12.09 then
        return
    end

    if rfsuite.session.fcVersion== nil then
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

    -- we defer to FBL_CONFIG api to retrieve this
    local apiVersion = tonumber(rfsuite.session.apiVersion)
    if apiVersion == nil or apiVersion >= 12.09 then
        return
    end

    rfsuite.session.fcVersion = nil
    rfsuite.session.rfVersion = nil
end

function fcversion.isComplete()

    -- we defer to FBL_CONFIG api to retrieve this
    local apiVersion = tonumber(rfsuite.session.apiVersion)
    if apiVersion == nil then
        return
    end

    -- return true if apiVersion >= 12.09 as we do this in FBL_CONFIG
    if apiVersion >= 12.09 then
        return true
    end

    if rfsuite.session.fcVersion~= nil then
        return true
    end
end

return fcversion