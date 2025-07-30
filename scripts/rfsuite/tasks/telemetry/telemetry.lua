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
local i18n = rfsuite.i18n.get
local telemetry = {}
local protocol, telemetrySOURCE, crsfSOURCE

-- sensor cache: weak values so GC can drop cold sources
local sensors   = setmetatable({}, { __mode = "v" })

-- debug counters
local cache_hits, cache_misses = 0, 0

-- LRU for hot sources
local HOT_SIZE  = 25
local hot_list, hot_index = {}, {}

local function mark_hot(key)
  local idx = hot_index[key]
  if idx then
    table.remove(hot_list, idx)
  elseif #hot_list >= HOT_SIZE then
    local old = table.remove(hot_list, 1)
    hot_index[old] = nil
    -- evict the old sensor so cache size ≤ HOT_SIZE
    sensors[old] = nil    
  end
  table.insert(hot_list, key)
  hot_index[key] = #hot_list
end

function telemetry._debugStats()
  local hot_count = #hot_list
  return {
    hits        = cache_hits,
    misses      = cache_misses,
    hot_size    = hot_count,
    hot_list    = hot_list,
  }
end

-- Rate‐limiting for wakeup()
local sensorRateLimit = os.clock()
local ONCHANGE_RATE = 0.5        -- 1 second between onchange scans

-- Store the last validated sensors and timestamp
local lastValidationResult = nil
local lastValidationTime   = 0
local VALIDATION_RATE_LIMIT = 2  -- seconds

local lastCacheFlushTime   = 0
local CACHE_FLUSH_INTERVAL = 5  -- seconds

local telemetryState = false

-- Store last seen values for each sensor (by key)
local lastSensorValues = {}


telemetry.sensorStats = {}

-- For “reduced table” of onchange‐capable sensors:
local filteredOnchangeSensors = nil
local onchangeInitialized     = false

-- Predefined sensor mappings
--[[
sensorTable: A table containing various telemetry sensor configurations for different protocols (sport, crsf, crsfLegacy).

Each sensor configuration includes:
- name: The name of the sensor.
- mandatory: A boolean indicating if the sensor is mandatory.
- sport: A table of sensor configurations for the sport protocol.
- crsf: A table of sensor configurations for the crsf protocol.
- crsfLegacy: A table of sensor configurations for the crsfLegacy protocol.
- stats: A function to determine if min/max tracking should be active.
- localizations: A function to transform the sensor value.

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

Check this url for some useful ID numbers when associating these sensors to the correct telemetry sensors "set telemetry_sensors"
https://github.com/rotorflight/rotorflight-firmware/blob/c7cad2c86fd833fe4bce76728f4914602614058d/src/main/telemetry/sensors.h#L34C15-L34C24
]]--

