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
local CACHE_FLUSH_INTERVAL = 10 -- Flush cache every 10 seconds

local telemetryState = false

-- Predefined sensor mappings
--[[
sensorTable: A table containing various telemetry sensor configurations for different protocols (sport, crsf, crsfLegacy).

Each sensor configuration includes:
- name: The name of the sensor.
- mandatory: A boolean indicating if the sensor is mandatory.
- sport: A table of sensor configurations for the sport protocol.
- crsf: A table of sensor configurations for the crsf protocol.
- crsfLegacy: A table of sensor configurations for the crsfLegacy protocol.

Sensors included:
- RSSI Sensors (rssi)
- Arm Flags (armflags)
- Voltage Sensors (voltage)
- RPM Sensors (rpm)
- Current Sensors (current)
- Temperature Sensors (temp_esc, temp_mcu)
- Fuel and Capacity Sensors (fuel, capacity)
- Flight Mode Sensors (governor)
- Adjustment Sensors (adj_f, adj_v)
- PID and Rate Profiles (pid_profile, rate_profile)
- Throttle Sensors (throttle_percentage)
]]
local sensorTable = {
    -- RSSI Sensors
    rssi = {
        name = "RSSI",
        mandatory = true,
        sim = {
            {appId=0xF101, subId=0},
        },
        sport = {
            {appId=0xF101, subId=0},
            "RSSI",   -- fallback for older versions (should never get here if running ethos 1.6.2 or newer)
        },
        crsf = {
            {crsfId=0x14, subIdStart=0, subIdEnd=1},
            "Rx RSSI1", -- fallback for older versions (should never get here if running ethos 1.6.2 or newer)
        },
        crsfLegacy = {
            {crsfId=0x14, subIdStart=0, subIdEnd=1},
            "RSSI 1",   -- fallback for older versions (should never get here if running ethos 1.6.2 or newer)
            "RSSI 2",
            "Rx Quality",
        }
    },

    -- Arm Flags
    armflags = {
        name = "Arming Flags",
        mandatory = true,
        sim = {
            {uid=0x5001, unit=nil, dec=nil, value=function() return rfsuite.utils.simTelemetry('armflags') end, min = 0, max = 2},
        },
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5122},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5462}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1202}
        },
        crsfLegacy = {nil}
    },

    -- Voltage Sensors
    voltage = {
        name = "Voltage",
        mandatory = true,
        sim =  {
            {uid=0x5002, unit=UNIT_VOLT, dec=2, value=function() return rfsuite.utils.simTelemetry('voltage') end, min = 0, max = 3000},
        },
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0211},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0218},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x021A},
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1041},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1051},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1080},
        },
        crsfLegacy = {"Rx Batt"}
    },

    -- RPM Sensors
    rpm = {
        name = "Head Speed",
        mandatory = true,
        sim =  {
            {uid=0x5003, unit=UNIT_RPM, dec=nil, value=function() return rfsuite.utils.simTelemetry('rpm') end, min = 0, max = 2000},
        },
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0}
        },
        crsfLegacy = {"GPS Alt"}
    },

    -- Current Sensors
    current = {
        name = "Current",
        mandatory = false,
        sim =  {
            {uid=0x5004, unit=UNIT_AMPERE, dec=0, value=function() return rfsuite.utils.simTelemetry('current') end, min = 0, max = 25},
        },
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042}
        },
        crsfLegacy = {"Rx Curr"}
    },

    -- Temperature Sensors
    temp_esc = {
        name = "ESC Temperature",
        mandatory = false,
        sim =  {
            {uid=0x5005, unit=UNIT_DEGREE, dec=0, value=function() return rfsuite.utils.simTelemetry('temp_esc') end, min = 0, max = 100},
        },   
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0B70}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0}
        },
        crsfLegacy = {"GPS Speed"}
    },
    temp_mcu = {
        name = "MCU Temperature",
        mandatory = false,
        sim =  {
            {uid=0x5006, unit=UNIT_DEGREE, dec=0, value=function() return rfsuite.utils.simTelemetry('temp_mcu') end, min = 0, max = 100},
        },         
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400, mspgt = 12.08},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401, msplt = 12.07}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3}
        },
        crsfLegacy = {"GPS Sats"}
    },

    -- Fuel and Capacity Sensors
    fuel = {
        name = "Charge Level",
        mandatory = false,
        sim =  {
            {uid=0x5007, unit=UNIT_PERCENT, dec=0, value=function() return rfsuite.utils.simTelemetry('fuel') end, min = 0, max = 100},
        },               
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014}
        },
        crsfLegacy = {"Rx Batt%"}
    },
    consumption = {
        name = "Consumption",
        mandatory = false,
        sim =  {
            {uid=0x5008, unit=UNIT_MILLIAMPERE_HOUR, dec=0, value=function() return rfsuite.utils.simTelemetry('consumption') end, min = 0, max = 5000},
        },           
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013}
        },
        crsfLegacy = {"Rx Cons"}
    },

    -- Flight Mode Sensors
    governor = {
        name = "Governor State",
        mandatory = false,
        sim =  {
            {uid=0x5009, unit=nil, dec=0, value=function() return rfsuite.utils.simTelemetry('governor') end, min = 0, max = 5},
        },        
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5125},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205}
        },
        crsfLegacy = {"Flight mode"}
    },

    -- Adjustment Sensors
    adj_f = {
        name = "Adj (Function)",
        mandatory = false,
        sim =  {
            {uid=0x5010, unit=nil, dec=0, value=function() return rfsuite.utils.simTelemetry('adj_f') end, min = 0, max = 10},
        },           
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221}
        },
        crsfLegacy = {nil}
    },
    adj_v = {
        name = "Adj (Value)",
        mandatory = false,
        sim =  {
            {uid=0x5011, unit=nil, dec=0, value=function() return rfsuite.utils.simTelemetry('adj_v') end, min = 0, max = 2000},
        },           
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222}
        },
        crsfLegacy = {nil}
    },

    -- PID and Rate Profiles
    pid_profile = {
        name = "PID Profile",
        mandatory = true,
        sim =  {
            {uid=0x5012, unit=nil, dec=0, value=function() return rfsuite.utils.simTelemetry('pid_profile') end, min = 0, max = 6},
        },            
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5130},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211}
        },
        crsfLegacy = {nil}
    },
    rate_profile = {
        name = "Rate Profile",
        mandatory = true,
        sim =  {
            {uid=0x5013, unit=nil, dec=0, value=function() return rfsuite.utils.simTelemetry('rate_profile') end, min = 0, max = 6},
        },            
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5131},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212}
        },
        crsfLegacy = {nil}
    },

    -- Throttle Sensors
    throttle_percent = {
        name = "Throttle %",
        mandatory = true,
        sim =  {
            {uid=0x5014, unit=nil, dec=0, value=function() return rfsuite.utils.simTelemetry('throttle_percent') end, min = 0, max = 100},
        },         
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440}
        },
        crsf = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035}
        },
        crsfLegacy = {nil}
    }
}

