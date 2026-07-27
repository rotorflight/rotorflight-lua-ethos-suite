-- CRSF/ELRS candidate appIds for lib/telemetry_sensors.lua -- what
-- tasks/elrs_sensors.lua decodes off CRSF's custom-telemetry frames and
-- creates DIY sensors for. Split into its own file (rather than a sub-table
-- of one big CANDIDATES literal) so lib/telemetry_sensors.lua can
-- loadfile() only the protocol actually in use for this session instead of
-- constructing all three protocols' tables regardless -- see that file's
-- own header.

return {
  altitude = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10B2},
  },
  voltage = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1011},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1041},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1051},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1080},
  },
  consumption = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013},
  },
  current = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x104A},
  },
  rpm = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10C0},
  },
  temp_esc = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A0},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1047},
  },
  temp_mcu = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x10A3},
  },
  bec_voltage = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1081},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1049},
  },
  throttle_percent = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1035},
  },
  smartfuel = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014},
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1},
  },
  -- Same appIds tasks/elrs_sensors.lua's DIY sensors use (SIDs 0x1211/
  -- 0x1212/0x1214) -- this resolves to that same sensor once it exists.
  pid_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1211},
  },
  rate_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1212},
  },
  battery_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1214},
  },
  governor = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1205},
  },
  adj_f = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1221},
  },
  adj_v = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1222},
  },
  armflags = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1202},
  },
}
