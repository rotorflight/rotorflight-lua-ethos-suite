--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * Optimized version: reduced allocations, fewer global lookups, safer cache reset,
 * bug fixes (weak table reset; accy sim sensor typo), and light memoization.
 * Retains existing functionality/IO while lowering CPU & RAM.
]]

local arg = {...}
local config = arg[1]
local i18n = rfsuite.i18n.get
local simSensors = rfsuite.utils.simSensors
local round = rfsuite.utils.round

local telemetry = {}

-- ========= Fast locals for frequently used globals (cuts table lookups) =========
local os_clock       = os.clock
local sys_getSource  = system.getSource
local sys_getVersion = system.getVersion
local t_insert       = table.insert
local t_remove       = table.remove
local t_pairs        = pairs
local t_ipairs       = ipairs
local t_type         = type

local protocol, crsfSOURCE

-- sensor cache: weak values so GC can drop cold sources
local sensors   = setmetatable({}, { __mode = "v" })

-- debug counters
local cache_hits, cache_misses = 0, 0

-- LRU for hot sources (smaller = lower RAM footprint)
local HOT_SIZE  = 20
local hot_list, hot_index = {}, {}

local function mark_hot(key)
  local idx = hot_index[key]
  if idx then
    t_remove(hot_list, idx)
  elseif #hot_list >= HOT_SIZE then
    local old = t_remove(hot_list, 1)
    hot_index[old] = nil
    sensors[old] = nil -- evict the old sensor so cache size ≤ HOT_SIZE
  end
  t_insert(hot_list, key)
  hot_index[key] = #hot_list
end

