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
local SENSOR_RATE = 0.25 -- rate in seconds

-- Store the last validated sensors and timestamp
local lastValidationResult = nil
local lastValidationTime = 0
local VALIDATION_RATE_LIMIT = 2 -- Rate limit in seconds

local lastCacheFlushTime = 0
local CACHE_FLUSH_INTERVAL = 5 -- Flush cache every 5 seconds

local telemetryState = false

local sensorStats = {}
local lastSensorValues = {}

-- Predefined sensor mappings
--[[
sensorTable: A table containing various telemetry sensor configurations for different protocols (sport, crsf, crsfLegacy).

Each sensor configuration includes:
- name: The name of the sensor.
- mandatory: A boolean indicating if the sensor is mandatory.
- sport: A table of sensor configurations for the sport protocol.
- crsf: A table of sensor configurations for the crsf protocol.
- crsfLegacy: A table of sensor configurations for the crsfLegacy protocol.
- maxmin_trigger: A function to determine if min/max tracking should be active.

Sensors included:
- RSSI Sensors (rssi)
- Arm Flags (armflags)
- Arm Disabled (arm_disabled)
- Voltage Sensors (voltage)
- RPM Sensors (rpm)
- Current Sensors (current)
- Temperature Sensors (temp_esc, temp_mcu)
- Fuel and Capacity Sensors (fuel, capacity)
- Flight Mode Sensors (governor)
- Adjustment Sensors (adj_f, adj_v)
- PID and Rate Profiles (pid_profile, rate_profile)
- Throttle Sensors (throttle_percent)

 Check this url for some usefull id numbers when associated these sensors to the correct telemetry sensors "set telemetry_sensors"
 https://github.com/rotorflight/rotorflight-firmware/blob/c7cad2c86fd833fe4bce76728f4914602614058d/src/main/telemetry/sensors.h#L34C15-L34C24
]]

