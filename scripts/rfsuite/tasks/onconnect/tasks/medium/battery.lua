--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local battery = {}

local mspCallMade = false

function battery.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end

    if (rfsuite.session.batteryConfig == nil) and mspCallMade == false then
        mspCallMade = true

        local API = rfsuite.tasks.msp.api.load("BATTERY_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local batteryCapacity = API.readValue("batteryCapacity")
            local batteryCellCount = API.readValue("batteryCellCount")
            local vbatwarningcellvoltage = API.readValue("vbatwarningcellvoltage") / 100
            local vbatmincellvoltage = API.readValue("vbatmincellvoltage") / 100
            local vbatmaxcellvoltage = API.readValue("vbatmaxcellvoltage") / 100
            local vbatfullcellvoltage = API.readValue("vbatfullcellvoltage") / 100
            local lvcPercentage = API.readValue("lvcPercentage")
            local consumptionWarningPercentage = API.readValue("consumptionWarningPercentage")
            local voltageMeterSource = API.readValue("voltageMeterSource")

            rfsuite.session.batteryConfig = {}
            rfsuite.session.batteryConfig.voltageMeterSource = voltageMeterSource
            rfsuite.session.batteryConfig.batteryCapacity = batteryCapacity
            rfsuite.session.batteryConfig.batteryCellCount = batteryCellCount
            rfsuite.session.batteryConfig.vbatwarningcellvoltage = vbatwarningcellvoltage
            rfsuite.session.batteryConfig.vbatmincellvoltage = vbatmincellvoltage
            rfsuite.session.batteryConfig.vbatmaxcellvoltage = vbatmaxcellvoltage
            rfsuite.session.batteryConfig.vbatfullcellvoltage = vbatfullcellvoltage
            rfsuite.session.batteryConfig.lvcPercentage = lvcPercentage
            rfsuite.session.batteryConfig.consumptionWarningPercentage = consumptionWarningPercentage

            rfsuite.utils.log("Capacity: " .. batteryCapacity .. "mAh", "info")
            rfsuite.utils.log("Cell Count: " .. batteryCellCount, "info")
            rfsuite.utils.log("Warning Voltage: " .. vbatwarningcellvoltage .. "V", "info")
            rfsuite.utils.log("Min Voltage: " .. vbatmincellvoltage .. "V", "info")
            rfsuite.utils.log("Max Voltage: " .. vbatmaxcellvoltage .. "V", "info")
            rfsuite.utils.log("Full Cell Voltage: " .. vbatfullcellvoltage .. "V", "info")
            rfsuite.utils.log("LVC Percentage: " .. lvcPercentage .. "%", "info")
            rfsuite.utils.log("Consumption Warning Percentage: " .. consumptionWarningPercentage .. "%", "info")
            rfsuite.utils.log("Battery Config Complete", "info")
        end)
        API.setUUID("a3f9c2b4-5d7e-4e8a-9c3b-2f6d8e7a1b2d")
        API.read()
    end

end

function battery.reset()
    rfsuite.session.batteryConfig = nil
    mspCallMade = false
end

function battery.isComplete() if rfsuite.session.batteryConfig ~= nil then return true end end

return battery