function telemetry._debugStats()
  return { hits = cache_hits, misses = cache_misses, hot_size = #hot_list, hot_list = hot_list }
end

-- Rate‐limiting for wakeup()
local sensorRateLimit = os_clock()
local ONCHANGE_RATE = 0.5        -- seconds between onchange scans

-- Store the last validated sensors and timestamp
local lastValidationResult = nil
local lastValidationTime   = 0
local VALIDATION_RATE_LIMIT = 10  -- seconds

local telemetryState = false

-- Store last seen values for each sensor (by key)
local lastSensorValues = {}

telemetry.sensorStats = {}

-- Memoized list data (recomputed on reset)
local memo_listSensors, memo_listSwitchSensors, memo_listAudioUnits = nil, nil, nil

-- For “reduced table” of onchange‐capable sensors:
local filteredOnchangeSensors = nil
local onchangeInitialized     = false

-- ============================== Sensor table ===============================
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

    -- Link
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
                "RSSI",
            },
            crsf = {
                { crsfId = 0x14, subIdStart = 0, subIdEnd = 1 },
                "Rx RSSI1",
            },
            crsfLegacy = {
                { crsfId = 0x14, subIdStart = 0, subIdEnd = 1 },
                "RSSI 1",
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
                  value = function() return simSensors('armflags') end,
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
            rfsuite.session.isArmed = (value == 1 or value == 3)
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
                  value = function() return simSensors('voltage') end,
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
                  value = function() return simSensors('rpm') end,
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
                  value = function() return simSensors('current') end,
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
                  value = function() return simSensors('temp_esc') end,
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
        localizations = function(value, paramMin, paramMax, paramThresholds)
            if value == nil then return nil, UNIT_DEGREE, nil, paramMin, paramMax, paramThresholds end

            local min = paramMin or 0
            local max = paramMax or 100
            local thresholds = paramThresholds

            local prefs = rfsuite.preferences.localizations
            local isFahrenheit = prefs and prefs.temperature_unit == 1

            local function convertThresholds(thrs, conv)
                if not thrs then return nil end
                local result = {}
                for i, t in t_ipairs(thrs) do
                    local copy = {}
                    for k, v in t_pairs(t) do copy[k] = v end
                    if t_type(copy.value) == "number" then
                        copy.value = conv(copy.value)
                    end
                    t_insert(result, copy)
                end
                return result
            end

            if isFahrenheit then
                return value * 1.8 + 32, UNIT_DEGREE, "°F",
                    min * 1.8 + 32, max * 1.8 + 32,
                    convertThresholds(thresholds, function(v) return v * 1.8 + 32 end)
            end
            return value, UNIT_DEGREE, "°C", min, max, thresholds
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
                  value = function() return simSensors('temp_mcu') end,
                  min = 0, max = 100 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400, mspgt = 12.08 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401, msplt = 12.07 },
            },
            crsf = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3 }, },
            crsfLegacy = { "GPS Sats" },
        },
        localizations = function(value, paramMin, paramMax, paramThresholds)
            if value == nil then return nil, UNIT_DEGREE, nil, paramMin, paramMax, paramThresholds end
            local min = paramMin or 0
            local max = paramMax or 100
            local thresholds = paramThresholds
            local prefs = rfsuite.preferences.localizations
            local isFahrenheit = prefs and prefs.temperature_unit == 1
            local function convertThresholds(thrs, conv)
                if not thrs then return nil end
                local result = {}
                for i, t in t_ipairs(thrs) do
                    local copy = {}
                    for k, v in t_pairs(t) do copy[k] = v end
                    if t_type(copy.value) == "number" then copy.value = conv(copy.value) end
                    t_insert(result, copy)
                end
                return result
            end
            if isFahrenheit then
                return value * 1.8 + 32, UNIT_DEGREE, "°F",
                    min * 1.8 + 32, max * 1.8 + 32,
                    convertThresholds(thresholds, function(v) return v * 1.8 + 32 end)
            end
            return value, UNIT_DEGREE, "°C", min, max, thresholds
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
                { uid = 0x5007, unit = UNIT_PERCENT, dec = 0,
                  value = function() return simSensors('fuel') end,
                  min = 0, max = 100 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014 }, },
            crsfLegacy = { "Rx Batt%" },
        },
    },

    smartfuel = {
        name = i18n("telemetry.sensors.smartfuel"),
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_PERCENT, unit_string = "%",
        sensors = { sim = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1 }, },
                    sport= { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1 }, },
                    crsf = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1 }, },
                    crsfLegacy = nil },
    },

    smartconsumption = {
        name = i18n("telemetry.sensors.smartconsumption"),
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_MILLIAMPERE_HOUR, unit_string = "mAh",
        sensors = { sim = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0 }, },
                    sport= { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0 }, },
                    crsf = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0 }, },
                    crsfLegacy = nil },
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
                  value = function() return simSensors('consumption') end,
                  min = 0, max = 5000 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013 }, },
            crsfLegacy = { "Rx Cons" },
        },
    },

    governor = {
        name = i18n("telemetry.sensors.governor"),
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 93,
        sensors = {
            sim = {
                { uid = 0x5009, unit = nil, dec = 0,
                  value = function() return simSensors('governor') end,
                  min = 0, max = 200 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5125 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450 },
            },
            crsf = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205 }, },
            crsfLegacy = { "Flight mode" },
        },
    },

    adj_f = {
        name = i18n("telemetry.sensors.adj_func"),
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 99,
        sensors = {
            sim = {
                { uid = 0x5010, unit = nil, dec = 0,
                  value = function() return simSensors('adj_f') end,
                  min = 0, max = 10 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221 }, },
            crsfLegacy = { nil },
        },
    },

    adj_v = {
        name = i18n("telemetry.sensors.adj_val"),
        mandatory = true,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5011, unit = nil, dec = 0,
                  value = function() return simSensors('adj_v') end,
                  min = 0, max = 2000 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222 }, },
            crsfLegacy = { nil },
        },
    },

    pid_profile = {
        name = i18n("telemetry.sensors.pid_profile"),
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 95,
        sensors = {
            sim = { { uid = 0x5012, unit = nil, dec = 0,
                      value = function() return simSensors('pid_profile') end,
                      min = 0, max = 6 }, },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5130 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471 },
            },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211 }, },
            crsfLegacy = { nil },
        },
    },

    rate_profile = {
        name = i18n("telemetry.sensors.rate_profile"),
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 96,
        sensors = {
            sim = { { uid = 0x5013, unit = nil, dec = 0,
                      value = function() return simSensors('rate_profile') end,
                      min = 0, max = 6 }, },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5131 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472 },
            },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212 }, },
            crsfLegacy = { nil },
        },
    },

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
                  value = function() return simSensors('throttle_percent') end,
                  min = 0, max = 100 },
            },
            sport = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4 },
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5269 },
            },
            crsf = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035 }, },
            crsfLegacy = { nil },
        },
    },

    armdisableflags = {
        name = i18n("telemetry.sensors.armdisableflags"),
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 91,
        sensors = {
            sim = {
                { uid = 0x5015, unit = nil, dec = nil,
                  value = function() return simSensors('armdisableflags') end,
                  min = 0, max = 65536 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5123 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1203 }, },
            crsfLegacy = { nil },
        },
    },

    altitude = {
        name = i18n("telemetry.sensors.altitude"),
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_METER,
        sensors = {
            sim = {
                { uid = 0x5016, unit = UNIT_METER, dec = 0,
                  value = function() return simSensors('altitude') end,
                  min = 0, max = 50000 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0100 } },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10B2 }, },
            crsfLegacy = { nil },
        },
        localizations = function(value)
            local major = UNIT_METER
            if value == nil then return nil, major, nil end
            local prefs = rfsuite.preferences.localizations
            local isFeet = prefs and prefs.altitude_unit == 1
            if isFeet then return value * 3.28084, major, "ft" end
            return value, major, "m"
        end,
    },

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
                  value = function() return simSensors('bec_voltage') end,
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

    cell_count = {
        name = i18n("telemetry.sensors.cell_count"),
        mandatory = false,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5018, unit = nil, dec = 0,
                  value = function() return simSensors('cell_count') end,
                  min = 0, max = 50 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5260 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1020 }, },
            crsfLegacy = { nil },
        },
    },

    accx = {
        name = i18n("telemetry.sensors.accx"),
        mandatory = false,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5019, unit = UNIT_G, dec = 3,
                  value = function() return simSensors('accx') end,
                  min = -4000, max = 4000 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0700 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1111 }, },
            crsfLegacy = { nil },
        },
    },

    accy = {
        name = i18n("telemetry.sensors.accy"),
        mandatory = false,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5020, unit = UNIT_G, dec = 3,
                  value = function() return simSensors('accy') end, -- fixed typo
                  min = -4000, max = 4000 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0710 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1112 }, },
            crsfLegacy = { nil },
        },
    },

    accz = {
        name = i18n("telemetry.sensors.accz"),
        mandatory = false,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5021, unit = UNIT_G, dec = 3,
                  value = function() return simSensors('accz') end,
                  min = -4000, max = 4000 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0720 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1113 }, },
            crsfLegacy = { nil },
        },
    },

    attyaw = {
        name = i18n("telemetry.sensors.attyaw"),
        mandatory = false,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5022, unit = UNIT_DEGREE, dec = 1,
                  value = function() return simSensors('attyaw') end,
                  min = -1800, max = 3600 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5210 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1103 }, },
            crsfLegacy = { nil },
        },
    },

    attroll = {
        name = i18n("telemetry.sensors.attroll"),
        mandatory = false,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5023, unit = UNIT_DEGREE, dec = 1,
                  value = function() return simSensors('attroll') end,
                  min = -1800, max = 3600 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730 , subId = 0}, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1102 }, },
            crsfLegacy = { nil },
        },
    },

    attpitch = {
        name = i18n("telemetry.sensors.attpitch"),
        mandatory = false,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5024, unit = UNIT_DEGREE, dec = 1,
                  value = function() return simSensors('attpitch') end,
                  min = -1800, max = 3600 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730, subId = 1 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1101 }, },
            crsfLegacy = { nil },
        },
    },

    groundspeed = {
        name = i18n("telemetry.sensors.groundspeed"),
        mandatory = false,
        stats = false,
        sensors = {
            sim = {
                { uid = 0x5025, unit = UNIT_KNOT, dec = 1,
                  value = function() return simSensors('groundspeed') end,
                  min = -1800, max = 3600 },
            },
            sport = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0830, subId = 1 }, },
            crsf  = { { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1128 }, },
            crsfLegacy = { nil },
        },
    },
}

