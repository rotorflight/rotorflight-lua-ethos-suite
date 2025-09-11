local sensorList = {
    [0]  = { sidElrs = 0x1000, sidSport = nil,     group = "system",   name = "NULL",          unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decNil },
    [1]  = { sidElrs = 0x1001, sidSport = 0x5100,  group = "system",   name = "Heartbeat",     unit = UNIT_RAW,     prec = 0, min = 0,    max = 60000,   dec = decU16 },

    [3]  = { sidElrs = 0x1011, sidSport = 0x0210,  group = "battery",  name = "Voltage",       unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [4]  = { sidElrs = 0x1012, sidSport = 0x0200,  group = "battery",  name = "Current",       unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [5]  = { sidElrs = 0x1013, sidSport = 0x5250,  group = "battery",  name = "Consumption",   unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [6]  = { sidElrs = 0x1014, sidSport = 0x0600,  group = "battery",  name = "Charge Level",  unit = UNIT_PERCENT, prec = 0, min = 0,    max = 100,     dec = decU8 },

    [7]  = { sidElrs = 0x1020, sidSport = 0x5260,  group = "battery",  name = "Cell Count",    unit = UNIT_RAW,     prec = 0, min = 0,    max = 16,      dec = decU8 },
    [8]  = { sidElrs = 0x1021, sidSport = 0x0910,  group = "battery",  name = "Cell Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 455,     dec = decCellV },
    [9]  = { sidElrs = 0x102F, sidSport = 0x0300,  group = "battery",  name = "Cell Voltages", unit = UNIT_VOLT,    prec = 2, min = nil,  max = nil,     dec = decCells },

    [10] = { sidElrs = 0x1030, sidSport = nil,     group = "control",  name = "Ctrl",          unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decControl },
    [11] = { sidElrs = 0x1031, sidSport = 0x51A0,  group = "control",  name = "Pitch Control", unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [12] = { sidElrs = 0x1032, sidSport = 0x51A1,  group = "control",  name = "Roll Control",  unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [13] = { sidElrs = 0x1033, sidSport = 0x51A2,  group = "control",  name = "Yaw Control",   unit = UNIT_DEGREE,  prec = 1, min = -900, max = 900,     dec = decS16 },
    [14] = { sidElrs = 0x1034, sidSport = 0x51A3,  group = "control",  name = "Coll Control",  unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [15] = { sidElrs = 0x1035, sidSport = 0x51A4,  group = "control",  name = "Throttle %",    unit = UNIT_PERCENT, prec = 0, min = -100, max = 100,     dec = decS8 },

    [17] = { sidElrs = 0x1041, sidSport = 0x0218,  group = "esc1",     name = "ESC1 Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [18] = { sidElrs = 0x1042, sidSport = 0x0208,  group = "esc1",     name = "ESC1 Current",  unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [19] = { sidElrs = 0x1043, sidSport = 0x5258,  group = "esc1",     name = "ESC1 Consump",  unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [20] = { sidElrs = 0x1044, sidSport = 0x0508,  group = "esc1",     name = "ESC1 eRPM",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU24 },
    [21] = { sidElrs = 0x1045, sidSport = 0x5268,  group = "esc1",     name = "ESC1 PWM",      unit = UNIT_PERCENT, prec = 1, min = 0,    max = 1000,    dec = decU16 },
    [22] = { sidElrs = 0x1046, sidSport = 0x5269,  group = "esc1",     name = "ESC1 Throttle", unit = UNIT_PERCENT, prec = 1, min = 0,    max = 1000,    dec = decU16 },
    [23] = { sidElrs = 0x1047, sidSport = 0x0418,  group = "esc1",     name = "ESC1 Temp",     unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [24] = { sidElrs = 0x1048, sidSport = 0x0419,  group = "esc1",     name = "ESC1 Temp 2",   unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [25] = { sidElrs = 0x1049, sidSport = 0x0219,  group = "esc1",     name = "ESC1 BEC Volt", unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1500,    dec = decU16 },
    [26] = { sidElrs = 0x104A, sidSport = 0x0229,  group = "esc1",     name = "ESC1 BEC Curr", unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 10000,   dec = decU16 },
    [27] = { sidElrs = 0x104E, sidSport = 0x5128,  group = "esc1",     name = "ESC1 Status",   unit = UNIT_RAW,     prec = 0, min = 0,    max = 2147483647, dec = decU32 },
    [28] = { sidElrs = 0x104F, sidSport = 0x5129,  group = "esc1",     name = "ESC1 Model ID", unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [30] = { sidElrs = 0x1051, sidSport = 0x021A,  group = "esc2",     name = "ESC2 Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [31] = { sidElrs = 0x1052, sidSport = 0x020A,  group = "esc2",     name = "ESC2 Current",  unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [32] = { sidElrs = 0x1053, sidSport = 0x525A,  group = "esc2",     name = "ESC2 Consump",  unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [33] = { sidElrs = 0x1054, sidSport = 0x050A,  group = "esc2",     name = "ESC2 eRPM",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU24 },
    [36] = { sidElrs = 0x1057, sidSport = 0x041A,  group = "esc2",     name = "ESC2 Temp",     unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [41] = { sidElrs = 0x105F, sidSport = 0x512B,  group = "esc2",     name = "ESC2 Model ID", unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [42] = { sidElrs = 0x1080, sidSport = 0x0211,  group = "voltage",  name = "ESC Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [43] = { sidElrs = 0x1081, sidSport = 0x0901,  group = "voltage",  name = "BEC Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1600,    dec = decU16 },
    [44] = { sidElrs = 0x1082, sidSport = 0x0902,  group = "voltage",  name = "BUS Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1200,    dec = decU16 },
    [45] = { sidElrs = 0x1083, sidSport = 0x0900,  group = "voltage",  name = "MCU Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 500,     dec = decU16 },

    [46] = { sidElrs = 0x1090, sidSport = 0x0201,  group = "current",  name = "ESC Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [47] = { sidElrs = 0x1091, sidSport = 0x0222,  group = "current",  name = "BEC Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 10000,   dec = decU16 },
    [48] = { sidElrs = 0x1092, sidSport = nil,     group = "current",  name = "BUS Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 1000,    dec = decU16 },
    [49] = { sidElrs = 0x1093, sidSport = nil,     group = "current",  name = "MCU Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 1000,    dec = decU16 },

    [50] = { sidElrs = 0x10A0, sidSport = 0x0401,  group = "temps",    name = "ESC Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [51] = { sidElrs = 0x10A1, sidSport = 0x0402,  group = "temps",    name = "BEC Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [52] = { sidElrs = 0x10A3, sidSport = 0x0400,  group = "temps",    name = "MCU Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },

    [57] = { sidElrs = 0x10B1, sidSport = 0x5210,  group = "gyro",     name = "Heading",       unit = UNIT_DEGREE,  prec = 1, min = -1800, max = 3600,   dec = decS16 },
    [58] = { sidElrs = 0x10B2, sidSport = 0x0100,  group = "barometer",name = "Altitude",      unit = UNIT_METER,   prec = 2, min = -100000, max = 100000, dec = decS24 },
    [59] = { sidElrs = 0x10B3, sidSport = 0x0110,  group = "barometer",name = "VSpeed",        unit = UNIT_METER_PER_SECOND, prec = 2, min = -10000, max = 10000, dec = decS16 },

    [60] = { sidElrs = 0x10C0, sidSport = 0x0500,  group = "rpm",      name = "Headspeed",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU16 },
    [61] = { sidElrs = 0x10C1, sidSport = 0x0501,  group = "rpm",      name = "Tailspeed",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU16 },

    [64] = { sidElrs = 0x1100, sidSport = nil,     group = "gyro",     name = "Attd",          unit = UNIT_DEGREE,  prec = 1, min = nil,  max = nil,     dec = decAttitude },
    [65] = { sidElrs = 0x1101, sidSport = 0x0730,  group = "gyro",     name = "Pitch Attitude",unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },
    [66] = { sidElrs = 0x1102, sidSport = 0x0730,  group = "gyro",     name = "Roll Attitude", unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },
    [67] = { sidElrs = 0x1103, sidSport = nil,     group = "gyro",     name = "Yaw Attitude",  unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },

    [68] = { sidElrs = 0x1110, sidSport = nil,     group = "gyro",     name = "Accl",          unit = UNIT_G,       prec = 2, min = nil,  max = nil,     dec = decAccel },
    [69] = { sidElrs = 0x1111, sidSport = 0x0700,  group = "gyro",     name = "Accel X",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },
    [70] = { sidElrs = 0x1112, sidSport = 0x0710,  group = "gyro",     name = "Accel Y",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },
    [71] = { sidElrs = 0x1113, sidSport = 0x0720,  group = "gyro",     name = "Accel Z",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },

    [73] = { sidElrs = 0x1121, sidSport = nil,     group = "gps",      name = "GPS Sats",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [74] = { sidElrs = 0x1122, sidSport = nil,     group = "gps",      name = "GPS PDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [75] = { sidElrs = 0x1123, sidSport = nil,     group = "gps",      name = "GPS HDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [76] = { sidElrs = 0x1124, sidSport = nil,     group = "gps",      name = "GPS VDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [77] = { sidElrs = 0x1125, sidSport = 0x0800,  group = "gps",      name = "GPS Coord",     unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decLatLong },
    [78] = { sidElrs = 0x1126, sidSport = 0x0820,  group = "gps",      name = "GPS Altitude",  unit = UNIT_METER,   prec = 2, min = -100000000, max = 100000000, dec = decS16 },
    [79] = { sidElrs = 0x1127, sidSport = 0x0840,  group = "gps",      name = "GPS Heading",   unit = UNIT_DEGREE,  prec = 1, min = -1800, max = 3600,   dec = decS16 },
    [80] = { sidElrs = 0x1128, sidSport = 0x0830,  group = "gps",      name = "GPS Speed",     unit = UNIT_METER_PER_SECOND, prec = 2, min = 0, max = 10000, dec = decU16 },
    [81] = { sidElrs = 0x1129, sidSport = nil,     group = "gps",      name = "GPS Home Dist", unit = UNIT_METER,   prec = 1, min = 0,    max = 65535,   dec = decU16 },
    [82] = { sidElrs = 0x112A, sidSport = nil,     group = "gps",      name = "GPS Home Dir",  unit = UNIT_METER,   prec = 1, min = 0,    max = 3600,    dec = decU16 },

    [85] = { sidElrs = 0x1141, sidSport = 0x51D0,  group = "system",   name = "CPU Load",      unit = UNIT_PERCENT, prec = 0, min = 0,    max = 100,     dec = decU8 },
    [86] = { sidElrs = 0x1142, sidSport = 0x51D1,  group = "system",   name = "SYS Load",      unit = UNIT_PERCENT, prec = 0, min = 0,    max = 10,      dec = decU8 },
    [87] = { sidElrs = 0x1143, sidSport = 0x51D2,  group = "system",   name = "RT Load",       unit = UNIT_PERCENT, prec = 0, min = 0,    max = 200,     dec = decU8 },

    [88] = { sidElrs = 0x1200, sidSport = 0x5120,  group = "status",   name = "Model ID",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [89] = { sidElrs = 0x1201, sidSport = 0x5121,  group = "status",   name = "Flight Mode",   unit = UNIT_RAW,     prec = 0, min = 0,    max = 65535,   dec = decU16 },
    [90] = { sidElrs = 0x1202, sidSport = 0x5122,  group = "status",   name = "Arming Flags",  unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [91] = { sidElrs = 0x1203, sidSport = 0x5123,  group = "status",   name = "Arming Disable",unit = UNIT_RAW,     prec = 0, min = 0,    max = 2147483647, dec = decU32 },
    [92] = { sidElrs = 0x1204, sidSport = 0x5124,  group = "status",   name = "Rescue",        unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [93] = { sidElrs = 0x1205, sidSport = 0x5125,  group = "status",   name = "Governor",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [95] = { sidElrs = 0x1211, sidSport = 0x5130,  group = "profiles", name = "PID Profile",   unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },
    [96] = { sidElrs = 0x1212, sidSport = 0x5131,  group = "profiles", name = "Rate Profile",  unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },
    [98] = { sidElrs = 0x1213, sidSport = nil,     group = "profiles", name = "LED Profile",   unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },

    [99] = { sidElrs = 0x1220, sidSport = 0x5110,  group = "status",   name = "ADJ",           unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decAdjFunc },

    -- Debug
    [100] = { sidElrs = 0xDB00, sidSport = nil,    group = "debug",    name = "DBG0",          unit = UNIT_RAW,     prec = 0, dec = decS32 },
    [101] = { sidElrs = 0xDB01, sidSport = nil,    group = "debug",    name = "DBG1",          unit = UNIT_RAW,     prec = 0, dec = decS32 },
    [102] = { sidElrs = 0xDB02, sidSport = nil,    group = "debug",    name = "DBG2",          unit = UNIT_RAW,     prec = 0, dec = decS32 },
    [103] = { sidElrs = 0xDB03, sidSport = nil,    group = "debug",    name = "DBG3",          unit = UNIT_RAW,     prec = 0, dec = decS32 },
    [104] = { sidElrs = 0xDB04, sidSport = nil,    group = "debug",    name = "DBG4",          unit = UNIT_RAW,     prec = 0, dec = decS32 },
    [105] = { sidElrs = 0xDB05, sidSport = nil,    group = "debug",    name = "DBG5",          unit = UNIT_RAW,     prec = 0, dec = decS32 },
    [106] = { sidElrs = 0xDB06, sidSport = nil,    group = "debug",    name = "DBG6",          unit = UNIT_RAW,     prec = 0, dec = decS32 },
    [107] = { sidElrs = 0xDB07, sidSport = nil,    group = "debug",    name = "DBG7",          unit = UNIT_RAW,     prec = 0, dec = decS32 },
}

return sensorList