-- Cache telemetry source
local tlm = system.getSource({category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE})

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

    for key, sensor in pairs(sensorTable) do table.insert(sensorList, {key = key, name = sensor.name, mandatory = sensor.mandatory}) end

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
        if sensorEntry.mspgt then
            -- Check if API version exists and meets "greater than" condition
            return rfsuite.session and rfsuite.session.apiVersion and (rfsuite.utils.round(rfsuite.session.apiVersion,2) >= rfsuite.utils.round(sensorEntry.mspgt,2))
        elseif sensorEntry.msplt then
            -- Check if API version exists and meets "less than" condition
            return rfsuite.session and rfsuite.session.apiVersion and (rfsuite.utils.round(rfsuite.session.apiVersion,2) <= rfsuite.utils.round(sensorEntry.msplt,2))

        end
        -- No conditions = always valid
        return true
    end

    if system.getVersion().simulation == true then
        protocol = "sport"
        for _, sensor in ipairs(sensorTable[name].sim or {}) do
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
    elseif rfsuite.session.rssiSensorType == "crsf" then
        if not crsfSOURCE then crsfSOURCE = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = 0xEE01}) end

        if crsfSOURCE then
            protocol = "crsf"
            for _, sensor in ipairs(sensorTable[name].crsf or {}) do
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
            for _, sensor in ipairs(sensorTable[name].crsfLegacy or {}) do
                local source = system.getSource(sensor)
                if source then
                    sensors[name] = source
                    return sensors[name]
                end
            end
        end
    elseif rfsuite.session.rssiSensorType == "sport" then
        protocol = "sport"
        for _, sensor in ipairs(sensorTable[name].sport or {}) do
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

    if not telemetry.active() then
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
        local firstSportSensor = sensor.sim and sensor.sim[1]

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
    if system.getVersion().simulation then return true end
    return telemetryState
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
        telemetryState = tlm and tlm:state() or false
    end

    -- Periodic cache flush every 10 seconds
    if (now - lastCacheFlushTime) >= CACHE_FLUSH_INTERVAL then
        lastCacheFlushTime = now
        sensors = {} -- Reset cached sensors
        telemetrySOURCE, crsfSOURCE, protocol = nil, nil, nil
    end

    -- Reset if telemetry is inactive or RSSI sensor changed
    if not telemetry.active() or rfsuite.session.rssiSensorChanged then
        telemetrySOURCE, crsfSOURCE, protocol = nil, nil, nil
        sensors = {}
    end
end

return telemetry