-- ============================== Public helpers =============================
function telemetry.getSensorProtocol()
    return protocol
end

local function build_memo_lists()
    -- Called on first demand and on reset.
    memo_listSensors, memo_listSwitchSensors, memo_listAudioUnits = {}, {}, {}
    for key, sensor in t_pairs(sensorTable) do
        t_insert(memo_listSensors, {
            key = key,
            name = sensor.name,
            mandatory = sensor.mandatory,
            set_telemetry_sensors = sensor.set_telemetry_sensors
        })
        if sensor.switch_alerts then
            t_insert(memo_listSwitchSensors, {
                key = key,
                name = sensor.name,
                mandatory = sensor.mandatory,
                set_telemetry_sensors = sensor.set_telemetry_sensors
            })
        end
        if sensor.unit then memo_listAudioUnits[key] = sensor.unit end
    end
end

function telemetry.listSensors()
    if not memo_listSensors then build_memo_lists() end
    return memo_listSensors
end

function telemetry.listSensorAudioUnits()
    if not memo_listAudioUnits then build_memo_lists() end
    return memo_listAudioUnits
end

function telemetry.listSwitchSensors()
    if not memo_listSwitchSensors then build_memo_lists() end
    return memo_listSwitchSensors
end

-- Helper: check MSP version gating quickly
local function checkCondition(sensorEntry)
    local sess = rfsuite.session
    if not (sess and sess.apiVersion) then return true end
    local roundedApiVersion = round(sess.apiVersion, 2)
    local gt, lt = sensorEntry.mspgt, sensorEntry.msplt
    if gt then return roundedApiVersion >= round(gt, 2) end
    if lt then return roundedApiVersion <= round(lt, 2) end
    return true
