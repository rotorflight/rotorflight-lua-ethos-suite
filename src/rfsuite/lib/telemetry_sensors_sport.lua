-- S.Port candidate appIds for lib/telemetry_sensors.lua -- what the FC/ESC
-- broadcast directly over S.Port. Split into its own file (rather than a
-- sub-table of one big CANDIDATES literal) so lib/telemetry_sensors.lua can
-- loadfile() only the protocol actually in use for this session instead of
-- constructing all three protocols' tables regardless -- see that file's
-- own header.

return {
  altitude = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0100},
  },
  voltage = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0211},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0218},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x021A},
  },
  consumption = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250},
  },
  current = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0208},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201},
  },
  link = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0xF101, subId = 0},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0xF010, subId = 0},
  },
  rpm = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500},
  },
  temp_esc = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0418},
  },
  temp_mcu = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401},
  },
  bec_voltage = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0901},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0219},
  },
  throttle_percent = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5269},
  },
  smartfuel = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1},
  },
  -- Native S.Port broadcasts if the FC sends them directly, but in
  -- practice these are the same appIds lib/frsky_sensors.lua labels from
  -- TELEMETRY_CONFIG's slot assignment -- see tasks/session.lua's
  -- profile-change tracking.
  pid_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5130},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471},
  },
  rate_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5131},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472},
  },
  battery_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5133},
  },
  governor = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5125},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450},
  },
  adj_f = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110},
  },
  adj_v = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111},
  },
  -- Arm-status flags -- see tasks/session.lua's own updateProfiles() for
  -- how the raw value maps to a plain isArmed boolean.
  armflags = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5122},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5462},
  },
  -- Why-can't-arm bitmask (see lib/msp_status.lua's own arming_disable_flags
  -- and widgets/dashboard/context.lua's armingDisableFlagsToString()) --
  -- broadcast at the appId right after armflags's own.
  armdisableflags = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5123},
  },
}
