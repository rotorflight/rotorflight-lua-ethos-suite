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

craftname = {}

function craftname.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if (rfsuite.session.craftName == nil) then
        local API = rfsuite.tasks.msp.api.load("NAME")
        API.setUUID("a66de3a0-c64e-423b-a48c-307d476303b6")
        API.read()
        if API.readComplete() and API.readValue("name") ~= nil then
            local data = API.data()
            rfsuite.session.craftName = API.readValue("name")
            if rfsuite.preferences.syncCraftName == true and model.name and rfsuite.session.craftName ~= nil then
                rfsuite.utils.log("Setting model name to: " .. rfsuite.session.craftName, "info")
                model.name(rfsuite.session.craftName)
                lcd.invalidate()
            end
            if rfsuite.session.craftName and rfsuite.session.craftName ~= "" then
                rfsuite.utils.log("Craft name: " .. rfsuite.session.craftName, "info")
            end
        end
    end    

end

function craftname.reset()
    rfsuite.session.craftName = nil
end

function craftname.isComplete()
    if rfsuite.session.craftName ~= nil then
        return true
    end
end

return craftname