end

-- Helper: get cached raw Source object for a given sensorKey
function telemetry.getSensorSource(name)
    local entry = sensorTable[name]
    if not entry then return nil end

    local src = sensors[name]
    if src then
        cache_hits = cache_hits + 1
        mark_hot(name)
        return src
    end

    -- Only call sys_getVersion() once per miss
    local isSim = sys_getVersion().simulation == true

    if isSim then
        protocol = "sport"
        for _, sensor in t_ipairs(entry.sensors.sim or {}) do
            if sensor.uid then
                local sensorQ = { appId = sensor.uid, category = CATEGORY_TELEMETRY_SENSOR }
                local source = sys_getSource(sensorQ)
                if source then
                    cache_misses = cache_misses + 1
                    sensors[name] = source
                    mark_hot(name)
                    return source
                end
            else
                if checkCondition(sensor) and t_type(sensor) == "table" then
                    sensor.mspgt, sensor.msplt = nil, nil -- strip once after check
                    local source = sys_getSource(sensor)
                    if source then
                        cache_misses = cache_misses + 1
                        sensors[name] = source
                        mark_hot(name)
                        return source
                    end
                end
            end
        end

    elseif rfsuite.session.telemetryType == "crsf" then
        if not crsfSOURCE then crsfSOURCE = sys_getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = 0xEE01 }) end
        if crsfSOURCE then
            protocol = "crsf"
            for _, sensor in t_ipairs(entry.sensors.crsf or {}) do
                if checkCondition(sensor) and t_type(sensor) == "table" then
                    sensor.mspgt, sensor.msplt = nil, nil
                    local source = sys_getSource(sensor)
                    if source then
                        cache_misses = cache_misses + 1
                        sensors[name] = source
                        mark_hot(name)
                        return source
                    end
                end
            end
        else
            protocol = "crsfLegacy"
            for _, sensor in t_ipairs(entry.sensors.crsfLegacy or {}) do
                local source = sys_getSource(sensor)
                if source then
                    cache_misses = cache_misses + 1
                    sensors[name] = source
                    mark_hot(name)
                    return source
                end
            end
        end

    elseif rfsuite.session.telemetryType == "sport" then
        protocol = "sport"
        for _, sensor in t_ipairs(entry.sensors.sport or {}) do
            if checkCondition(sensor) and t_type(sensor) == "table" then
                sensor.mspgt, sensor.msplt = nil, nil
                local source = sys_getSource(sensor)
                if source then
                    cache_misses = cache_misses + 1
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

