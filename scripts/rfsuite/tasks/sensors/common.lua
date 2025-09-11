elrs.RFSensors = {
    [0]  = { sid = 0x1000, name = "NULL",          unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decNil },
    [1]  = { sid = 0x1001, name = "Heartbeat",     unit = UNIT_RAW,     prec = 0, min = 0,    max = 60000,   dec = decU16 },

    [3]  = { sid = 0x1011, name = "Voltage",       unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [4]  = { sid = 0x1012, name = "Current",       unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [5]  = { sid = 0x1013, name = "Consumption",   unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [6]  = { sid = 0x1014, name = "Charge Level",  unit = UNIT_PERCENT, prec = 0, min = 0,    max = 100,     dec = decU8 },

    [7]  = { sid = 0x1020, name = "Cell Count",    unit = UNIT_RAW,     prec = 0, min = 0,    max = 16,      dec = decU8 },
    [8]  = { sid = 0x1021, name = "Cell Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 455,     dec = decCellV },
    [9]  = { sid = 0x102F, name = "Cell Voltages", unit = UNIT_VOLT,    prec = 2, min = nil,  max = nil,     dec = decCells },

    [10] = { sid = 0x1030, name = "Ctrl",          unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decControl },
    [11] = { sid = 0x1031, name = "Pitch Control", unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [12] = { sid = 0x1032, name = "Roll Control",  unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [13] = { sid = 0x1033, name = "Yaw Control",   unit = UNIT_DEGREE,  prec = 1, min = -900, max = 900,     dec = decS16 },
    [14] = { sid = 0x1034, name = "Coll Control",  unit = UNIT_DEGREE,  prec = 1, min = -450, max = 450,     dec = decS16 },
    [15] = { sid = 0x1035, name = "Throttle %",    unit = UNIT_PERCENT, prec = 0, min = -100, max = 100,     dec = decS8 },

    [17] = { sid = 0x1041, name = "ESC1 Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [18] = { sid = 0x1042, name = "ESC1 Current",  unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [19] = { sid = 0x1043, name = "ESC1 Consump",  unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [20] = { sid = 0x1044, name = "ESC1 eRPM",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU24 },
    [21] = { sid = 0x1045, name = "ESC1 PWM",      unit = UNIT_PERCENT, prec = 1, min = 0,    max = 1000,    dec = decU16 },
    [22] = { sid = 0x1046, name = "ESC1 Throttle", unit = UNIT_PERCENT, prec = 1, min = 0,    max = 1000,    dec = decU16 },
    [23] = { sid = 0x1047, name = "ESC1 Temp",     unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [24] = { sid = 0x1048, name = "ESC1 Temp 2",   unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [25] = { sid = 0x1049, name = "ESC1 BEC Volt", unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1500,    dec = decU16 },
    [26] = { sid = 0x104A, name = "ESC1 BEC Curr", unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 10000,   dec = decU16 },
    [27] = { sid = 0x104E, name = "ESC1 Status",   unit = UNIT_RAW,     prec = 0, min = 0,    max = 2147483647, dec = decU32 },
    [28] = { sid = 0x104F, name = "ESC1 Model ID", unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [30] = { sid = 0x1051, name = "ESC2 Voltage",  unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [31] = { sid = 0x1052, name = "ESC2 Current",  unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [32] = { sid = 0x1053, name = "ESC2 Consump",  unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16 },
    [33] = { sid = 0x1054, name = "ESC2 eRPM",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU24 },
    [36] = { sid = 0x1057, name = "ESC2 Temp",     unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [41] = { sid = 0x105F, name = "ESC2 Model ID", unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [42] = { sid = 0x1080, name = "ESC Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 6500,    dec = decU16 },
    [43] = { sid = 0x1081, name = "BEC Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1600,    dec = decU16 },
    [44] = { sid = 0x1082, name = "BUS Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 1200,    dec = decU16 },
    [45] = { sid = 0x1083, name = "MCU Voltage",   unit = UNIT_VOLT,    prec = 2, min = 0,    max = 500,     dec = decU16 },

    [46] = { sid = 0x1090, name = "ESC Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 65000,   dec = decU16 },
    [47] = { sid = 0x1091, name = "BEC Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 10000,   dec = decU16 },
    [48] = { sid = 0x1092, name = "BUS Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 1000,    dec = decU16 },
    [49] = { sid = 0x1093, name = "MCU Current",   unit = UNIT_AMPERE,  prec = 2, min = 0,    max = 1000,    dec = decU16 },

    [50] = { sid = 0x10A0, name = "ESC Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [51] = { sid = 0x10A1, name = "BEC Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },
    [52] = { sid = 0x10A3, name = "MCU Temp",      unit = UNIT_CELSIUS, prec = 0, min = 0,    max = 255,     dec = decU8 },

    [57] = { sid = 0x10B1, name = "Heading",       unit = UNIT_DEGREE,  prec = 1, min = -1800, max = 3600,   dec = decS16 },
    [58] = { sid = 0x10B2, name = "Altitude",      unit = UNIT_METER,   prec = 2, min = -100000, max = 100000, dec = decS24 },
    [59] = { sid = 0x10B3, name = "VSpeed",        unit = UNIT_METER_PER_SECOND, prec = 2, min = -10000, max = 10000, dec = decS16 },

    [60] = { sid = 0x10C0, name = "Headspeed",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU16 },
    [61] = { sid = 0x10C1, name = "Tailspeed",     unit = UNIT_RPM,     prec = 0, min = 0,    max = 65535,   dec = decU16 },

    [64] = { sid = 0x1100, name = "Attd",          unit = UNIT_DEGREE,  prec = 1, min = nil,  max = nil,     dec = decAttitude },
    [65] = { sid = 0x1101, name = "Pitch Attitude",unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },
    [66] = { sid = 0x1102, name = "Roll Attitude", unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },
    [67] = { sid = 0x1103, name = "Yaw Attitude",  unit = UNIT_DEGREE,  prec = 0, min = -180, max = 360,     dec = decS16 },

    [68] = { sid = 0x1110, name = "Accl",          unit = UNIT_G,       prec = 2, min = nil,  max = nil,     dec = decAccel },
    [69] = { sid = 0x1111, name = "Accel X",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },
    [70] = { sid = 0x1112, name = "Accel Y",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },
    [71] = { sid = 0x1113, name = "Accel Z",       unit = UNIT_G,       prec = 1, min = -4000, max = 4000,   dec = decS16 },

    [73] = { sid = 0x1121, name = "GPS Sats",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [74] = { sid = 0x1122, name = "GPS PDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [75] = { sid = 0x1123, name = "GPS HDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [76] = { sid = 0x1124, name = "GPS VDOP",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [77] = { sid = 0x1125, name = "GPS Coord",     unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decLatLong },
    [78] = { sid = 0x1126, name = "GPS Altitude",  unit = UNIT_METER,   prec = 2, min = -100000000, max = 100000000, dec = decS16 },
    [79] = { sid = 0x1127, name = "GPS Heading",   unit = UNIT_DEGREE,  prec = 1, min = -1800, max = 3600,   dec = decS16 },
    [80] = { sid = 0x1128, name = "GPS Speed",     unit = UNIT_METER_PER_SECOND, prec = 2, min = 0, max = 10000, dec = decU16 },
    [81] = { sid = 0x1129, name = "GPS Home Dist", unit = UNIT_METER,   prec = 1, min = 0,    max = 65535,   dec = decU16 },
    [82] = { sid = 0x112A, name = "GPS Home Dir",  unit = UNIT_METER,   prec = 1, min = 0,    max = 3600,    dec = decU16 },

    [85] = { sid = 0x1141, name = "CPU Load",      unit = UNIT_PERCENT, prec = 0, min = 0,    max = 100,     dec = decU8 },
    [86] = { sid = 0x1142, name = "SYS Load",      unit = UNIT_PERCENT, prec = 0, min = 0,    max = 10,      dec = decU8 },
    [87] = { sid = 0x1143, name = "RT Load",       unit = UNIT_PERCENT, prec = 0, min = 0,    max = 200,     dec = decU8 },

    [88] = { sid = 0x1200, name = "Model ID",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [89] = { sid = 0x1201, name = "Flight Mode",   unit = UNIT_RAW,     prec = 0, min = 0,    max = 65535,   dec = decU16 },
    [90] = { sid = 0x1202, name = "Arming Flags",  unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [91] = { sid = 0x1203, name = "Arming Disable",unit = UNIT_RAW,     prec = 0, min = 0,    max = 2147483647, dec = decU32 },
    [92] = { sid = 0x1204, name = "Rescue",        unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },
    [93] = { sid = 0x1205, name = "Governor",      unit = UNIT_RAW,     prec = 0, min = 0,    max = 255,     dec = decU8 },

    [95] = { sid = 0x1211, name = "PID Profile",   unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },
    [96] = { sid = 0x1212, name = "Rate Profile",  unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },
    [98] = { sid = 0x1213, name = "LED Profile",   unit = UNIT_RAW,     prec = 0, min = 1,    max = 6,       dec = decU8 },

    [99] = { sid = 0x1220, name = "ADJ",           unit = UNIT_RAW,     prec = 0, min = nil,  max = nil,     dec = decAdjFunc },
}
