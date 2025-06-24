--[[
 * Copyright (C) Rotorflight Project
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
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local arg = { ... }
local config = arg[1]

local battery = {}

function battery.wakeup()
    -- Don't run if no API version (not connected)
    if rfsuite.session.apiVersion == nil then return end    

    -- Only refresh if the flag is set
    if rfsuite.session.batteryConfigNeedsRefresh then
        rfsuite.session.batteryConfigNeedsRefresh = false

        local API = rfsuite.tasks.msp.api.load("BATTERY_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local batteryCapacity = API.readValue("batteryCapacity")
            local batteryCellCount = API.readValue("batteryCellCount")
            local vbatwarningcellvoltage = API.readValue("vbatwarningcellvoltage")/100
            local vbatmincellvoltage = API.readValue("vbatmincellvoltage")/100
            local vbatmaxcellvoltage = API.readValue("vbatmaxcellvoltage")/100
            local vbatfullcellvoltage = API.readValue("vbatfullcellvoltage")/100
            local lvcPercentage = API.readValue("lvcPercentage")
            local consumptionWarningPercentage = API.readValue("consumptionWarningPercentage")

            -- Overwrite or create the table
            rfsuite.session.batteryConfig = rfsuite.session.batteryConfig or {}
            rfsuite.session.batteryConfig.batteryCapacity = batteryCapacity
            rfsuite.session.batteryConfig.batteryCellCount = batteryCellCount
            rfsuite.session.batteryConfig.vbatwarningcellvoltage = vbatwarningcellvoltage
            rfsuite.session.batteryConfig.vbatmincellvoltage = vbatmincellvoltage
            rfsuite.session.batteryConfig.vbatmaxcellvoltage = vbatmaxcellvoltage
            rfsuite.session.batteryConfig.vbatfullcellvoltage = vbatfullcellvoltage
            rfsuite.session.batteryConfig.lvcPercentage = lvcPercentage
            rfsuite.session.batteryConfig.consumptionWarningPercentage = consumptionWarningPercentage

            rfsuite.utils.log("Battery Config Refreshed", "info")
        end)
        API.setUUID("a3f9c2b4-5d7e-4e8a-9c3b-2f6d8e7a1b2d")
        API.read()
    end    
end

return battery