-- ELRS/CRSF custom-telemetry SID -> sensor-metadata table. Stateless data
-- only (a factory function, not a stateful module -- see below for why).
-- Transcribed from rotorflight-lua-edgetx-suite's
-- tasks/scheduler/sensors/elrs_sensors.lua, ported in full (it's small
-- data, not much cost to carry entries this rebuild doesn't use yet).
--
-- INVARIANT: this table must cover every appId the flight controller
-- broadcasts. tasks/elrs_sensors.lua's parseFrame() walks a frame as
-- `(U16 appId, value)` pairs and stops at the first appId it has no entry
-- for -- it cannot skip one, because the pair's byte width lives here and
-- nowhere on the wire. One gap therefore costs every sensor packed after it
-- in that same frame, and the symptom looks like a dead sensor rather than a
-- missing table entry.
--
-- The appIds are declared in the flight controller as TLM_SENSOR(...) in
-- src/main/telemetry/crsf.c, and that file is the reference whenever this
-- table is questioned. bin/telemetry/verify_sensor_table.py checks the two
-- against each other (pinned to a firmware snapshot, overridable with
-- --ref) and names the missing entries, and the parseFrame() abort itself now
-- logs which appId it gave up on.
--
-- Returns a *factory function* taking a `decoders` table (both the pure
-- primitives from lib/elrs_decode_primitives.lua and the aggregate
-- decoders tasks/elrs_sensors.lua defines for itself) and returning
-- `table<SID, {name, unit, prec, min, max, dec}>`. Factory pattern (rather
-- than requiring the caller to already have every decoder in scope) keeps
-- this file a pure, dependency-free data table that only cares about
-- shape, matching the original's own reasoning.

return function(decoders)
  local decNil = decoders.decNil
  local decU8 = decoders.decU8
  local decS8 = decoders.decS8
  local decU16 = decoders.decU16
  local decS16 = decoders.decS16
  local decU24 = decoders.decU24
  local decS24 = decoders.decS24
  local decU32 = decoders.decU32
  local decS32 = decoders.decS32
  local decCellV = decoders.decCellV
  local decCells = decoders.decCells
  local decControl = decoders.decControl
  local decAttitude = decoders.decAttitude
  local decAccel = decoders.decAccel
  local decLatLong = decoders.decLatLong
  local decAdjFunc = decoders.decAdjFunc

  return {
    [0x1000] = {name = "NULL", unit = UNIT_RAW, prec = 0, dec = decNil},
    [0x1001] = {name = "Heartbeat", unit = UNIT_RAW, prec = 0, min = 0, max = 60000, dec = decU16},
    [0x1011] = {name = "Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    [0x1012] = {name = "Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    [0x1013] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1014] = {name = "Charge Level", unit = UNIT_PERCENT, prec = 0, min = 0, max = 100, dec = decU8},
    [0x1020] = {name = "Cell Count", unit = UNIT_RAW, prec = 0, min = 0, max = 16, dec = decU8},
    [0x1021] = {name = "Cell Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 455, dec = decCellV},
    [0x102F] = {name = "Cell Voltages", unit = UNIT_VOLT, prec = 2, dec = decCells},
    [0x1030] = {name = "Ctrl", unit = UNIT_RAW, prec = 0, dec = decControl},
    [0x1031] = {name = "Pitch Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    [0x1032] = {name = "Roll Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    [0x1033] = {name = "Yaw Control", unit = UNIT_DEGREE, prec = 1, min = -900, max = 900, dec = decS16},
    [0x1034] = {name = "Coll Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    [0x1035] = {name = "Throttle %", unit = UNIT_PERCENT, prec = 0, min = -100, max = 100, dec = decS8},
    [0x1041] = {name = "ESC1 Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    [0x1042] = {name = "ESC1 Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    [0x1043] = {name = "ESC1 Consump", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1044] = {name = "ESC1 eRPM", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU24},
    [0x1045] = {name = "ESC1 PWM", unit = UNIT_PERCENT, prec = 1, min = 0, max = 1000, dec = decU16},
    [0x1046] = {name = "ESC1 Throttle", unit = UNIT_PERCENT, prec = 1, min = 0, max = 1000, dec = decU16},
    [0x1047] = {name = "ESC1 Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1048] = {name = "ESC1 Temp 2", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1049] = {name = "ESC1 BEC Volt", unit = UNIT_VOLT, prec = 2, min = 0, max = 1500, dec = decU16},
    [0x104A] = {name = "ESC1 BEC Curr", unit = UNIT_AMPERE, prec = 2, min = 0, max = 10000, dec = decU16},
    [0x104E] = {name = "ESC1 Status", unit = UNIT_RAW, prec = 0, min = 0, max = 2147483647, dec = decU32},
    [0x104F] = {name = "ESC1 Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1051] = {name = "ESC2 Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    [0x1052] = {name = "ESC2 Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    [0x1053] = {name = "ESC2 Consump", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    [0x1054] = {name = "ESC2 eRPM", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU24},
    [0x1057] = {name = "ESC2 Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x105F] = {name = "ESC2 Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1080] = {name = "ESC Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    [0x1081] = {name = "BEC Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 1600, dec = decU16},
    [0x1082] = {name = "BUS Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 1200, dec = decU16},
    [0x1083] = {name = "MCU Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 500, dec = decU16},
    [0x1090] = {name = "ESC Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    [0x1091] = {name = "BEC Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 10000, dec = decU16},
    [0x1092] = {name = "BUS Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 1000, dec = decU16},
    [0x1093] = {name = "MCU Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 1000, dec = decU16},
    [0x10A0] = {name = "ESC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x10A1] = {name = "BEC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x10A3] = {name = "MCU Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    [0x10B1] = {name = "Heading", unit = UNIT_DEGREE, prec = 1, min = -1800, max = 3600, dec = decS16},
    [0x10B2] = {name = "Altitude", unit = UNIT_METER, prec = 2, min = -100000, max = 100000, dec = decS24},
    [0x10B3] = {name = "VSpeed", unit = UNIT_METER_PER_SECOND, prec = 2, min = -10000, max = 10000, dec = decS16},
    [0x10C0] = {name = "Headspeed", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU16},
    [0x10C1] = {name = "Tailspeed", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU16},
    [0x1100] = {name = "Attd", unit = UNIT_DEGREE, prec = 1, dec = decAttitude},
    [0x1101] = {name = "Pitch Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    [0x1102] = {name = "Roll Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    [0x1103] = {name = "Yaw Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    [0x1110] = {name = "Accl", unit = UNIT_G, prec = 2, dec = decAccel},
    [0x1111] = {name = "Accel X", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    [0x1112] = {name = "Accel Y", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    [0x1113] = {name = "Accel Z", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    [0x1121] = {name = "GPS Sats", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1122] = {name = "GPS PDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1123] = {name = "GPS HDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1124] = {name = "GPS VDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1125] = {name = "GPS Coord", unit = UNIT_RAW, prec = 0, dec = decLatLong},
    [0x1126] = {name = "GPS Altitude", unit = UNIT_METER, prec = 2, min = -100000000, max = 100000000, dec = decS16},
    [0x1127] = {name = "GPS Course", unit = UNIT_DEGREE, prec = 1, min = -1800, max = 3600, dec = decS16},
    [0x1128] = {name = "GPS Speed", unit = UNIT_METER_PER_SECOND, prec = 2, min = 0, max = 10000, dec = decU16},
    [0x1129] = {name = "GPS Home Dist", unit = UNIT_METER, prec = 1, min = 0, max = 65535, dec = decU16},
    [0x112A] = {name = "GPS Home Dir", unit = UNIT_METER, prec = 1, min = 0, max = 3600, dec = decU16},
    [0x1141] = {name = "CPU Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 100, dec = decU8},
    [0x1142] = {name = "SYS Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 10, dec = decU8},
    [0x1143] = {name = "RT Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 200, dec = decU8},
    [0x1200] = {name = "Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1201] = {name = "Flight Mode", unit = UNIT_RAW, prec = 0, min = 0, max = 65535, dec = decU16},
    [0x1202] = {name = "Arming Flags", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1203] = {name = "Arming Disable", unit = UNIT_RAW, prec = 0, min = 0, max = 2147483647, dec = decU32},
    [0x1204] = {name = "Rescue", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1205] = {name = "Governor", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    [0x1211] = {name = "PID Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    [0x1212] = {name = "Rate Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    [0x1213] = {name = "LED Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    [0x1214] = {name = "Battery Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    [0x1220] = {name = "ADJ", unit = UNIT_RAW, prec = 0, dec = decAdjFunc},
    [0xDB00] = {name = "Debug 0", unit = UNIT_RAW, prec = 0, dec = decS32},
    [0xDB01] = {name = "Debug 1", unit = UNIT_RAW, prec = 0, dec = decS32},
    [0xDB02] = {name = "Debug 2", unit = UNIT_RAW, prec = 0, dec = decS32},
    [0xDB03] = {name = "Debug 3", unit = UNIT_RAW, prec = 0, dec = decS32},
    [0xDB04] = {name = "Debug 4", unit = UNIT_RAW, prec = 0, dec = decS32},
    [0xDB05] = {name = "Debug 5", unit = UNIT_RAW, prec = 0, dec = decS32},
    [0xDB06] = {name = "Debug 6", unit = UNIT_RAW, prec = 0, dec = decS32},
    [0xDB07] = {name = "Debug 7", unit = UNIT_RAW, prec = 0, dec = decS32},
  }
end