local sensorTable = {


    -- RSSI Sensors
    rssi = {
        name = i18n("telemetry.sensors.rssi"),
        mandatory = true,
        stats = true,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
        sensors = {
            sim = {
                { appId = 0xF010, subId = 0 },
            },
            sport = {
                { appId = 0xF010, subId = 0 },
            },
            crsf = {
                {crsfId=0x14, subId = 2}
            },
            crsfLegacy = {
                {crsfId=0x14, subIdStart=0, subIdEnd=1}
            },
        },
    },

    -- RSSI Sensors
    link = {
        name = i18n("telemetry.sensors.link"),
        mandatory = true,
        stats = true,
        switch_alerts = true,
        unit = UNIT_DB,
        unit_string = "dB",
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
            },
        },
    },    

    -- Arm Flags
    armflags = {
        name = i18n("telemetry.sensors.arming_flags"),
        mandatory = true,
        stats = false,
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
        name = i18n("telemetry.sensors.voltage"),
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 3,
        switch_alerts = true,
        unit = UNIT_VOLT,
        unit_string = "V",
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
        name = i18n("telemetry.sensors.headspeed"),
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 60,
        switch_alerts = true,
        unit = UNIT_RPM,
        unit_string = "rpm",
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
        name = i18n("telemetry.sensors.current"),
        mandatory = false,
        stats = true,
        set_telemetry_sensors = 4,
        switch_alerts = true,
        unit = UNIT_AMPERE,
        unit_string = "A",
        sensors = {
            sim = {
                { uid = 0x5004, unit = UNIT_AMPERE, dec = 0,
                  value = function() return rfsuite.utils.simSensors('current') end,
                  min = 0, max = 300 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0208 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201 },               
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042 },                
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x104A },
            },
            crsfLegacy = { "Rx Curr" },
        },
    },

    -- ESC Temperature Sensors
    temp_esc = {
        name = i18n("telemetry.sensors.esc_temp"),
        mandatory = false,
        stats = true,
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
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401, mspgt = 12.08},
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0418 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1047 },
            },
            crsfLegacy = { "GPS Speed" },
        },
        localizations = function(value)
            local major = UNIT_DEGREE
            if value == nil then return nil, major, nil end

            -- Shortcut to the user’s temperature‐unit preference (may be nil)
            local prefs = rfsuite.preferences.localizations
            local isFahrenheit = prefs and prefs.temperature_unit == 1

            if isFahrenheit then
                -- Convert from Celsius to Fahrenheit
                return value * 1.8 + 32, major, "°F"
            end

            -- Default: return Celsius
            return value, major, "°C"
        end,
    },

    -- MCU Temperature Sensors
    temp_mcu = {
        name = i18n("telemetry.sensors.mcu_temp"),
        mandatory = false,
        stats = true,
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
        localizations = function(value)
            local major = UNIT_DEGREE
            if value == nil then return nil, major, nil end

            -- Shortcut to the user’s temperature‐unit preference (may be nil)
            local prefs = rfsuite.preferences.localizations
            local isFahrenheit = prefs and prefs.temperature_unit == 1

            if isFahrenheit then
                -- Convert from Celsius to Fahrenheit
                return value * 1.8 + 32, major, "°F"
            end

            -- Default: return Celsius
            return value, major, "°C"
        end,
    },

    -- Fuel and Capacity Sensors
    fuel = {
        name = i18n("telemetry.sensors.fuel"),
        mandatory = false,
        stats = true,
        set_telemetry_sensors = 6,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
        sensors = {
            sim = {
                { 
                    uid = 0x5007, unit = UNIT_PERCENT, dec = 0,
                    value = function() return rfsuite.utils.simSensors('fuel') end,                   
                    min = 0, max = 100
                },
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

    -- Fuel and Capacity Sensors
    smartfuel = {
        name = i18n("telemetry.sensors.smartfuel"),
        mandatory = false,
        stats = true,
        set_telemetry_sensors = nil,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
        sensors = {
            sim = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1 },
            },
            crsfLegacy = nil,
        },
    },

    -- Fuel and Capacity Sensors
    smartconsumption = {
        name = i18n("telemetry.sensors.smartconsumption"),
        mandatory = false,
        stats = true,
        set_telemetry_sensors = nil,
        switch_alerts = true,
        unit = UNIT_MILLIAMPERE_HOUR,
        unit_string = "mAh",
        sensors = {
            sim = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0 },
            },
            crsfLegacy = nil,
        },
    },


    consumption = {
        name = i18n("telemetry.sensors.consumption"),
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 5,
        switch_alerts = true,
        unit = UNIT_MILLIAMPERE_HOUR,
        unit_string = "mAh",
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
        name = i18n("telemetry.sensors.governor"),
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 93,
        sensors = {
            sim = {
                { uid = 0x5009, unit = nil, dec = 0,
                  value = function() return rfsuite.utils.simSensors('governor') end,
                  min = 0, max = 200 },
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
        name = i18n("telemetry.sensors.adj_func"),
        mandatory = true,
        stats = false,
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
        name = i18n("telemetry.sensors.adj_val"),
        mandatory = true,
        stats = false,
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
        name = i18n("telemetry.sensors.pid_profile"),
        mandatory = true,
        stats = false,
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
        name = i18n("telemetry.sensors.rate_profile"),
        mandatory = true,
        stats = false,
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
        name = i18n("telemetry.sensors.throttle_pct"),
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 15,
        unit = UNIT_PERCENT,
        unit_string = "%",
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
        name = i18n("telemetry.sensors.armdisableflags"),
        mandatory = true,
        stats = false,
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
        name = i18n("telemetry.sensors.altitude"),
        mandatory = false,
        stats = true,
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
        localizations = function(value)
            local major = UNIT_METER
            if value == nil then return nil, major, nil end
            
            -- Shortcut to the user’s altitude‐unit preference (may be nil)
            local prefs = rfsuite.preferences.localizations
            local isFeet = prefs and prefs.altitude_unit == 1

            if isFeet then
                -- Convert from meters to feet
                return value * 3.28084, major, "ft"
            end

            -- Default: return meters
            return value, major, "m"
        end,
    },     

    -- Bec Voltage
    bec_voltage = {
        name = i18n("telemetry.sensors.bec_voltage"),
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 43,
        switch_alerts = true,
        unit = UNIT_VOLT,
        unit_string = "V",
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
        name = i18n("telemetry.sensors.cell_count"),
        mandatory = false,
        stats = false,
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

    -- Accellerometer X
    accx = {
        name = i18n("telemetry.sensors.accx"),
        mandatory = false,
        stats = false,
        set_telemetry_sensors = nil,
        sensors = {
            sim = {
                { uid = 0x5019, unit = UNIT_G, dec = 3,
                  value = function() return rfsuite.utils.simSensors('accx') end,
                  min = -4000, max = 4000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0700 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1111 },
            },
            crsfLegacy = { nil },
        },
    },  

    -- Accellerometer y
    accy = {
        name = i18n("telemetry.sensors.accy"),
        mandatory = false,
        stats = false,
        set_telemetry_sensors = nil,
        sensors = {
            sim = {
                { uid = 0x5020, unit = UNIT_G, dec = 3,
                  value = function() return rfsuite.utils.simSensors('accz') end,
                  min = -4000, max = 4000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0710 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1112 },
            },
            crsfLegacy = { nil },
        },
    },     

    -- Accellerometer z
    accz = {
        name = i18n("telemetry.sensors.accz"),
        mandatory = false,
        stats = false,
        set_telemetry_sensors = nil,
        sensors = {
            sim = {
                { uid = 0x5021, unit = UNIT_G, dec = 3,
                  value = function() return rfsuite.utils.simSensors('accz') end,
                  min = -4000, max = 4000 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0720 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1113},
            },
            crsfLegacy = { nil },
        },
    },  

    -- Attitude Yaw
    attyaw = {
        name = i18n("telemetry.sensors.attyaw"),
        mandatory = false,
        stats = false,
        set_telemetry_sensors = nil,
        sensors = {
            sim = {
                { uid = 0x5022, unit = UNIT_DEGREE, dec = 1,
                  value = function() return rfsuite.utils.simSensors('attyaw') end,
                  min = -1800, max = 3600 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5210 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1103},
            },
            crsfLegacy = { nil },
        },
    },  

    -- Attitude Yaw
    attroll = {
        name = i18n("telemetry.sensors.attroll"),
        mandatory = false,
        stats = false,
        set_telemetry_sensors = nil,
        sensors = {
            sim = {
                { uid = 0x5023, unit = UNIT_DEGREE, dec = 1,
                  value = function() return rfsuite.utils.simSensors('attroll') end,
                  min = -1800, max = 3600 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730 , subId = 0},
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1102},
            },
            crsfLegacy = { nil },
        },
    },     


    -- Attitude Pitch
    attpitch = {
        name = i18n("telemetry.sensors.attpitch"),
        mandatory = false,
        stats = false,
        set_telemetry_sensors = nil,
        sensors = {
            sim = {
                { uid = 0x5024, unit = UNIT_DEGREE, dec = 1,
                  value = function() return rfsuite.utils.simSensors('attpitch') end,
                  min = -1800, max = 3600 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730, subId = 1 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1101},
            },
            crsfLegacy = { nil },
        },
    },   

    -- Attitude Pitch
    groundspeed = {
        name = i18n("telemetry.sensors.groundspeed"),
        mandatory = false,
        stats = false,
        set_telemetry_sensors = nil,
        sensors = {
            sim = {
                { uid = 0x5025, unit = UNIT_KNOT, dec = 1,
                  value = function() return rfsuite.utils.simSensors('groundspeed') end,
                  min = -1800, max = 3600 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0830, subId = 1 },
            },
            crsf = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1128},
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
        table.insert(sensorList, {
            key = key,
            name = sensor.name,
            mandatory = sensor.mandatory,
            set_telemetry_sensors = sensor.set_telemetry_sensors
        })
    end
    return sensorList
end

--[[ 
    Function: telemetry.listSensorAudioUnits
    Returns a mapping of sensorKey → unit type, if defined.
]]
function telemetry.listSensorAudioUnits()
    local sensorMap = {}
    for key, sensor in pairs(sensorTable) do 
        if sensor.unit then
            sensorMap[key] = sensor.unit
        end    
    end
    return sensorMap
end

--[[ 
    Function: telemetry.listSwitchSensors
    Returns a list of sensors flagged for switch alerts.
]]
function telemetry.listSwitchSensors()
    local sensorList = {}
    for key, sensor in pairs(sensorTable) do 
        if sensor.switch_alerts then
            table.insert(sensorList, {
                key = key,
                name = sensor.name,
                mandatory = sensor.mandatory,
                set_telemetry_sensors = sensor.set_telemetry_sensors
            })
        end    
    end
    return sensorList
end

--[[ 
    Helper: Get the raw Source object for a given sensorKey, caching as we go.
]]
function telemetry.getSensorSource(name)
    if not sensorTable[name] then return nil end

    -- Return cached if available, bump it as hot:
    if sensors[name] then
        cache_hits = cache_hits + 1           -- debug: we hit the cache :contentReference[oaicite:0]{index=0}
        mark_hot(name)
        return sensors[name]
    end

    local function checkCondition(sensorEntry)
        if not (rfsuite.session and rfsuite.session.apiVersion) then
            return true
        end
        local roundedApiVersion = rfsuite.utils.round(rfsuite.session.apiVersion, 2)
        if sensorEntry.mspgt then
            return roundedApiVersion >= rfsuite.utils.round(sensorEntry.mspgt, 2)
        elseif sensorEntry.msplt then
            return roundedApiVersion <= rfsuite.utils.round(sensorEntry.msplt, 2)
        end
        return true
    end
    
    if system.getVersion().simulation == true then
        protocol = "sport"
        for _, sensor in ipairs(sensorTable[name].sensors.sim or {}) do
            -- handle sensors in regular formt
            if sensor.uid then
                if sensor and type(sensor) == "table" then
                    local sensorQ = { appId = sensor.uid, category = CATEGORY_TELEMETRY_SENSOR }
                    local source = system.getSource(sensorQ)
                    if source then
                        cache_misses = cache_misses + 1       -- debug: loaded from system.getSource :contentReference[oaicite:1]{index=1}
                        sensors[name] = source
                        mark_hot(name)
                        return source
                    end
                end
            else
                -- handle smart sensors / regular lookups    
                if checkCondition(sensor) and type(sensor) == "table" then
                    sensor.mspgt = nil
                    sensor.msplt = nil
                    local source = system.getSource(sensor)
                    if source then
                        cache_misses = cache_misses + 1       -- debug: loaded from system.getSource :contentReference[oaicite:1]{index=1}
                        sensors[name] = source
                        mark_hot(name)
                        return source
                    end
                end                
            end    
        end

    elseif rfsuite.session.telemetryType == "crsf" then
        if not crsfSOURCE then 
            crsfSOURCE = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = 0xEE01 }) 
        end
        if crsfSOURCE then
            protocol = "crsf"
            for _, sensor in ipairs(sensorTable[name].sensors.crsf or {}) do
                if checkCondition(sensor) and type(sensor) == "table" then
                    sensor.mspgt = nil
                    sensor.msplt = nil
                    local source = system.getSource(sensor)
                    if source then
                        cache_misses = cache_misses + 1       -- debug: loaded from system.getSource :contentReference[oaicite:1]{index=1}
                        sensors[name] = source
                        mark_hot(name)
                        return source
                    end
                end
            end
        else
            protocol = "crsfLegacy"
            for _, sensor in ipairs(sensorTable[name].sensors.crsfLegacy or {}) do
                local source = system.getSource(sensor)
                if source then
                    cache_misses = cache_misses + 1       -- debug: loaded from system.getSource :contentReference[oaicite:1]{index=1}
                    sensors[name] = source
                    mark_hot(name)
                    return source
                end
            end
        end

    elseif rfsuite.session.telemetryType == "sport" then
        protocol = "sport"
        for _, sensor in ipairs(sensorTable[name].sensors.sport or {}) do
            if checkCondition(sensor) and type(sensor) == "table" then
                sensor.mspgt = nil
                sensor.msplt = nil
                local source = system.getSource(sensor)
                if source then
                    cache_misses = cache_misses + 1       -- debug: loaded from system.getSource :contentReference[oaicite:1]{index=1}
                    sensors[name] = source
                    mark_hot(name)
                    return source
                end
            end
        end
    else
        protocol = "unknown"
    end

    return nil
end

--- Retrieves the value of a telemetry sensor by its key.
-- This function now supports both physical sensors (linked to telemetry sources)
-- and virtual/computed sensors (which define a `.source` function in sensorTable).
--
-- 1. If the sensorTable entry includes a `source` function (virtual/computed sensor),
--    this function is called and its `.value()` result is returned.
-- 2. Otherwise, attempts to resolve the sensor as a physical/real telemetry source.
--    If found, returns its value; otherwise, returns nil.
-- 3. If a `localizations` function is defined for the sensor, it is applied to
--    transform the raw value and resolve units as needed.
--
-- @param sensorKey The key identifying the telemetry sensor.
-- @return The sensor value (possibly transformed), primary unit (major), and secondary unit (minor) if available.
function telemetry.getSensor(sensorKey)
    local entry = sensorTable[sensorKey]

    if entry and type(entry.source) == "function" then
        local src = entry.source()
        if src and type(src.value) == "function" then
            local value, major, minor = src.value()
            major = major or entry.unit
            -- Optionally apply localization, if needed:
            if entry.localizations and type(entry.localizations) == "function" then
                value, major, minor = entry.localizations(value)
            end
            return value, major, minor
        end
    end

    -- Physical/real telemetry source
    local source = telemetry.getSensorSource(sensorKey)
    if not source then
        return nil
    end

    -- get initial defaults
    local value = source:value()
    local major = entry and entry.unit or nil
    local minor = nil

    -- if we have a transform function, apply it to the value:
    if entry and entry.transform and type(entry.transform) == "function" then
        value = entry.transform(value)
    end   

    -- if the sensor has a localization function, apply it to the value:
    if entry and entry.localizations and type(entry.localizations) == "function" then
        value, major, minor = entry.localizations(value)
    end

    return value, major, minor
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
    if (now - lastValidationTime) < VALIDATION_RATE_LIMIT then
        return lastValidationResult
    end
    lastValidationTime = now

    if not rfsuite.session.telemetryState then
        local allSensors = {}
        for key, sensor in pairs(sensorTable) do
            table.insert(allSensors, { key = key, name = sensor.name })
        end
        lastValidationResult = allSensors
        return allSensors
    end

    local resultSensors = {}
    for key, sensor in pairs(sensorTable) do
        local sensorSource = telemetry.getSensorSource(key)
        local isValid = (sensorSource ~= nil and sensorSource:state() ~= false)
        if returnValid then
            if isValid then
                table.insert(resultSensors, { key = key, name = sensor.name })
            end
        else
            if not isValid and sensor.mandatory ~= false then
                table.insert(resultSensors, { key = key, name = sensor.name })
            end
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

    This function is used to build a list of sensors that are available in 'simulation mode'
]]
function telemetry.simSensors(returnValid)
    local result = {}
    for key, sensor in pairs(sensorTable) do
        local name = sensor.name
        local firstSportSensor = sensor.sensors.sim and sensor.sensors.sim[1]
        if firstSportSensor then
            table.insert(result, { name = name, sensor = firstSportSensor })
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

