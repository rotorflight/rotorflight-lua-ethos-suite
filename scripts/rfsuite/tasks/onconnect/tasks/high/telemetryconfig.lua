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

local telemetryconfig = {}

local mspCallMade = false

function telemetryconfig.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if rfsuite.session.mspBusy then return end

    if (rfsuite.session.telemetryConfig == nil) and (mspCallMade == false) then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local data = API.data().parsed

            -- normalize into a 40-element array
            local slots = {}
            for i = 1, 40 do
                local key = "telem_sensor_slot_" .. i
                slots[i] = tonumber(data[key]) or 0
            end

            -- also keep the full config table if you want other settings
            rfsuite.session.telemetryConfig = slots

            -- build a string with only non-zero entries
            local parts = {}
            for i, v in ipairs(slots) do
                if v ~= 0 then
                    parts[#parts+1] = tostring(v)
                end
            end
            local slotsStr = table.concat(parts, ",")

            if rfsuite.utils and rfsuite.utils.log then
                rfsuite.utils.log("Updated telemetry sensors: " .. slotsStr, "info")
            end
        end)
        API.setUUID("38163617-1496-4886-8b81-6a1dd6d7ed81")
        API.read()
    end     

end

function telemetryconfig.reset()
    rfsuite.session.telemetryConfig = nil
    mspCallMade = false
end

function telemetryconfig.isComplete()
    if rfsuite.session.telemetryConfig ~= nil then
        return true
    end
end

return telemetryconfig