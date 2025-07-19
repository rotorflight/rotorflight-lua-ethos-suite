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

local battery = {}

function battery.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if (rfsuite.session.batteryConfig == nil) then

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

            rfsuite.session.batteryConfig = {}
            rfsuite.session.batteryConfig.batteryCapacity = batteryCapacity
            rfsuite.session.batteryConfig.batteryCellCount = batteryCellCount
            rfsuite.session.batteryConfig.vbatwarningcellvoltage = vbatwarningcellvoltage
            rfsuite.session.batteryConfig.vbatmincellvoltage = vbatmincellvoltage
            rfsuite.session.batteryConfig.vbatmaxcellvoltage = vbatmaxcellvoltage
            rfsuite.session.batteryConfig.vbatfullcellvoltage = vbatfullcellvoltage
            rfsuite.session.batteryConfig.lvcPercentage = lvcPercentage
            rfsuite.session.batteryConfig.consumptionWarningPercentage = consumptionWarningPercentage
            -- we also get a volage scale factor stored in this table - but its in pilot config

            rfsuite.utils.log("Capacity: " .. batteryCapacity .. "mAh","info")
            rfsuite.utils.log("Cell Count: " .. batteryCellCount,"info")
            rfsuite.utils.log("Warning Voltage: " .. vbatwarningcellvoltage .. "V","info")
            rfsuite.utils.log("Min Voltage: " .. vbatmincellvoltage .. "V","info")
            rfsuite.utils.log("Max Voltage: " .. vbatmaxcellvoltage .. "V","info")
            rfsuite.utils.log("Full Cell Voltage: " .. vbatfullcellvoltage .. "V", "info")
            rfsuite.utils.log("LVC Percentage: " .. lvcPercentage .. "%","info")
            rfsuite.utils.log("Consumption Warning Percentage: " .. consumptionWarningPercentage .. "%","info")
            rfsuite.utils.log("Battery Config Complete","info")
        end)
        API.setUUID("a3f9c2b4-5d7e-4e8a-9c3b-2f6d8e7a1b2d")
        API.read()
    end    

end

function battery.reset()
    rfsuite.session.batteryConfig = nil
end

function battery.isComplete()
    if rfsuite.session.batteryConfig ~= nil then
        return true
    end
end

return battery