--- Clears all cached sources and state.
function telemetry.reset()
    telemetrySOURCE, crsfSOURCE, protocol = nil, nil, nil
    sensors = {}
    hot_list, hot_index = {}, {}
    filteredOnchangeSensors = nil
    lastSensorValues = {}
    onchangeInitialized = false
    sensorRateLimit = os.clock()
    lastValidationResult = nil
    lastValidationTime = 0
    lastCacheFlushTime = os.clock()
    cache_hits, cache_misses = 0, 0
    --telemetry.sensorStats = {} -- we defer this to onconnect
end

--[[ 
    Primary wakeup() loop:
    - Prioritize MSP traffic
    - Rate-limit onchange scanning (once per second)
    - Periodic cache flush every 5s
    - Reset telemetry if needed
]]
function telemetry.wakeup()
    local now = os.clock()

    -- Prioritize MSP traffic
    if rfsuite.app.triggers.mspBusy then
        return
    end

    -- Rate‐limited “onchange” scanning (every ONCHANGE_RATE seconds)
    if (now - sensorRateLimit) >= ONCHANGE_RATE then
        sensorRateLimit = now

        -- Build reduced table of onchange‐capable sensors exactly once:
        if not filteredOnchangeSensors then
            filteredOnchangeSensors = {}
            for sensorKey, sensorDef in pairs(sensorTable) do
                if type(sensorDef.onchange) == "function" then
                    filteredOnchangeSensors[sensorKey] = sensorDef
                end
            end
            -- Mark that we just built the reduced table; skip invoking onchange this pass
            onchangeInitialized = true
        end

        -- If we just built the table on this pass, skip detection; next time, run normally
        if onchangeInitialized then
            onchangeInitialized = false
        else
            -- Now iterate only over filteredOnchangeSensors
            for sensorKey, sensorDef in pairs(filteredOnchangeSensors) do
                local source = telemetry.getSensorSource(sensorKey)
                if source and source:state() then
                    local val = source:value()
                    if lastSensorValues[sensorKey] ~= val then
                        -- Invoke onchange with the new value
                        sensorDef.onchange(val)
                        lastSensorValues[sensorKey] = val
                    end
                end
            end
        end
    end


    -- Reset if telemetry is inactive or telemetry type changed
    if not rfsuite.session.telemetryState or rfsuite.session.telemetryTypeChanged then
        telemetry.reset()
    end
end

-- retrieve min/max values for a sensor
function telemetry.getSensorStats(sensorKey)
    return telemetry.sensorStats[sensorKey] or { min = nil, max = nil }
end

-- allow sensor table to be accessed externally
telemetry.sensorTable = sensorTable

return telemetry