return {
    -- RSSI and Link
    rssi = {{crsfId = 0x14, subId = 2}},
    link = {{crsfId = 0x14, subIdStart = 0, subIdEnd = 1}, "Rx RSSI1"},
    vfr = {{crsfId = 0x14, subId = 2}},

    -- Flags
    armflags = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1202}},
    armdisableflags = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1203}},

    -- Power
    voltage = {
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011},
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1041},
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1051},
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1080},
        {crsfId = 8},
    },
    current = {
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012},
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042},
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x104A},
    },
    bec_voltage = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1081}, {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1049}},

    -- Fuel
    fuel = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014}},
    smartfuel = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1}},
    smartconsumption = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0}},
    consumption = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013}},

    -- Temperature
    temp_esc = {
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0},
        {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1047},
    },
    temp_mcu = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3}},

    -- Motor/Rotor
    rpm = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0}},
    governor = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205}},

    -- Adjustments & Profiles
    adj_f = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221}},
    adj_v = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222}},
    pid_profile = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211}},
    rate_profile = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212}},

    -- Control
    throttle_percent = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035}},

    -- Navigation
    altitude = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10B2}},
    groundspeed = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1128}},

    -- Attitude
    attroll = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1102}},
    attpitch = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1101}},
    attyaw = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1103}},

    -- Acceleration
    accx = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1111}},
    accy = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1112}},
    accz = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1113}},

    -- Battery
    cell_count = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1020}},
}
