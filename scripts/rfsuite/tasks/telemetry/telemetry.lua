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

]]--
--
local arg = {...}
local config = arg[1]

local telemetry = {}

local sensors = {}
local protocol = nil

local telemetrySOURCE
local crsfSOURCE
local tgt

local sensorRateLimit = os.clock()
local sensorRate = 2 -- how fast can we call the rssi sensor

local telemetryState = false

local sensorTable = {}
sensorTable["rssi"] = {sport = rfsuite.utils.getRssiSensor(), ccrsf = rfsuite.utils.getRssiSensor(), rfsuite.utils.getRssiSensor()}
sensorTable["voltage"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011}, lcrsf = "Rx Batt"}
sensorTable["rpm"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0}, lcrsf = "GPS Alt"}
sensorTable["current"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012}, lcrsf = "Rx Curr"}
sensorTable["currentESC1"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042}, lcrsf = nil}
sensorTable["tempESC"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0B70}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0}, lcrsf = "GPS Speed"}
sensorTable["tempMCU"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3}, lcrsf = "GPS Sats"}
sensorTable["fuel"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014}, lcrsf = "Rx Batt%"}
sensorTable["capacity"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013}, lcrsf = "Rx Cons"}
sensorTable["governor"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205}, lcrsf = "Flight mode"}
sensorTable["adjF"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221}, lcrsf = nil}
sensorTable["adjV"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222}, lcrsf = nil}
sensorTable["pidProfile"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211}, lcrsf = nil}
sensorTable["rateProfile"] = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212}, lcrsf = nil}

local tlm = system.getSource({category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE, options = nil})

function telemetry.getSensorProtocol()
    return protocol
end

function telemetry.getSensorSource(name)
    local src
    if sensorTable[name] ~= nil then
        if sensors[name] == nil then

            if telemetrySOURCE == nil then telemetrySOURCE = system.getSource("Rx RSSI1") end

            -- find type we are targetting
            if telemetrySOURCE ~= nil then
                if crsfSOURCE == nil then crsfSOURCE = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = 0xEE01}) end

                if crsfSOURCE ~= nil then
                    protocol = 'ccrsf'
                    src = system.getSource(sensorTable[name].ccrsf)
                else
                    protocol = 'lcrsf'
                    src = system.getSource(sensorTable[name].lcrsf)
                end
            else
                protocol = 'sport'
                src = system.getSource(sensorTable[name].sport)
            end

        else
            src = sensors[name]
        end
        return src
    end

    return nil
end

function telemetry.active()

    if system:getVersion().simulation == true then return true end

    return telemetryState
end

function telemetry.wakeup()

    -- we need to rate limit these calls to save issues

    if rfsuite.app.triggers.mspBusy ~= true then
        local now = os.clock()
        if (now - sensorRateLimit) >= sensorRate then
            sensorRateLimit = now

            if tlm:state() == true then
                telemetryState = true
            else
                telemetryState = false
            end

        end
    end

    if not telemetry.active() or rfsuite.rssiSensorChanged == true then
        telemetrySOURCE = nil
        crsfSOURCE = nil
        protocol = nil
        sensors = {}
    end

end

return telemetry