local sensorTable = {
    -- RSSI Sensors
    rssi = {
        name = rfsuite.i18n.get("telemetry.sensors.rssi"),
        mandatory = true,
        maxmin_trigger = nil,
        switch_alerts = true,
        unit = UNIT_DB,
        sensors = {
            sim = {
                { appId = 0xF101, subId = 0 },
            },
            sport = {
                { appId = 0xF101, subId = 0 },
                "RSSI",   -- fallback for older versions
            },
            crsf = {
                { crsfId = 0x14, subIdStart = 0, subIdEnd = 1 },
                "Rx RSSI1", -- fallback for older versions
            },
            crsfLegacy = {
                { crsfId = 0x14, subIdStart = 0, subIdEnd = 1 },
                "RSSI 1",   -- fallback for older versions
                "RSSI 2",
                "Rx Quality",
            },
        },
    },

    -- Arm Flags
    armflags = {
        name = rfsuite.i18n.get("telemetry.sensors.arming_flags"),
        mandatory = true,
        maxmin_trigger = nil,
        set_telemetry_sensors = 90,
        sensors = {
            sim = {
                { uid = 0x5001, unit = nil, dec = nil,
                  value = function() return rfsuite.utils.simSensors('armflags') end,
                  min = 0, max = 2 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5122 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5462 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1202 },
            },
            crsfLegacy = { nil },
        },
        onchange = function(value)
                if value == 1 or value == 3 then
                    rfsuite.session.isArmed = true
                else
                    rfsuite.session.isArmed = false    
                end
        end,
    },

    -- Voltage Sensors
    voltage = {
        name = rfsuite.i18n.get("telemetry.sensors.voltage"),
        mandatory = true,
        maxmin_trigger = nil,
        set_telemetry_sensors = 3,
        switch_alerts = true,
        unit = UNIT_VOLT,
        sensors = {
            sim = {
                { uid = 0x5002, unit = UNIT_VOLT, dec = 2,
                  value = function() return rfsuite.utils.simSensors('voltage') end,
                  min = 0, max = 3000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0211 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0218 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x021A },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1041 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1051 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1080 },
            },
            crsfLegacy = { "Rx Batt" },
        },    
    },

    -- RPM Sensors
    rpm = {
        name = rfsuite.i18n.get("telemetry.sensors.headspeed"),
        mandatory = true,
        maxmin_trigger = true,
        set_telemetry_sensors = 60,
        switch_alerts = true,
        unit = UNIT_RPM,
        sensors = {
            sim = {
                { uid = 0x5003, unit = UNIT_RPM, dec = nil,
                  value = function() return rfsuite.utils.simSensors('rpm') end,
                  min = 0, max = 2000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0 },
            },
            crsfLegacy = { "GPS Alt" },
        },
    },

    -- Current Sensors
    current = {
        name = rfsuite.i18n.get("telemetry.sensors.current"),
        mandatory = false,
        maxmin_trigger = true,
        set_telemetry_sensors = 18,
        switch_alerts = true,
        unit = UNIT_AMPERE,
        sensors = {
            sim = {
                { uid = 0x5004, unit = UNIT_AMPERE, dec = 0,
                  value = function() return rfsuite.utils.simSensors('current') end,
                  min = 0, max = 25 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0208 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x104A },
            },
            crsfLegacy = { "Rx Curr" },
        },
    },

    -- ESC Temperature Sensors
    temp_esc = {
        name = rfsuite.i18n.get("telemetry.sensors.esc_temp"),
        mandatory = false,
        maxmin_trigger = true,
        set_telemetry_sensors = 23,
        switch_alerts = true,
        unit = UNIT_DEGREE,
        sensors = {
            sim = {
                { uid = 0x5005, unit = UNIT_DEGREE, dec = 0,
                  value = function() return rfsuite.utils.simSensors('temp_esc') end,
                  min = 0, max = 100 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0B70 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0418 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1047 },
            },
            crsfLegacy = { "GPS Speed" },
        },
    },

    -- MCU Temperature Sensors
    temp_mcu = {
        name = rfsuite.i18n.get("telemetry.sensors.mcu_temp"),
        mandatory = false,
        maxmin_trigger = true,
        set_telemetry_sensors = 52,
        switch_alerts = true,
        unit = UNIT_DEGREE,
        sensors = {
            sim = {
                { uid = 0x5006, unit = UNIT_DEGREE, dec = 0,
                  value = function() return rfsuite.utils.simSensors('temp_mcu') end,
                  min = 0, max = 100 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400, mspgt = 12.08 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401, msplt = 12.07 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3 },
            },
            crsfLegacy = { "GPS Sats" },
        },
    },

    -- Fuel and Capacity Sensors
    fuel = {
        name = rfsuite.i18n.get("telemetry.sensors.fuel"),
        mandatory = false,
        maxmin_trigger = nil,
        set_telemetry_sensors = 6,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        sensors = {
            sim = {
                { uid = 0x5007, unit = UNIT_PERCENT, dec = 0,
                  value = function() return rfsuite.utils.simSensors('fuel') end,
                  min = 0, max = 100 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014 },
            },
            crsfLegacy = { "Rx Batt%" },
        },
    },

    consumption = {
        name = rfsuite.i18n.get("telemetry.sensors.consumption"),
        mandatory = true,
        maxmin_trigger = nil,
        set_telemetry_sensors = 5,
        switch_alerts = true,
        unit = UNIT_MILLIAMPERE_HOUR,
        sensors = {
            sim = {
                { uid = 0x5008, unit = UNIT_MILLIAMPERE_HOUR, dec = 0,
                  value = function() return rfsuite.utils.simSensors('consumption') end,
                  min = 0, max = 5000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013 },
            },
            crsfLegacy = { "Rx Cons" },
        },
    },

    -- Flight Mode (Governor)
    governor = {
        name = rfsuite.i18n.get("telemetry.sensors.governor"),
        mandatory = true,
        maxmin_trigger = nil,
        set_telemetry_sensors = 93,
        sensors = {
            sim = {
                { uid = 0x5009, unit = nil, dec = 0,
                  value = function() return rfsuite.utils.simSensors('governor') end,
                  min = 0, max = 5 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5125 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205 },
            },
            crsfLegacy = { "Flight mode" },
        },
    },

    -- Adjustment Sensors
    adj_f = {
        name = rfsuite.i18n.get("telemetry.sensors.adj_func"),
        mandatory = true,
        maxmin_trigger = nil,
        set_telemetry_sensors = 99,
        sensors = {
            sim = {
                { uid = 0x5010, unit = nil, dec = 0,
                  value = function() return rfsuite.utils.simSensors('adj_f') end,
                  min = 0, max = 10 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221 },
            },
            crsfLegacy = { nil },
        },
    },

    adj_v = {
        name = rfsuite.i18n.get("telemetry.sensors.adj_val"),
        mandatory = true,
        maxmin_trigger = nil,
        -- grouped with adj_f, so no set_telemetry_sensors here
        sensors = {
            sim = {
                { uid = 0x5011, unit = nil, dec = 0,
                  value = function() return rfsuite.utils.simSensors('adj_v') end,
                  min = 0, max = 2000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222 },
            },
            crsfLegacy = { nil },
        },
    },

    -- PID and Rate Profiles
    pid_profile = {
        name = rfsuite.i18n.get("telemetry.sensors.pid_profile"),
        mandatory = true,
        maxmin_trigger = nil,
        set_telemetry_sensors = 95,
        sensors = {
            sim = {
                { uid = 0x5012, unit = nil, dec = 0,
                  value = function() return rfsuite.utils.simSensors('pid_profile') end,
                  min = 0, max = 6 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5130 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211 },
            },
            crsfLegacy = { nil },
        },
    },

    rate_profile = {
        name = rfsuite.i18n.get("telemetry.sensors.rate_profile"),
        mandatory = true,
        maxmin_trigger = nil,
        set_telemetry_sensors = 96,
        sensors = {
            sim = {
                { uid = 0x5013, unit = nil, dec = 0,
                  value = function() return rfsuite.utils.simSensors('rate_profile') end,
                  min = 0, max = 6 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5131 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212 },
            },
            crsfLegacy = { nil },
        },
    },

    -- Throttle Sensors
    throttle_percent = {
        name = rfsuite.i18n.get("telemetry.sensors.throttle_pct"),
        mandatory = true,
        maxmin_trigger = true,
        set_telemetry_sensors = 15,
        sensors = {
            sim = {
                { uid = 0x5014, unit = nil, dec = 0,
                  value = function() return rfsuite.utils.simSensors('throttle_percent') end,
                  min = 0, max = 100 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5269 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035 },
            },
            crsfLegacy = { nil },
        },
    },

    -- Arm Disable Flags
    armdisableflags = {
        name = rfsuite.i18n.get("telemetry.sensors.armdisableflags"),
        mandatory = true,
        maxmin_trigger = nil,
        set_telemetry_sensors = 91,
        sensors = {
            sim = {
                { uid = 0x5015, unit = nil, dec = nil,
                  value = function() return rfsuite.utils.simSensors('armdisableflags') end,
                  min = 0, max = 65536 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5123 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1203 },
            },
            crsfLegacy = { nil },
        },
    },

    -- Altitude
    altitude = {
        name = rfsuite.i18n.get("telemetry.sensors.altitude"),
        mandatory = false,
        maxmin_trigger = true,
        set_telemetry_sensors = nil,
        switch_alerts = true,
        unit = UNIT_METER,
        sensors = {
            sim = {
                { uid = 0x5016, unit = UNIT_METER, dec = 0,
                  value = function() return rfsuite.utils.simSensors('altitude') end,
                  min = 0, max = 50000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0100 }
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10B2 },
            },
            crsfLegacy = { nil },
        },
    },     

    -- Bec Voltage
    bec_voltage = {
        name = rfsuite.i18n.get("telemetry.sensors.bec_voltage"),
        mandatory = false,
        maxmin_trigger = true,
        set_telemetry_sensors = nil,
        switch_alerts = true,
        unit = UNIT_VOLT,
        sensors = {
            sim = {
                { uid = 0x5017, unit = UNIT_VOLT, dec = 2,
                  value = function() return rfsuite.utils.simSensors('bec_voltage') end,
                  min = 0, max = 3000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0901 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0219 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1081 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1049 },
            },
            crsfLegacy = { nil },
        },
    },  

    -- Cell Count
    cell_count = {
        name = rfsuite.i18n.get("telemetry.sensors.cell_count"),
        mandatory = false,
        maxmin_trigger = true,
        set_telemetry_sensors = nil,
        sensors = {
            sim = {
                { uid = 0x5018, unit = nil, dec = 0,
                  value = function() return rfsuite.utils.simSensors('cell_count') end,
                  min = 0, max = 50 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5260 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1020 },
            },
            crsfLegacy = { nil },
        },
    },  

}


