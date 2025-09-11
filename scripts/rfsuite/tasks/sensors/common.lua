elrs.RFSensors = {
    [0]  = { sidElrs = 0x1000, sidSport = nil,     name = "NULL",          unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decNil },
    [1]  = { sidElrs = 0x1001, sidSport = 0x5100,  name = "Heartbeat",     unit = UNIT_RAW,     prec = 0, min = 0,    max = 60000,   dec = decU16 },

    [3]  = { sidElrs = 0x1011, sidSport = 0x0210,  name = "Voltage",       unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [4]  = { sidElrs = 0x1012, sidSport = nil,     name = "Current",       unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [5]  = { sidElrs = 0x1013, sidSport = 0x5250,  name = "Consumption",   unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [6]  = { sidElrs = 0x1014, sidSport = 0x0600,  name = "Charge Level",  unit = UNIT_PERCENT, prec = 0, min = 0,    max = 100,     dec = decU8 },

    [7]  = { sidElrs = 0x1020, sidSport = 0x5260,  name = "Cell Count",    unit = UNIT_RAW,     prec = 0, min = 0,    max = 16,      dec = decU8 },
    [8]  = { sidElrs = 0x1021, sidSport = 0x0910,  name = "Cell Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 455,     dec = decCellV },
    [9]  = { sidElrs = 0x102F, sidSport = nil,     name = "Cell Voltages", unit = UNIT_VOLT,    prec = 2, min = nil,  max = nil,     dec = decCells },

    [10] = { sidElrs = 0x1030, sidSport = nil,     name = "Ctrl",          unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decControl },
    [11] = { sidElrs = 0x1031, sidSport = 0x51A0,  name = "Pitch Control", unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [12] = { sidElrs = 0x1032, sidSport = 0x51A1,  name = "Roll Control",  unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [13] = { sidElrs = 0x1033, sidSport = 0x51A2,  name = "Yaw Control",   unit = UNIT_DEGREE,  prec = 1, min = -900, max = 900,     dec = decS16 },
    [14] = { sidElrs = 0x1034, sidSport = 0x51A3,  name = "Coll Control",  unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [15] = { sidElrs = 0x1035, sidSport = 0x51A4,  name = "Throttle %",    unit = UNIT_PERCENT, prec = 0, min = -100, max = 100,     dec = decS8 },

    [17] = { sidElrs = 0x1041, sidSport = 0x0218,  name = "ESC1 Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [18] = { sidElrs = 0x1042, sidSport = 0x0208,  name = "ESC1 Current",  unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [19] = { sidElrs = 0x1043, sidSport = 0x5258,  name = "ESC1 Consump",  unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [20] = { sidElrs = 0x1044, sidSport = 0x0508,  name = "ESC1 eRPM",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU24 },
    [21] = { sidElrs = 0x1045, sidSport = 0x5268,  name = "ESC1 PWM",      unit = UNIT_PERCENT, prec = 1, min = 0,    max = 1000,    dec = decU16 },
    [22] = { sidElrs = 0x1046, sidSport = 0x5269,  name = "ESC1 Throttle", unit = UNIT_PERCENT, prec = 1, min = 0,    max = 1000,    dec = decU16 },
    [23] = { sidElrs = 0x1047, sidSport = 0x0418,  name = "ESC1 Temp",     unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [24] = { sidElrs = 0x1048, sidSport = 0x0419,  name = "ESC1 Temp 2",   unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [25] = { sidElrs = 0x1049, sidSport = 0x0219,  name = "ESC1 BEC Volt", unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1500,    dec = decU16 },
    [26] = { sidElrs = 0x104A, sidSport = 0x0229,  name = "ESC1 BEC Curr", unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 10000,   dec = decU16 },
    [27] = { sidElrs = 0x104E, sidSport = 0x5128,  name = "ESC1 Status",   unit = UNIT_RAW,     prec = 0, min = 0,    max = 2147483647, dec = decU32 },
    [28] = { sidElrs = 0x104F, sidSport = 0x5129,  name = "ESC1 Model ID", unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [30] = { sidElrs = 0x1051, sidSport = 0x021A,  name = "ESC2 Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [31] = { sidElrs = 0x1052, sidSport = 0x020A,  name = "ESC2 Current",  unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [32] = { sidElrs = 0x1053, sidSport = 0x525A,  name = "ESC2 Consump",  unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [33] = { sidElrs = 0x1054, sidSport = 0x050A,  name = "ESC2 eRPM",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU24 },
    [36] = { sidElrs = 0x1057, sidSport = 0x041A,  name = "ESC2 Temp",     unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [41] = { sidElrs = 0x105F, sidSport = 0x512B,  name = "ESC2 Model ID", unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [42] = { sidElrs = 0x1080, sidSport = 0x0211,  name = "ESC Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [43] = { sidElrs = 0x1081, sidSport = 0x0901,  name = "BEC Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1600,    dec = decU16 },
    [44] = { sidElrs = 0x1082, sidSport = 0x0902,  name = "BUS Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1200,    dec = decU16 },
    [45] = { sidElrs = 0x1083, sidSport = 0x0900,  name = "MCU Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 500,     dec = decU16 },

    [46] = { sidElrs = 0x1090, sidSport = 0x0201,  name = "ESC Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [47] = { sidElrs = 0x1091, sidSport = 0x0222,  name = "BEC Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 10000,   dec = decU16 },
    [48] = { sidElrs = 0x1092, sidSport = nil,     name = "BUS Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 1000,    dec = decU16 },
    [49] = { sidElrs = 0x1093, sidSport = nil,     name = "MCU Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 1000,    dec = decU16 },

    [50] = { sidElrs = 0x10A0, sidSport = 0x0401,  name = "ESC Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [51] = { sidElrs = 0x10A1, sidSport = 0x0402,  name = "BEC Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [52] = { sidElrs = 0x10A3, sidSport = 0x0400,  name = "MCU Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },

    [57] = { sidElrs = 0x10B1, sidSport = 0x5210,  name = "Heading",       unit = UNIT_DEGREE,  prec = 1, min = -1800, max = 3600,   dec = decS16 },
    [58] = { sidElrs = 0x10B2, sidSport = nil,     name = "Altitude",      unit = UNIT_METER,   prec = 2, min = -100000, max = 100000, dec = decS24 },
    [59] = { sidElrs = 0x10B3, sidSport = nil,     name = "VSpeed",        unit = UNIT_METER_PER_SECOND, prec = 2, min = -10000, max = 10000, dec = decS16 },

    [60] = { sidElrs = 0x10C0, sidSport = 0x0500,  name = "Headspeed",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU16 },
    [61] = { sidElrs = 0x10C1, sidSport = 0x0501,  name = "Tailspeed",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU16 },

    [64] = { sidElrs = 0x1100, sidSport = nil,     name = "Attd",          unit = UNIT_DEGREE,  prec = 1, min = nil,  max = nil,     dec = decAttitude },
    [65] = { sidElrs = 0x1101, sidSport = nil,     name = "Pitch Attitude",unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },
    [66] = { sidElrs = 0x1102, sidSport = nil,     name = "Roll Attitude", unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },
    [67] = { sidElrs = 0x1103, sidSport = nil,     name = "Yaw Attitude",  unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },

    [68] = { sidElrs = 0x1110, sidSport = nil,     name = "Accl",          unit = UNIT_G,       prec = 2, min = nil,  max = nil,     dec = decAccel },
    [69] = { sidElrs = 0x1111, sidSport = nil,     name = "Accel X",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },
    [70] = { sidElrs = 0x1112, sidSport = nil,     name = "Accel Y",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },
    [71] = { sidElrs = 0x1113, sidSport = nil,     name = "Accel Z",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },

    [73] = { sidElrs = 0x1121, sidSport = nil,     name = "GPS Sats",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [74] = { sidElrs = 0x1122, sidSport = nil,     name = "GPS PDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [75] = { sidElrs = 0x1123, sidSport = nil,     name = "GPS HDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [76] = { sidElrs = 0x1124, sidSport = nil,     name = "GPS VDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [77] = { sidElrs = 0x1125, sidSport = nil,     name = "GPS Coord",     unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decLatLong },
    [78] = { sidElrs = 0x1126, sidSport = nil,     name = "GPS Altitude",  unit = UNIT_METER,   prec = 2, min = -100000000, max = 100000000, dec = decS16 },
    [79] = { sidElrs = 0x1127, sidSport = 0x0840,  name = "GPS Heading",   unit = UNIT_DEGREE,  prec = 1, min = -1800, max = 3600,   dec = decS16 },
    [80] = { sidElrs = 0x1128, sidSport = nil,     name = "GPS Speed",     unit = UNIT_METER_PER_SECOND, prec = 2, min = 0, max = 10000, dec = decU16 },
    [81] = { sidElrs = 0x1129, sidSport = nil,     name = "GPS Home Dist", unit = UNIT_METER,   prec = 1, min = 0,    max = 65535,   dec = decU16 },
    [82] = { sidElrs = 0x112A, sidSport = nil,     name = "GPS Home Dir",  unit = UNIT_METER,   prec = 1, min = 0,    max = 3600,    dec = decU16 },

    [85] = { sidElrs = 0x1141, sidSport = 0x51D0,  name = "CPU Load",      unit = UNIT_PERCENT, prec = 0, min = 0,    max = 100,     dec = decU8 },
    [86] = { sidElrs = 0x1142, sidSport = 0x51D1,  name = "SYS Load",      unit = UNIT_PERCENT, prec = 0, min = 0,    max = 10,      dec = decU8 },
    [87] = { sidElrs = 0x1143, sidSport = 0x51D2,  name = "RT Load",       unit = UNIT_PERCENT, prec = 0, min = 0,    max = 200,     dec = decU8 },

    [88] = { sidElrs = 0x1200, sidSport = 0x5120,  name = "Model ID",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [89] = { sidElrs = 0x1201, sidSport = 0x5121,  name = "Flight Mode",   unit = UNIT_RAW,     prec = 0, min = 0,    max = 65535,   dec = decU16 },
    [90] = { sidElrs = 0x1202, sidSport = 0x5122,  name = "Arming Flags",  unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [91] = { sidElrs = 0x1203, sidSport = 0x5123,  name = "Arming Disable",unit = UNIT_RAW,     prec = 0, min = 0,    max = 2147483647, dec = decU32 },
    [92] = { sidElrs = 0x1204, sidSport = 0x5124,  name = "Rescue",        unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [93] = { sidElrs = 0x1205, sidSport = 0x5125,  name = "Governor",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [95] = { sidElrs = 0x1211, sidSport = 0x5130,  name = "PID Profile",   unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },
    [96] = { sidElrs = 0x1212, sidSport = 0x5131,  name = "Rate Profile",  unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },
    [98] = { sidElrs = 0x1213, sidSport = nil,     name = "LED Profile",   unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },

    [99] = { sidElrs = 0x1220, sidSport = 0x5110,  name = "ADJ",           unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decAdjFunc },

    [100] = {sidElrs = 0xDB00, sidSport = nil,    name = "DBG0", unit = UNIT_RAW, prec = 0, dec = decS32 },
    [101] = {sidElrs = 0xDB01, sidSport = nil,    name = "DBG1", unit = UNIT_RAW, prec = 0, dec = decS32 },
    [102] = {sidElrs = 0xDB02, sidSport = nil,    name = "DBG2", unit = UNIT_RAW, prec = 0, dec = decS32 },
    [103] = {sidElrs = 0xDB03, sidSport = nil,    name = "DBG3", unit = UNIT_RAW, prec = 0, dec = decS32 },
    [104] = {sidElrs = 0xDB04, sidSport = nil,    name = "DBG4", unit = UNIT_RAW, prec = 0, dec = decS32 },
    [105] = {sidElrs = 0xDB05, sidSport = nil,    name = "DBG5", unit = UNIT_RAW, prec = 0, dec = decS32 },
    [106] = {sidElrs = 0xDB06, sidSport = nil,    name = "DBG6", unit = UNIT_RAW, prec = 0, dec = decS32 },
    [107] = {sidElrs = 0xDB07, sidSport = nil, name = "DBG7", unit = UNIT_RAW, prec = 0, dec = decS32 },

}
