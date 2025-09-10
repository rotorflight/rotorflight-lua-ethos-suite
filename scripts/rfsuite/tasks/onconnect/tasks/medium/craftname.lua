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

local craftname = {}

local mspCallMade = false

function craftname.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if (rfsuite.session.craftName == nil) and (mspCallMade == false) then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load("NAME")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.craftName = API.readValue("name")
            if rfsuite.preferences.general.syncname == true and model.name and rfsuite.session.craftName ~= nil then
                rfsuite.utils.log("Setting model name to: " .. rfsuite.session.craftName, "info")
                model.name(rfsuite.session.craftName)
                lcd.invalidate()
            end
            if rfsuite.session.craftName and rfsuite.session.craftName ~= "" then
                rfsuite.utils.log("Craft name: " .. rfsuite.session.craftName, "info")
            else
                rfsuite.session.craftName = model.name()    
            end
        end)
        API.setUUID("37163617-1486-4886-8b81-6a1dd6d7edd1")
        API.read()
    end     

end

function craftname.reset()
    rfsuite.session.craftName = nil
    mspCallMade = false
end

function craftname.isComplete()
    if rfsuite.session.craftName ~= nil then
        return true
    end
end

return craftname