--[[
    Retrieves the current sensor protocol.
    @return protocol - The protocol used by the sensor.
]]
function telemetry.getSensorProtocol()
    return protocol
end

--[[
    Function: telemetry.listSensors
    Description: Generates a list of sensors from the sensorTable.
    Returns: A table containing sensor details (key, name, and mandatory status).
]]
function telemetry.listSensors()
    local sensorList = {}

    for key, sensor in pairs(sensorTable) do 
        table.insert(sensorList, {key = key, name = sensor.name, mandatory = sensor.mandatory, set_telemetry_sensors = sensor.set_telemetry_sensors }) end

    return sensorList
end

--[[
    Function: telemetry.listSensors
    Description: Generates a list of sensors from the sensorTable.
    Returns: A table map containing audio units.
]]
function telemetry.listSensorAudioUnits()
    local sensorMap = {}

    for key, sensor in pairs(sensorTable) do 
        if sensor.unit  then
            sensorMap[key] = sensor.unit
        end    
    end

    return sensorMap
end

--[[
    Function: telemetry.listSensors
    Description: Generates a list of sensors from the sensorTable.
    Returns: A table containing sensor details (key, name, and mandatory status).
]]
function telemetry.listSwitchSensors()
    local sensorList = {}

    for key, sensor in pairs(sensorTable) do 
        if sensor.switch_alerts then
            table.insert(sensorList, {key = key, name = sensor.name, mandatory = sensor.mandatory, set_telemetry_sensors = sensor.set_telemetry_sensors }) 
        end    
    end

    return sensorList
