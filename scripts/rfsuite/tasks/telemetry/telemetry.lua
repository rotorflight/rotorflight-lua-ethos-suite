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
local arg = {...}
local config = arg[1]

local telemetry = {}
local sensors = {}
local protocol, telemetrySOURCE, crsfSOURCE
local sensorRateLimit = os.clock()
local SENSOR_RATE = 2 -- rate in seconds

local telemetryState = false

-- Predefined sensor mappings
local sensorTable = {
    rssi = {sport = rfsuite.utils.getRssiSensor(), ccrsf = rfsuite.utils.getRssiSensor(), lcrsf = nil},
    armflags = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5462}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1202}, lcrsf = nil},
    voltage = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011}, lcrsf = "Rx Batt"},
    rpm = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0}, lcrsf = "GPS Alt"},
    current = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012}, lcrsf = "Rx Curr"},
    currentESC1 = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042}, lcrsf = nil},
    tempESC = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0B70}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0}, lcrsf = "GPS Speed"},
    tempMCU = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3}, lcrsf = "GPS Sats"},
    fuel = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014}, lcrsf = "Rx Batt%"},
    capacity = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013}, lcrsf = "Rx Cons"},
    governor = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450},sport_alt = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5125}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205}, lcrsf = "Flight mode"},
    adjF = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221}, lcrsf = nil},
    adjV = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222}, lcrsf = nil},
    pidProfile = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211}, lcrsf = nil},
    rateProfile = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212}, lcrsf = nil},
    throttlePercentage = {sport = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440}, ccrsf = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035}, lcrsf = nil},
    roll = {sport = {category = CATEGORY_ANALOG, member = ANALOG_STICK_AILERON}, crsf = {category = CATEGORY_ANALOG, member = ANALOG_STICK_AILERON}, lcrsf = {category = CATEGORY_ANALOG, member = ANALOG_STICK_AILERON}},
    pitch = {sport = {category = CATEGORY_ANALOG, member = ANALOG_STICK_ELEVATOR}, crsf = {category = CATEGORY_ANALOG, member = ANALOG_STICK_ELEVATOR}, lcrsf = {category = CATEGORY_ANALOG, member = ANALOG_STICK_ELEVATOR}},
    yaw = {sport = {category = CATEGORY_ANALOG, member = ANALOG_STICK_RUDDER}, crsf = {category = CATEGORY_ANALOG, member = ANALOG_STICK_RUDDER}, lcrsf = {category = CATEGORY_ANALOG, member = ANALOG_STICK_RUDDER}},
    collective = {sport = {category = CATEGORY_ANALOG, member = ANALOG_STICK_THROTTLE}, crsf = {category = CATEGORY_ANALOG, member = ANALOG_STICK_THROTTLE}, lcrsf = {category = CATEGORY_ANALOG, member = ANALOG_STICK_THROTTLE}}
}

-- Cache telemetry source
local tlm = system.getSource({category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE})

--- Retrieve the active telemetry protocol
---@return string
function telemetry.getSensorProtocol()
    return protocol
end

--- Retrieve a sensor source by name
---@param name string
---@return any
function telemetry.getSensorSource(name)
    if not sensorTable[name] then return nil end

    -- Use cached value if available
    if sensors[name] then return sensors[name] end

    if not telemetrySOURCE then telemetrySOURCE = system.getSource("Rx RSSI1") end

    if telemetrySOURCE then
        if not crsfSOURCE then crsfSOURCE = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = 0xEE01}) end

        if crsfSOURCE then
            protocol = "ccrsf"
            sensors[name] = system.getSource(sensorTable[name].ccrsf)
            if sensors[name] == nil and sensorTable[name].ccrsf_alt ~= nil then
                sensors[name] = system.getSource(sensorTable[name].ccrsf_alt)
            end  
        else
            protocol = "lcrsf"
            sensors[name] = system.getSource(sensorTable[name].lcrsf)
            if sensors[name] == nil and sensorTable[name].lcrsf_alt ~= nil then
                sensors[name] = system.getSource(sensorTable[name].lcrsf_alt)
            end            
        end
    else
        protocol = "sport"
        sensors[name] = system.getSource(sensorTable[name].sport)
        if sensors[name] == nil and sensorTable[name].sport_alt ~= nil then
            sensors[name] = system.getSource(sensorTable[name].sport_alt)
        end
    end

    return sensors[name]
end

--- Check if telemetry is active
---@return boolean
function telemetry.active()
    if system.getVersion().simulation then return true end
    return telemetryState
end

--- Wakeup function to refresh telemetry state
function telemetry.wakeup()
    local now = os.clock()

    if rfsuite.app.triggers.mspBusy then return end

    -- Rate-limited telemetry checks
    if (now - sensorRateLimit) >= SENSOR_RATE then
        sensorRateLimit = now
        telemetryState = tlm and tlm:state() or false
    end

    -- Reset if telemetry is inactive or RSSI sensor changed
    if not telemetry.active() or rfsuite.rssiSensorChanged then
        telemetrySOURCE, crsfSOURCE, protocol = nil, nil, nil
        sensors = {}
    end
end

return telemetry
