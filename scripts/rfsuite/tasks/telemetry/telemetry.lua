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

-- Store the last validated sensors and timestamp
local lastValidationResult = nil
local lastValidationTime = 0
local VALIDATION_RATE_LIMIT = 5 -- Rate limit in seconds

local telemetryState = false

-- Predefined sensor mappings
local sensorTable = {
    -- RSSI Sensors
    rssi = {
        sport = {
            rfsuite.utils.getRssiSensor()
        },
        customCRSF = {
            rfsuite.utils.getRssiSensor()
        },
        legacyCRSF = {
            nil
        }
    },

    -- Arm Flags
    armflags = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5122},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5462},
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1202}
        },
        legacyCRSF = {
            nil
        }
    },

    -- Voltage Sensors
    voltage = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011}
        },
        legacyCRSF = {
            "Rx Batt"
        }
    },

    -- RPM Sensors
    rpm = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0}
        },
        legacyCRSF = {
            "GPS Alt"
        }
    },

    -- Current Sensors
    current = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200},            
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201},
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012},            
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042},
        },
        legacyCRSF = {
            "Rx Curr"
        }
    },

    -- Temperature Sensors
    tempESC = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
            {category = CATEGORY_TELEMETRY_SENSOR, appId =  0x0B70}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0}
        },
        legacyCRSF = {
            "GPS Speed"
        }
    },
    tempMCU = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3}
        },
        legacyCRSF = {
            "GPS Sats"
        }
    },

    -- Fuel and Capacity Sensors
    fuel = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014}
        },
        legacyCRSF = {
            "Rx Batt%"
        }
    },
    capacity = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013}
        },
        legacyCRSF = {
            "Rx Cons"
        }
    },

    -- Flight Mode Sensors
    governor = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5125},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205}
        },
        legacyCRSF = {
            "Flight mode"
        }
    },

    -- Adjustment Sensors
    adjF = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221}
        },
        legacyCRSF = {
            nil
        }
    },
    adjV = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222}
        },
        legacyCRSF = {
            nil
        }
    },

    -- PID and Rate Profiles
    pidProfile = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5130},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211}
        },
        legacyCRSF = {
            nil
        }
    },
    rateProfile = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5131},            
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212}
        },
        legacyCRSF = {
            nil
        }
    },

    -- Throttle Sensors
    throttlePercentage = {
        sport = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440}
        },
        customCRSF = {
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035}
        },
        legacyCRSF = {
            nil
        }
    },

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
            protocol = "customCRSF"
            for _, sensor in ipairs(sensorTable[name].customCRSF or {}) do
                local source = system.getSource(sensor)
                if source then
                    sensors[name] = source
                    return sensors[name]
                end
            end
        else
            protocol = "legacyCRSF"
            for _, sensor in ipairs(sensorTable[name].legacyCRSF or {}) do
                local source = system.getSource(sensor)
                if source then
                    sensors[name] = source
                    return sensors[name]
                end
            end
        end
    else
        protocol = "sport"
        for _, sensor in ipairs(sensorTable[name].sport or {}) do
            local source = system.getSource(sensor)
            if source then
                sensors[name] = source
                return sensors[name]
            end
        end
    end

    return nil -- If no valid sensor is found
end


--- Function to validate sensors with rate limiting
---@return table
function telemetry.validateSensors()
    local now = os.clock()
    
    -- Return cached result if within rate limit
    if (now - lastValidationTime) < VALIDATION_RATE_LIMIT then
        return lastValidationResult
    end
    
    -- Update last validation time
    lastValidationTime = now
    
    if not telemetry.active() then
        local allSensors = {}
        for name, _ in pairs(sensorTable) do
            table.insert(allSensors, name)
        end
        lastValidationResult = allSensors
        return allSensors
    end

    local failedSensors = {}
    
    for name, _ in pairs(sensorTable) do
        local sensor = telemetry.getSensorSource(name)
        if sensor == nil or sensor:state() == false then
            table.insert(failedSensors, name)
        end
    end
    
    lastValidationResult = failedSensors
    return failedSensors
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
