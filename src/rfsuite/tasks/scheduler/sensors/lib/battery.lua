--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local battery = {}
local log = rfsuite.utils.log

local mspCallMade = false

local function finalizeBatteryConfig(config)
    rfsuite.session.batteryConfig = config

    log("Capacity: " .. config.batteryCapacity .. "mAh", "info")
    log("Cell Count: " .. config.batteryCellCount, "info")
    log("Warning Voltage: " .. config.vbatwarningcellvoltage .. "V", "info")
    log("Min Voltage: " .. config.vbatmincellvoltage .. "V", "info")
    log("Max Voltage: " .. config.vbatmaxcellvoltage .. "V", "info")
    log("Full Cell Voltage: " .. config.vbatfullcellvoltage .. "V", "info")
    log("LVC Percentage: " .. config.lvcPercentage .. "%", "info")
    log("Consumption Warning Percentage: " .. config.consumptionWarningPercentage .. "%", "info")
    log("Battery Config Complete", "info")

    log("Capacity: " .. config.batteryCapacity .. "mAh", "connect")
    log("Cell Count: " .. config.batteryCellCount, "connect")
    log("Warning Voltage: " .. config.vbatwarningcellvoltage .. "V", "connect")
    log("Min Voltage: " .. config.vbatmincellvoltage .. "V", "connect")
    log("Max Voltage: " .. config.vbatmaxcellvoltage .. "V", "connect")
    log("Full Cell Voltage: " .. config.vbatfullcellvoltage .. "V", "connect")
    log("LVC Percentage: " .. config.lvcPercentage .. "%", "connect")
    log("Consumption Warning Percentage: " .. config.consumptionWarningPercentage .. "%", "connect")
end

local function readSmartFuelConfig(config)
    if not rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
        finalizeBatteryConfig(config)
        return
    end

    local smartFuelAPI = rfsuite.tasks.msp.api.load("SMARTFUEL_CONFIG")
    smartFuelAPI.setCompleteHandler(function()
        config.smartfuel = tonumber(smartFuelAPI.readValue("smartfuel")) or 0
        finalizeBatteryConfig(config)
    end)

    smartFuelAPI.setErrorHandler(function(self, err)
        log("Failed to read smart fuel config via MSP: " .. err, "info")
        config.smartfuel = 0
        finalizeBatteryConfig(config)
    end)

    smartFuelAPI.setUUID("0f6f4fd1-9e69-4e13-bc53-3d0e98e5c5a5")
    smartFuelAPI.read()
end

function battery.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end
    if rfsuite.tasks.msp.mspQueue:isProcessed() == false then return end

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
            local config = {}
            config.voltageMeterSource = voltageMeterSource
            config.batteryCapacity = batteryCapacity
            config.batteryCellCount = batteryCellCount
            config.vbatwarningcellvoltage = vbatwarningcellvoltage
            config.vbatmincellvoltage = vbatmincellvoltage
            config.vbatmaxcellvoltage = vbatmaxcellvoltage
            config.vbatfullcellvoltage = vbatfullcellvoltage
            config.lvcPercentage = lvcPercentage
            config.consumptionWarningPercentage = consumptionWarningPercentage
            config.smartfuel = 0

            config.profiles = {}
            for i = 0, 5 do
                local val = API.readValue("batteryCapacity_" .. i)
                if val then
                    config.profiles[i] = val
                end
            end

            readSmartFuelConfig(config)
        end)

        API.setErrorHandler(function(self, err)
            log("Failed to read battery config via MSP: " .. err, "info")
            mspCallMade = false
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
