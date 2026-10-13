-- Static catalog for Setup -> Telemetry.
--
-- Sensor IDs, labels, groups, and aggregate/child exclusions are copied
-- from rotorflight-lua-ethos-suite's app/modules/telemetry/telemetry.lua.
-- DEFAULT_IDS comes from that suite's telemetry sensor metadata
-- (tasks/scheduler/telemetry/sources/sensor_table.lua): every mandatory
-- sensor with a set_telemetry_sensors mapping, plus the explicitly
-- default fuel sensor.

if package.loaded["rfsuite.lib.telemetry_sensor_catalog"] then
  return package.loaded["rfsuite.lib.telemetry_sensor_catalog"]
end

local SENSOR_LIST = {
  [1] = {name = "@i18n(telemetry.sensor_heartbeat)@", group = "system"},
  [3] = {name = "@i18n(telemetry.sensor_voltage)@", group = "battery"},
  [4] = {name = "@i18n(telemetry.sensor_current)@", group = "battery"},
  [5] = {name = "@i18n(telemetry.sensor_consumption)@", group = "battery"},
  [6] = {name = "@i18n(telemetry.sensor_charge_level)@", group = "battery"},
  [7] = {name = "@i18n(telemetry.sensor_cell_count)@", group = "battery"},
  [8] = {name = "@i18n(telemetry.sensor_cell_voltage)@", group = "battery"},
  [9] = {name = "@i18n(telemetry.sensor_cell_voltages)@", group = "battery"},
  [10] = {name = "@i18n(telemetry.sensor_ctrl)@", group = "control"},
  [11] = {name = "@i18n(telemetry.sensor_pitch_control)@", group = "control"},
  [12] = {name = "@i18n(telemetry.sensor_roll_control)@", group = "control"},
  [13] = {name = "@i18n(telemetry.sensor_yaw_control)@", group = "control"},
  [14] = {name = "@i18n(telemetry.sensor_coll_control)@", group = "control"},
  [15] = {name = "@i18n(telemetry.sensor_throttle_pct)@", group = "control"},
  [17] = {name = "@i18n(telemetry.sensor_esc1_voltage)@", group = "esc1"},
  [18] = {name = "@i18n(telemetry.sensor_esc1_current)@", group = "esc1"},
  [19] = {name = "@i18n(telemetry.sensor_esc1_consump)@", group = "esc1"},
  [20] = {name = "@i18n(telemetry.sensor_esc1_erpm)@", group = "esc1"},
  [21] = {name = "@i18n(telemetry.sensor_esc1_pwm)@", group = "esc1"},
  [22] = {name = "@i18n(telemetry.sensor_esc1_throttle)@", group = "esc1"},
  [23] = {name = "@i18n(telemetry.sensor_esc1_temp)@", group = "esc1"},
  [24] = {name = "@i18n(telemetry.sensor_esc1_temp2)@", group = "esc1"},
  [25] = {name = "@i18n(telemetry.sensor_esc1_bec_volt)@", group = "esc1"},
  [26] = {name = "@i18n(telemetry.sensor_esc1_bec_curr)@", group = "esc1"},
  [27] = {name = "@i18n(telemetry.sensor_esc1_status)@", group = "esc1"},
  [28] = {name = "@i18n(telemetry.sensor_esc1_model_id)@", group = "esc1"},
  [30] = {name = "@i18n(telemetry.sensor_esc2_voltage)@", group = "esc2"},
  [31] = {name = "@i18n(telemetry.sensor_esc2_current)@", group = "esc2"},
  [32] = {name = "@i18n(telemetry.sensor_esc2_consump)@", group = "esc2"},
  [33] = {name = "@i18n(telemetry.sensor_esc2_erpm)@", group = "esc2"},
  [36] = {name = "@i18n(telemetry.sensor_esc2_temp)@", group = "esc2"},
  [41] = {name = "@i18n(telemetry.sensor_esc2_model_id)@", group = "esc2"},
  [42] = {name = "@i18n(telemetry.sensor_esc_voltage)@", group = "voltage"},
  [43] = {name = "@i18n(telemetry.sensor_bec_voltage)@", group = "voltage"},
  [44] = {name = "@i18n(telemetry.sensor_bus_voltage)@", group = "voltage"},
  [45] = {name = "@i18n(telemetry.sensor_mcu_voltage)@", group = "voltage"},
  [46] = {name = "@i18n(telemetry.sensor_esc_current)@", group = "current"},
  [47] = {name = "@i18n(telemetry.sensor_bec_current)@", group = "current"},
  [48] = {name = "@i18n(telemetry.sensor_bus_current)@", group = "current"},
  [49] = {name = "@i18n(telemetry.sensor_mcu_current)@", group = "current"},
  [50] = {name = "@i18n(telemetry.sensor_esc_temp)@", group = "temps"},
  [51] = {name = "@i18n(telemetry.sensor_bec_temp)@", group = "temps"},
  [52] = {name = "@i18n(telemetry.sensor_mcu_temp)@", group = "temps"},
  [57] = {name = "@i18n(telemetry.sensor_heading)@", group = "gyro"},
  [58] = {name = "@i18n(telemetry.sensor_altitude)@", group = "barometer"},
  [59] = {name = "@i18n(telemetry.sensor_vspeed)@", group = "barometer"},
  [60] = {name = "@i18n(telemetry.sensor_headspeed)@", group = "rpm"},
  [61] = {name = "@i18n(telemetry.sensor_tailspeed)@", group = "rpm"},
  [64] = {name = "@i18n(telemetry.sensor_attd)@", group = "gyro"},
  [65] = {name = "@i18n(telemetry.sensor_pitch_attitude)@", group = "gyro"},
  [66] = {name = "@i18n(telemetry.sensor_roll_attitude)@", group = "gyro"},
  [67] = {name = "@i18n(telemetry.sensor_yaw_attitude)@", group = "gyro"},
  [68] = {name = "@i18n(telemetry.sensor_accl)@", group = "gyro"},
  [69] = {name = "@i18n(telemetry.sensor_accel_x)@", group = "gyro"},
  [70] = {name = "@i18n(telemetry.sensor_accel_y)@", group = "gyro"},
  [71] = {name = "@i18n(telemetry.sensor_accel_z)@", group = "gyro"},
  [73] = {name = "@i18n(telemetry.sensor_gps_sats)@", group = "gps"},
  [74] = {name = "@i18n(telemetry.sensor_gps_pdop)@", group = "gps"},
  [75] = {name = "@i18n(telemetry.sensor_gps_hdop)@", group = "gps"},
  [76] = {name = "@i18n(telemetry.sensor_gps_vdop)@", group = "gps"},
  [77] = {name = "@i18n(telemetry.sensor_gps_coord)@", group = "gps"},
  [78] = {name = "@i18n(telemetry.sensor_gps_altitude)@", group = "gps"},
  [79] = {name = "@i18n(telemetry.sensor_gps_heading)@", group = "gps"},
  [80] = {name = "@i18n(telemetry.sensor_gps_speed)@", group = "gps"},
  [81] = {name = "@i18n(telemetry.sensor_gps_home_dist)@", group = "gps"},
  [82] = {name = "@i18n(telemetry.sensor_gps_home_dir)@", group = "gps"},
  [85] = {name = "@i18n(telemetry.sensor_cpu_load)@", group = "system"},
  [86] = {name = "@i18n(telemetry.sensor_sys_load)@", group = "system"},
  [87] = {name = "@i18n(telemetry.sensor_rt_load)@", group = "system"},
  [88] = {name = "@i18n(telemetry.sensor_model_id)@", group = "status"},
  [89] = {name = "@i18n(telemetry.sensor_flight_mode)@", group = "status"},
  [90] = {name = "@i18n(telemetry.sensor_arming_flags)@", group = "status"},
  [91] = {name = "@i18n(telemetry.sensor_arming_disable)@", group = "status"},
  [92] = {name = "@i18n(telemetry.sensor_rescue)@", group = "status"},
  [93] = {name = "@i18n(telemetry.sensor_governor)@", group = "status"},
  [95] = {name = "@i18n(telemetry.sensor_pid_profile)@", group = "profiles"},
  [96] = {name = "@i18n(telemetry.sensor_rate_profile)@", group = "profiles"},
  [97] = {name = "@i18n(telemetry.sensor_battery_profile)@", group = "profiles"},
  [98] = {name = "@i18n(telemetry.sensor_led_profile)@", group = "profiles"},
  [99] = {name = "@i18n(telemetry.sensor_adj)@", group = "status"},
  [100] = {name = "@i18n(telemetry.sensor_dbg0)@", group = "debug"},
  [101] = {name = "@i18n(telemetry.sensor_dbg1)@", group = "debug"},
  [102] = {name = "@i18n(telemetry.sensor_dbg2)@", group = "debug"},
  [103] = {name = "@i18n(telemetry.sensor_dbg3)@", group = "debug"},
  [104] = {name = "@i18n(telemetry.sensor_dbg4)@", group = "debug"},
  [105] = {name = "@i18n(telemetry.sensor_dbg5)@", group = "debug"},
  [106] = {name = "@i18n(telemetry.sensor_dbg6)@", group = "debug"},
  [107] = {name = "@i18n(telemetry.sensor_dbg7)@", group = "debug"},
  -- Packed status words (lib/system_status.lua). minApiMinor: firmware
  -- before MSP API 12.10 does not have them, so app/pages/telemetry.lua
  -- does not offer them there.
  [120] = {name = "@i18n(telemetry.sensor_system_status)@", group = "status", minApiMinor = 10},
  [121] = {name = "@i18n(telemetry.sensor_system_config)@", group = "status", minApiMinor = 10},
}