end


--[[
    Function: telemetry.getSensorSource
    Retrieves the sensor source based on the provided sensor name.

    Parameters:
    - name (string): The name of the sensor to retrieve.

    Returns:
    - source (table or nil): The sensor source if found, otherwise nil.

    Description:
    This function attempts to retrieve a sensor source from a predefined sensor table. It first checks if the sensor is cached and returns the cached value if available. If not, it checks the sensor type (CRSF or SPORT) and retrieves the appropriate sensor source based on the conditions specified in the sensor table. If no valid sensor is found, it returns nil.

    Helper Function:
    - checkCondition(sensorEntry): Checks if the MSP version conditions are met for a given sensor entry.

    Notes:
    - The function uses a caching mechanism to store and retrieve sensor sources.
    - It supports different sensor types (CRSF, CRSF Legacy, and SPORT).
    - The function handles version conditions specified in the sensor table.
]]
function telemetry.getSensorSource(name)
    if not sensorTable[name] then return nil end

    -- Use cached value if available
    if sensors[name] then return sensors[name] end

    -- Helper function to check if MSP version conditions are met
    local function checkCondition(sensorEntry)
        if not (rfsuite.session and rfsuite.session.apiVersion) then
            -- No session or apiVersion means no valid comparison can happen, so return true (default to valid)
            return true
        end
    
        local roundedApiVersion = rfsuite.utils.round(rfsuite.session.apiVersion, 2)
    
        if sensorEntry.mspgt then
            -- Check if API version exists and meets "greater than" condition
            return roundedApiVersion >= rfsuite.utils.round(sensorEntry.mspgt, 2)
        elseif sensorEntry.msplt then
            -- Check if API version exists and meets "less than" condition
            return roundedApiVersion <= rfsuite.utils.round(sensorEntry.msplt, 2)
        end
    
        -- No conditions = always valid
        return true
    end
    
    if system.getVersion().simulation == true then
        protocol = "sport"
        for _, sensor in ipairs(sensorTable[name].sensors.sim or {}) do
            -- Skip entries with unfulfilled version conditions 

            if sensor and type(sensor) == "table" then
                -- redefine sensor params
                local sensorQ = {}
                sensorQ.appId = sensor.uid
                sensorQ.category = CATEGORY_TELEMETRY_SENSOR    

                local source = system.getSource(sensorQ)
                if source then
                    sensors[name] = source
                    return sensors[name]
                end
            end

        end
    elseif rfsuite.session.telemetryType == "crsf" then
        if not crsfSOURCE then crsfSOURCE = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = 0xEE01}) end

        if crsfSOURCE then
            protocol = "crsf"
            for _, sensor in ipairs(sensorTable[name].sensors.crsf or {}) do
                -- Skip entries with unfulfilled version conditions
                if checkCondition(sensor) then
                    if sensor and type(sensor) == "table" then
                        sensor.mspgt = nil
                        sensor.msplt = nil
                        local source = system.getSource(sensor)
                        if source then
                            sensors[name] = source
                            return sensors[name]
                        end
                    end    
                end
            end
        else
            protocol = "crsfLegacy"
            for _, sensor in ipairs(sensorTable[name].sensors.crsfLegacy or {}) do
                local source = system.getSource(sensor)
                if source then
                    sensors[name] = source
                    return sensors[name]
                end
            end
        end
    elseif rfsuite.session.telemetryType == "sport" then
        protocol = "sport"
        for _, sensor in ipairs(sensorTable[name].sensors.sport or {}) do
            -- Skip entries with unfulfilled version conditions 
            if checkCondition(sensor) then
                if sensor and type(sensor) == "table" then
                    sensor.mspgt = nil
                    sensor.msplt = nil
                    local source = system.getSource(sensor)
                    if source then
                        sensors[name] = source
                        return sensors[name]
                    end
                end
            end
        end
    else
        protocol = "unknown"    
    end

    return nil -- If no valid sensor is found
