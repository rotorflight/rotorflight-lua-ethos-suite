-- Ethos-simulator candidate appIds for lib/telemetry_sensors.lua, fabricated
-- by tasks/sim_sensors.lua (only loaded/populated when
-- system.getVersion().simulation == true) -- appIds must stay in sync with
-- that file's own SENSORS table. Only the keys already resolved by
-- lib/telemetry_sensors_sport.lua/lib/telemetry_sensors_crsf.lua get an
-- entry here; sim sensors with no real-hardware counterpart (fuel,
-- altitude, cell_count, accx/y/z, attpitch/roll/yaw, groundspeed,
-- armdisableflags, tailspeed) are still created and visible to
-- dashboards/telemetry pages via Ethos's own sensor picker, just not looked
-- up through this table -- nothing here needs them yet.
--
-- Split into its own file (rather than a sub-table of one big CANDIDATES
-- literal) so lib/telemetry_sensors.lua can loadfile() only the protocol
-- actually in use for this session instead of constructing all three
-- protocols' tables regardless -- see that file's own header.

return {
  altitude = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5016},
  },
  voltage = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5002},
  },
  consumption = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5008},
  },
  current = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5004},
  },
  rpm = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5003},
  },
  temp_esc = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5005},
  },
  temp_mcu = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5006},
  },
  bec_voltage = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5017},
  },
  throttle_percent = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5014},
  },
  pid_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5012},
  },
  rate_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5013},
  },
  battery_profile = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5026},
  },
  governor = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5009},
  },
  adj_f = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5010},
  },
  adj_v = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5011},
  },
  armflags = {
    {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5001},
  },
}