local GROUP_TITLE = {
  battery = "@i18n(telemetry.group_battery)@",
  voltage = "@i18n(telemetry.group_voltage)@",
  current = "@i18n(telemetry.group_current)@",
  temps = "@i18n(telemetry.group_temps)@",
  esc1 = "@i18n(telemetry.group_esc1)@",
  esc2 = "@i18n(telemetry.group_esc2)@",
  rpm = "@i18n(telemetry.group_rpm)@",
  barometer = "@i18n(telemetry.group_barometer)@",
  gyro = "@i18n(telemetry.group_gyro)@",
  gps = "@i18n(telemetry.group_gps)@",
  status = "@i18n(telemetry.group_status)@",
  profiles = "@i18n(telemetry.group_profiles)@",
  control = "@i18n(telemetry.group_control)@",
  system = "@i18n(telemetry.group_system)@",
  debug = "@i18n(telemetry.group_debug)@",
}

local GROUP_ORDER = {
  "battery", "voltage", "current", "temps", "esc1", "esc2", "rpm",
  "barometer", "gyro", "gps", "status", "profiles", "control",
  "system", "debug",
}

local SENSOR_IDS = {}
for id in pairs(SENSOR_LIST) do
  SENSOR_IDS[#SENSOR_IDS + 1] = id
end
table.sort(SENSOR_IDS, function(a, b) return a < b end)

local SENSOR_GROUPS = {}
for _, id in ipairs(SENSOR_IDS) do
  local sensor = SENSOR_LIST[id]
  local group = sensor.group or "system"
  if not SENSOR_GROUPS[group] then
    SENSOR_GROUPS[group] = {title = GROUP_TITLE[group] or group, ids = {}}
  end
  SENSOR_GROUPS[group].ids[#SENSOR_GROUPS[group].ids + 1] = id
end

local catalog = {
  SENSOR_LIST = SENSOR_LIST,
  SENSOR_IDS = SENSOR_IDS,
  SENSOR_GROUPS = SENSOR_GROUPS,
  GROUP_ORDER = GROUP_ORDER,
  NOT_AT_SAME_TIME = {
    [10] = {11, 12, 13, 14},
    [64] = {65, 66, 67},
    [68] = {69, 70, 71},
  },
  -- Same set as rotorflight-firmware's telemetry_sensors default
  -- (src/main/pg/telemetry.c) -- keep the two in sync. 120/121 are only
  -- applied on firmware that has them (minApiMinor above).
  DEFAULT_IDS = {90, 3, 60, 4, 23, 5, 93, 99, 95, 96, 15, 91, 43, 97, 6, 120, 121},
  -- Ids the flight controller emits as *full* CRSF frames while
  -- crsf_telemetry_mode is NATIVE: crsfNativeTelemetrySensors in
  -- src/main/telemetry/crsf.c holds FLIGHT_MODE, BATTERY, ATTITUDE,
  -- ALTITUDE, GPS, RPM and TEMP, and crsfInitNativeTelemetry() adds one to
  -- the schedule per matching slot -- the mode picks which sensor table the
  -- 40 slots filter, it does not switch the slots off. The three ids below
  -- are the ones this catalog happens to offer; the rest of the native set
  -- has no catalog entry, so those slots are "unmanaged" and are preserved
  -- in place on save rather than listed here.
  --
  -- A native-locked sensor cannot be switched off from the Setup ->
  -- Telemetry page in that mode, because the FC sends it whether or not a
  -- slot selects it. Same ids, and the same treatment, as
  -- rotorflight-lua-edgetx-suite's app/pages/setup/telemetry/page.lua
  -- (CRSF_NATIVE_CATALOG_IDS).
  NATIVE_LOCKED_IDS = {
    [58] = true, -- Altitude
    [64] = true, -- Attitude (combined)
    [89] = true, -- Flight mode
  },
}

-- NOT_AT_SAME_TIME above maps a parent to its children, so answering "which
-- parent governs this id?" needs the reverse direction. Derived here rather
-- than hand-listed so the two cannot drift; the EdgeTX page builds the same
-- map (CONFLICTING_WITH) for the same reason.
catalog.CONFLICTING_WITH = {}
for parentId, childIds in pairs(catalog.NOT_AT_SAME_TIME) do
  for _, childId in ipairs(childIds) do
    catalog.CONFLICTING_WITH[childId] = parentId
  end
end

package.loaded["rfsuite.lib.telemetry_sensor_catalog"] = catalog
return catalog