end



--[[
    Function: telemetry.validateSensors
    Purpose: Validates the sensors and returns a list of either valid or invalid sensors based on the input parameter.
    Parameters:
        returnValid (boolean) - If true, the function returns only valid sensors. If false, it returns only invalid sensors.
    Returns:
        table - A list of sensors with their keys and names. The list contains either valid or invalid sensors based on the returnValid parameter.
    Notes:
        - The function uses a rate limit to avoid frequent validations.
        - If telemetry is not active, it returns all sensors.
        - The function considers the mandatory flag for invalid sensors.
]]
function telemetry.validateSensors(returnValid)
    local now = os.clock()

    -- Return cached result if within rate limit
    if (now - lastValidationTime) < VALIDATION_RATE_LIMIT then return lastValidationResult end

    -- Update last validation time
    lastValidationTime = now

    if not rfsuite.session.telemetryState then
        local allSensors = {}
        for key, sensor in pairs(sensorTable) do table.insert(allSensors, {key = key, name = sensor.name}) end
        lastValidationResult = allSensors
        return allSensors
    end

    local resultSensors = {}

    for key, sensor in pairs(sensorTable) do
        local sensorSource = telemetry.getSensorSource(key)
        local isValid = sensorSource ~= nil and sensorSource:state() ~= false

        if returnValid then
            -- Include only valid sensors
            if isValid then table.insert(resultSensors, {key = key, name = sensor.name}) end
        else
            -- Include only invalid sensors, but consider mandatory flag
            if not isValid and sensor.mandatory ~= false then table.insert(resultSensors, {key = key, name = sensor.name}) end
        end
    end

    lastValidationResult = resultSensors
    return resultSensors
end

--[[
    Function: telemetry.simSensors
    Description: Simulates sensors by iterating over a sensor table and returning a list of valid sensors.
    Parameters:
        returnValid (boolean) - A flag indicating whether to return valid sensors.
    Returns:
        result (table) - A table containing the names and first sport sensors of valid sensors.

    This function is used to build a list of sensors that are availiable in 'simulation mode'
]]
function telemetry.simSensors(returnValid)
    local result = {}

    for key, sensor in pairs(sensorTable) do
        local name = sensor.name
        local firstSportSensor = sensor.sensors.sim and sensor.sensors.sim[1]

        if firstSportSensor then
            table.insert(result, {
                name = name,
                sensor = firstSportSensor
            })
        end
    end

    return result
end

--[[
    Function: telemetry.active
    Description: Checks if telemetry is active. Returns true if the system is in simulation mode, otherwise returns the state of telemetry.
    Returns: 
        - boolean: true if in simulation mode or telemetry is active, false otherwise.
]]
function telemetry.active()
    return rfsuite.session.telemetryState or false
end


