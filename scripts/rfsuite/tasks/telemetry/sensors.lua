local i18n = rfsuite.i18n.get

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
        transform = function(value)
            -- If local calculation is enabled, calculate mAh used based on capacity
            if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.calc_local then
                if rfsuite.session.modelPreferences.battery.calc_local == 1 then
                    local capacity = rfsuite.session.batteryConfig.batteryCapacity or 1000 -- Default to 1000mAh if not set
                    local smartfuel = rfsuite.tasks.telemetry.getSensor("smartfuel")
                    local warningPercentage = rfsuite.session.batteryConfig.consumptionWarningPercentage or 30
                    if smartfuel then
                        local usableCapacity = capacity * (1 - warningPercentage / 100)
                        local usedPercent = 100 - smartfuel -- how much has been used
                        return (usedPercent / 100) * usableCapacity
                    end
                end
            end

            return nil
        end
  
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

return sensorTable