-- Retrieves the (possibly localized) value of a telemetry sensor by its key.
function telemetry.getSensor(sensorKey, paramMin, paramMax, paramThresholds)
    local entry = sensorTable[sensorKey]

    if entry and t_type(entry.source) == "function" then
        local src = entry.source()
        if src and t_type(src.value) == "function" then
            local value, major, minor = src.value()
            major = major or entry.unit
            if entry.localizations and t_type(entry.localizations) == "function" then
                value, major, minor = entry.localizations(value)
            end
            return value, major, minor
        end
    end

    local source = telemetry.getSensorSource(sensorKey)
    if not source then return nil end

    local value = source:value()
    local major = entry and entry.unit or nil
    local minor = nil

    if entry and entry.transform and t_type(entry.transform) == "function" then
        value = entry.transform(value)
    end

    if entry and entry.localizations and t_type(entry.localizations) == "function" then
        return entry.localizations(value, paramMin, paramMax, paramThresholds)
    end

    return value, major, minor, paramMin, paramMax, paramThresholds
end

-- Validate sensors with light rate limiting + memoization when telemetry is inactive
function telemetry.validateSensors(returnValid)
    local now = os_clock()
    if (now - lastValidationTime) < VALIDATION_RATE_LIMIT then
        return lastValidationResult or true
    end
    lastValidationTime = now

    if not rfsuite.session.telemetryState then
        if not memo_listSensors then build_memo_lists() end
        lastValidationResult = memo_listSensors
        return memo_listSensors
    end

    local resultSensors = {}
    for key, sensor in t_pairs(sensorTable) do
        local sensorSource = telemetry.getSensorSource(key)
        local isValid = (sensorSource ~= nil and sensorSource:state() ~= false)
        if returnValid then
            if isValid then t_insert(resultSensors, { key = key, name = sensor.name }) end
        else
            if not isValid and sensor.mandatory ~= false then
                t_insert(resultSensors, { key = key, name = sensor.name })
            end
        end
    end

    lastValidationResult = resultSensors
    return resultSensors
end

-- Build list of available sim sensors
function telemetry.simSensors(returnValid)
    local result = {}
    for _, sensor in t_pairs(sensorTable) do
        local firstSim = sensor.sensors.sim and sensor.sensors.sim[1]
        if firstSim then t_insert(result, { name = sensor.name, sensor = firstSim }) end
    end
    return result
end

function telemetry.active()
    return rfsuite.session.telemetryState or false
end

-- Clears all cached sources and state.
function telemetry.reset()
    protocol, crsfSOURCE = nil, nil
    sensors = setmetatable({}, { __mode = "v" }) -- keep weak values on reset
    hot_list, hot_index = {}, {}
    filteredOnchangeSensors = nil
    lastSensorValues = {}
    onchangeInitialized = false
    sensorRateLimit = os_clock()
    lastValidationResult = nil
    lastValidationTime = 0
    cache_hits, cache_misses = 0, 0
    memo_listSensors, memo_listSwitchSensors, memo_listAudioUnits = nil, nil, nil
end

-- Primary wakeup() loop
function telemetry.wakeup()
    local now = os_clock()

    -- Prioritize MSP traffic
    if rfsuite.app.triggers.mspBusy then return end

    -- Rate‐limited “onchange” scanning
    if (now - sensorRateLimit) >= ONCHANGE_RATE then
        sensorRateLimit = now

        if not filteredOnchangeSensors then
            filteredOnchangeSensors = {}
            for sensorKey, sensorDef in t_pairs(sensorTable) do
                if t_type(sensorDef.onchange) == "function" then
                    filteredOnchangeSensors[sensorKey] = sensorDef
                end
            end
            onchangeInitialized = true
        end

        if onchangeInitialized then
            onchangeInitialized = false
        else
            for sensorKey, sensorDef in t_pairs(filteredOnchangeSensors) do
                local source = telemetry.getSensorSource(sensorKey)
                if source and source:state() then
                    local val = source:value()
                    if lastSensorValues[sensorKey] ~= val then
                        sensorDef.onchange(val)
                        lastSensorValues[sensorKey] = val
                    end
                end
            end
        end
    end

    -- Reset if telemetry is inactive or telemetry type changed
    if (not rfsuite.session.telemetryState) or rfsuite.session.telemetryTypeChanged then
        telemetry.reset()
    end
end

-- retrieve min/max values for a sensor
function telemetry.getSensorStats(sensorKey)
    return telemetry.sensorStats[sensorKey] or { min = nil, max = nil }
end

telemetry.sensorTable = sensorTable

return telemetry