--- Resets the telemetry module by clearing all relevant variables and data.
---
--- This function performs the following actions:
--- - Sets `telemetrySOURCE`, `crsfSOURCE`, and `protocol` to `nil`.
--- - Clears the `sensors` table by reinitializing it as an empty table.
---
--- Use this function to reset the telemetry state to its initial condition.
function telemetry.reset()
    telemetrySOURCE, crsfSOURCE, protocol = nil, nil, nil
    sensors = {}
    sensorStats = {} -- Clear min/max tracking
    local lastSensorValues = {} -- clear last sensor values
end

--[[
    Function: telemetry.wakeup

    Description:
    This function is called periodically to handle telemetry updates and cache management. It prioritizes MSP traffic, performs rate-limited telemetry checks, flushes the cache periodically, and resets telemetry sources if necessary.

    Usage:
    This function should be called in a loop or scheduled task to ensure telemetry data is processed and managed correctly.

    Notes:
    - MSP traffic is prioritized by checking the rfsuite.app.triggers.mspBusy flag.
    - Telemetry checks are rate-limited based on SENSOR_RATE.
    - The cache is flushed every CACHE_FLUSH_INTERVAL seconds.
    - Telemetry sources and cached sensors are reset if telemetry is inactive or the RSSI sensor has changed.
]]
function telemetry.wakeup()
    local now = os.clock()

    -- Prioritize MSP traffic
    if rfsuite.app.triggers.mspBusy then return end

    -- Rate-limited telemetry checks
    if (now - sensorRateLimit) >= SENSOR_RATE then
        sensorRateLimit = now
    end

    -- Track sensor max/min values
    for sensorKey, sensorDef in pairs(sensorTable) do
        local source = telemetry.getSensorSource(sensorKey)
        if source and source:state() then
            local val = source:value()
            if val then
                -- Check optional per-sensor trigger
                local shouldTrack = false

                --[[
                    Determines whether telemetry tracking should be enabled based on various sensor conditions.

                    The logic follows these rules:
                    1. If `sensorDef.maxmin_trigger` is a function, its return value decides tracking.
                    2. If the session is armed and the "governor" sensor exists with a value of 4, tracking is enabled.
                    3. If the session is armed and the "rpm" sensor exists with a value greater than 500, tracking is enabled.
                    4. If the session is armed and the "throttle_percent" sensor exists with a value greater than 30, tracking is enabled.
                    5. If the session is armed (fallback), tracking is enabled.
                    6. Otherwise, tracking is disabled.

                    Variables:
                    - sensorDef: Table containing sensor definitions, possibly with a custom trigger function.
                    - shouldTrack: Boolean flag indicating whether telemetry tracking should occur.
                    - rfsuite.session.isArmed: Boolean indicating if the session is currently armed.
                    - telemetry.getSensorSource: Function to retrieve sensor data by name.
                ]]
                if type(sensorDef.maxmin_trigger) == "function" then
                    shouldTrack = sensorDef.maxmin_trigger()
                else
                    shouldTrack = rfsuite.utils.inFlight()
                end

                -- onchange tracking
                if lastSensorValues[sensorKey] ~= val then
                    if type(sensorDef.onchange) == "function" then
                        sensorDef.onchange(val)
                    end
                    lastSensorValues[sensorKey] = val
                end

                -- Record min/max if tracking is active
                if shouldTrack then
                    sensorStats[sensorKey] = sensorStats[sensorKey] or {min = math.huge, max = -math.huge}
                    sensorStats[sensorKey].min = math.min(sensorStats[sensorKey].min, val)
                    sensorStats[sensorKey].max = math.max(sensorStats[sensorKey].max, val)
                end
            end
        end
    end

    -- Periodic cache flush every 5 seconds
    if ((now - lastCacheFlushTime) >= CACHE_FLUSH_INTERVAL) or rfsuite.session.resetTelemetry == true then
        if rfsuite.session.resetTelemetry == true then
            rfsuite.utils.log("Telemetry cache reset", "info")
            rfsuite.session.resetTelemetry = false
        end
        lastCacheFlushTime = now
        telemetry.reset()
    end

    -- Reset if telemetry is inactive or RSSI sensor changed
    if not rfsuite.session.telemetryState or rfsuite.session.telemetryTypeChanged then
        telemetry.reset()
    end
end

-- retrieve min/max values for a sensor
function telemetry.getSensorStats(sensorKey)
    return sensorStats[sensorKey] or {min = nil, max = nil}
end

return telemetry
