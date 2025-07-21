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

local modelid = {}

function modelid.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if (rfsuite.session.modelID == nil) then 
        local API = rfsuite.tasks.msp.api.load("PILOT_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local model_id = API.readValue("model_id")
            local model_param1_value = API.readValue("model_param1_value")
            local model_param1_type = API.readValue("model_param1_type") / 10
            if model_id ~= nil or model_param1_value ~= nil then
                rfsuite.utils.log("Model id: " .. model_id, "info")
                rfsuite.utils.log("Model Flight Time: " .. model_param1_value, "info")
                rfsuite.session.modelID = model_id
                rfsuite.session.modelFlightTime = model_param1_value or 0
            end    
        end)
        API.setUUID("587d2865-df85-48e5-844b-e01c9f1aa247")
        API.read()
    end

end

function modelid.reset()
    rfsuite.session.modelID = nil
end

function modelid.isComplete()
    if rfsuite.session.modelID ~= nil then
        return true
    end
end

return modelid