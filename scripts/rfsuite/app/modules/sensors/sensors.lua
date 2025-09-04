local i18n = rfsuite.i18n.get
local enableWakeup = false

-- Lookup table (by ID)
local TELEMETRY_SENSORS = {
  [0] =  { name = i18n("sensors.sensor_none"),                 id = 0,   group = "general" },
  [1] =  { name = i18n("sensors.sensor_heartbeat"),            id = 1,   group = "general" },

  [2] =  { name = i18n("sensors.sensor_battery"),              id = 2,   group = "battery" },
  [3] =  { name = i18n("sensors.sensor_battery_voltage"),      id = 3,   group = "battery" },
  [4] =  { name = i18n("sensors.sensor_battery_current"),      id = 4,   group = "battery" },
  [5] =  { name = i18n("sensors.sensor_battery_consumption"),  id = 5,   group = "battery" },
  [6] =  { name = i18n("sensors.sensor_battery_charge_level"), id = 6,   group = "battery" },

  [7] =  { name = i18n("sensors.sensor_battery_cell_count"),   id = 7,   group = "battery_cells" },
  [8] =  { name = i18n("sensors.sensor_battery_cell_voltage"), id = 8,   group = "battery_cells" },
  [9] =  { name = i18n("sensors.sensor_battery_cell_voltages"),id = 9,   group = "battery_cells" },

  [10] = { name = i18n("sensors.sensor_control"),              id = 10,  group = "control" },
  [11] = { name = i18n("sensors.sensor_pitch_control"),        id = 11,  group = "control" },
  [12] = { name = i18n("sensors.sensor_roll_control"),         id = 12,  group = "control" },
  [13] = { name = i18n("sensors.sensor_yaw_control"),          id = 13,  group = "control" },
  [14] = { name = i18n("sensors.sensor_collective_control"),   id = 14,  group = "control" },
  [15] = { name = i18n("sensors.sensor_throttle_control"),     id = 15,  group = "control" },

  [16] = { name = i18n("sensors.sensor_esc1_data"),            id = 16,  group = "esc1" },
  [17] = { name = i18n("sensors.sensor_esc1_voltage"),         id = 17,  group = "esc1" },
  [18] = { name = i18n("sensors.sensor_esc1_current"),         id = 18,  group = "esc1" },
  [19] = { name = i18n("sensors.sensor_esc1_capacity"),        id = 19,  group = "esc1" },
  [20] = { name = i18n("sensors.sensor_esc1_erpm"),            id = 20,  group = "esc1" },
  [21] = { name = i18n("sensors.sensor_esc1_power"),           id = 21,  group = "esc1" },
  [22] = { name = i18n("sensors.sensor_esc1_throttle"),        id = 22,  group = "esc1" },
  [23] = { name = i18n("sensors.sensor_esc1_temp1"),           id = 23,  group = "esc1" },
  [24] = { name = i18n("sensors.sensor_esc1_temp2"),           id = 24,  group = "esc1" },
  [25] = { name = i18n("sensors.sensor_esc1_bec_voltage"),     id = 25,  group = "esc1" },
  [26] = { name = i18n("sensors.sensor_esc1_bec_current"),     id = 26,  group = "esc1" },
  [27] = { name = i18n("sensors.sensor_esc1_status"),          id = 27,  group = "esc1" },
  [28] = { name = i18n("sensors.sensor_esc1_model"),           id = 28,  group = "esc1" },

  [29] = { name = i18n("sensors.sensor_esc2_data"),            id = 29,  group = "esc2" },
  [30] = { name = i18n("sensors.sensor_esc2_voltage"),         id = 30,  group = "esc2" },
  [31] = { name = i18n("sensors.sensor_esc2_current"),         id = 31,  group = "esc2" },
  [32] = { name = i18n("sensors.sensor_esc2_capacity"),        id = 32,  group = "esc2" },
  [33] = { name = i18n("sensors.sensor_esc2_erpm"),            id = 33,  group = "esc2" },
  [34] = { name = i18n("sensors.sensor_esc2_power"),           id = 34,  group = "esc2" },
  [35] = { name = i18n("sensors.sensor_esc2_throttle"),        id = 35,  group = "esc2" },
  [36] = { name = i18n("sensors.sensor_esc2_temp1"),           id = 36,  group = "esc2" },
  [37] = { name = i18n("sensors.sensor_esc2_temp2"),           id = 37,  group = "esc2" },
  [38] = { name = i18n("sensors.sensor_esc2_bec_voltage"),     id = 38,  group = "esc2" },
  [39] = { name = i18n("sensors.sensor_esc2_bec_current"),     id = 39,  group = "esc2" },
  [40] = { name = i18n("sensors.sensor_esc2_status"),          id = 40,  group = "esc2" },
  [41] = { name = i18n("sensors.sensor_esc2_model"),           id = 41,  group = "esc2" },

  [42] = { name = i18n("sensors.sensor_esc_voltage"),          id = 42,  group = "esc" },
  [43] = { name = i18n("sensors.sensor_bec_voltage"),          id = 43,  group = "esc" },
  [44] = { name = i18n("sensors.sensor_bus_voltage"),          id = 44,  group = "esc" },
  [45] = { name = i18n("sensors.sensor_mcu_voltage"),          id = 45,  group = "esc" },

  [46] = { name = i18n("sensors.sensor_esc_current"),          id = 46,  group = "esc" },
  [47] = { name = i18n("sensors.sensor_bec_current"),          id = 47,  group = "esc" },
  [48] = { name = i18n("sensors.sensor_bus_current"),          id = 48,  group = "esc" },
  [49] = { name = i18n("sensors.sensor_mcu_current"),          id = 49,  group = "esc" },

  [50] = { name = i18n("sensors.sensor_esc_temp"),             id = 50,  group = "temps" },
  [51] = { name = i18n("sensors.sensor_bec_temp"),             id = 51,  group = "temps" },
  [52] = { name = i18n("sensors.sensor_mcu_temp"),             id = 52,  group = "temps" },
  [53] = { name = i18n("sensors.sensor_air_temp"),             id = 53,  group = "temps" },
  [54] = { name = i18n("sensors.sensor_motor_temp"),           id = 54,  group = "temps" },
  [55] = { name = i18n("sensors.sensor_battery_temp"),         id = 55,  group = "temps" },
  [56] = { name = i18n("sensors.sensor_exhaust_temp"),         id = 56,  group = "temps" },

  [57] = { name = i18n("sensors.sensor_heading"),              id = 57,  group = "nav" },
  [58] = { name = i18n("sensors.sensor_altitude"),             id = 58,  group = "nav" },
  [59] = { name = i18n("sensors.sensor_variometer"),           id = 59,  group = "nav" },

  [60] = { name = i18n("sensors.sensor_headspeed"),            id = 60,  group = "rpm" },
  [61] = { name = i18n("sensors.sensor_tailspeed"),            id = 61,  group = "rpm" },
  [62] = { name = i18n("sensors.sensor_motor_rpm"),            id = 62,  group = "rpm" },
  [63] = { name = i18n("sensors.sensor_trans_rpm"),            id = 63,  group = "rpm" },

  [64] = { name = i18n("sensors.sensor_attitude"),             id = 64,  group = "attitude" },
  [65] = { name = i18n("sensors.sensor_attitude_pitch"),       id = 65,  group = "attitude" },
  [66] = { name = i18n("sensors.sensor_attitude_roll"),        id = 66,  group = "attitude" },
  [67] = { name = i18n("sensors.sensor_attitude_yaw"),         id = 67,  group = "attitude" },

  [68] = { name = i18n("sensors.sensor_accel"),                id = 68,  group = "accel" },
  [69] = { name = i18n("sensors.sensor_accel_x"),              id = 69,  group = "accel" },
  [70] = { name = i18n("sensors.sensor_accel_y"),              id = 70,  group = "accel" },
  [71] = { name = i18n("sensors.sensor_accel_z"),              id = 71,  group = "accel" },

  [72] = { name = i18n("sensors.sensor_gps"),                  id = 72,  group = "gps" },
  [73] = { name = i18n("sensors.sensor_gps_sats"),             id = 73,  group = "gps" },
  [74] = { name = i18n("sensors.sensor_gps_pdop"),             id = 74,  group = "gps" },
  [75] = { name = i18n("sensors.sensor_gps_hdop"),             id = 75,  group = "gps" },
  [76] = { name = i18n("sensors.sensor_gps_vdop"),             id = 76,  group = "gps" },
  [77] = { name = i18n("sensors.sensor_gps_coord"),            id = 77,  group = "gps" },
  [78] = { name = i18n("sensors.sensor_gps_altitude"),         id = 78,  group = "gps" },
  [79] = { name = i18n("sensors.sensor_gps_heading"),          id = 79,  group = "gps" },
  [80] = { name = i18n("sensors.sensor_gps_groundspeed"),      id = 80,  group = "gps" },
  [81] = { name = i18n("sensors.sensor_gps_home_distance"),    id = 81,  group = "gps" },
  [82] = { name = i18n("sensors.sensor_gps_home_direction"),   id = 82,  group = "gps" },
  [83] = { name = i18n("sensors.sensor_gps_date_time"),        id = 83,  group = "gps" },

  [84] = { name = i18n("sensors.sensor_load"),                 id = 84,  group = "load" },
  [85] = { name = i18n("sensors.sensor_cpu_load"),             id = 85,  group = "load" },
  [86] = { name = i18n("sensors.sensor_sys_load"),             id = 86,  group = "load" },
  [87] = { name = i18n("sensors.sensor_rt_load"),              id = 87,  group = "load" },

  [88] = { name = i18n("sensors.sensor_model_id"),             id = 88,  group = "status" },
  [89] = { name = i18n("sensors.sensor_flight_mode"),          id = 89,  group = "status" },
  [90] = { name = i18n("sensors.sensor_arming_flags"),         id = 90,  group = "status" },
  [91] = { name = i18n("sensors.sensor_arming_disable_flags"), id = 91,  group = "status" },
  [92] = { name = i18n("sensors.sensor_rescue_state"),         id = 92,  group = "status" },
  [93] = { name = i18n("sensors.sensor_governor_state"),       id = 93,  group = "status" },
  [94] = { name = i18n("sensors.sensor_governor_flags"),       id = 94,  group = "status" },

  [95] = { name = i18n("sensors.sensor_pid_profile"),          id = 95,  group = "profiles" },
  [96] = { name = i18n("sensors.sensor_rates_profile"),        id = 96,  group = "profiles" },
  [97] = { name = i18n("sensors.sensor_battery_profile"),      id = 97,  group = "profiles" },
  [98] = { name = i18n("sensors.sensor_led_profile"),          id = 98,  group = "profiles" },

  [99] = { name = i18n("sensors.sensor_adjfunc"),              id = 99,  group = "tuning" },

  [100] = { name = i18n("sensors.sensor_debug_0"),             id = 100, group = "debug" },
  [101] = { name = i18n("sensors.sensor_debug_1"),             id = 101, group = "debug" },
  [102] = { name = i18n("sensors.sensor_debug_2"),             id = 102, group = "debug" },
  [103] = { name = i18n("sensors.sensor_debug_3"),             id = 103, group = "debug" },
  [104] = { name = i18n("sensors.sensor_debug_4"),             id = 104, group = "debug" },
  [105] = { name = i18n("sensors.sensor_debug_5"),             id = 105, group = "debug" },
  [106] = { name = i18n("sensors.sensor_debug_6"),             id = 106, group = "debug" },
  [107] = { name = i18n("sensors.sensor_debug_7"),             id = 107, group = "debug" },

  [108] = { name = i18n("sensors.sensor_rpm"),                 id = 108, group = "rpm" },
  [109] = { name = i18n("sensors.sensor_temp"),                id = 109, group = "temps" },
}

-- Display sections (groups)
local SENSOR_GROUPS = {
  general = {
    title = i18n("sensors.group_general"),
    ids = { 0, 1 },
  },
  battery = {
    title = i18n("sensors.group_battery"),
    ids = { 2, 3, 4, 5, 6 },
  },
  battery_cells = {
    title = i18n("sensors.group_battery_cells"),
    ids = { 7, 8, 9 },
  },
  control = {
    title = i18n("sensors.group_control"),
    ids = { 10, 11, 12, 13, 14, 15 },
  },
  esc1 = {
    title = i18n("sensors.group_esc1"),
    ids = { 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 },
  },
  esc2 = {
    title = i18n("sensors.group_esc2"),
    ids = { 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41 },
  },
  esc = {
    title = i18n("sensors.group_esc_common"),
    ids = { 42, 43, 44, 45, 46, 47, 48, 49 },
  },
  temps = {
    title = i18n("sensors.group_temperatures"),
    ids = { 50, 51, 52, 53, 54, 55, 56, 109 },
  },
  nav = {
    title = i18n("sensors.group_navigation"),
    ids = { 57, 58, 59 },
  },
  rpm = {
    title = i18n("sensors.group_rpm_speed"),
    ids = { 60, 61, 62, 63, 108 },
  },
  attitude = {
    title = i18n("sensors.group_attitude"),
    ids = { 64, 65, 66, 67 },
  },
  accel = {
    title = i18n("sensors.group_accel"),
    ids = { 68, 69, 70, 71 },
  },
  gps = {
    title = i18n("sensors.group_gps"),
    ids = { 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83 },
  },
  load = {
    title = i18n("sensors.group_load"),
    ids = { 84, 85, 86, 87 },
  },
  status = {
    title = i18n("sensors.group_status"),
    ids = { 88, 89, 90, 91, 92, 93, 94 },
  },
  profiles = {
    title = i18n("sensors.group_profiles"),
    ids = { 95, 96, 97, 98 },
  },
  tuning = {
    title = i18n("sensors.group_tuning"),
    ids = { 99 },
  },
  debug = {
    title = i18n("sensors.group_debug"),
    ids = { 100, 101, 102, 103, 104, 105, 106, 107 },
  },
}

-- Optional: control the visual order of sections when rendering
local GROUP_ORDER = {
  "general",
  "status",
  "profiles",
  "tuning",
  "control",
  "battery",
  "battery_cells",
  "esc1",
  "esc2",
  "esc",
  "temps",
  "rpm",
  "attitude",
  "accel",
  "gps",
  "nav",
  "load",
  "debug",
}


local function openPage(pidx, title, script)
    enableWakeup = false
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    -- track page
    rfsuite.app.lastIdx    = pidx
    rfsuite.app.lastTitle  = title
    rfsuite.app.lastScript = script

    -- header
    rfsuite.app.ui.fieldHeader(
        i18n("app.modules.sensors.name") 
    )

    rfsuite.app.formLineCnt = 0
    rfsuite.app.formFields = {}
    local config = {}

    local formFieldCount = 0

    for i,v in ipairs(GROUP_ORDER) do
        local group = SENSOR_GROUPS[v]
        if group and group.ids and #group.ids > 0 then
            local panel = form.addExpansionPanel(group.title)
            panel:open(false)
            for _,id in ipairs(group.ids) do
                local sensor = TELEMETRY_SENSORS[id]
                if sensor then
                    local line = panel:addLine(sensor.name)
                    formFieldCount = formFieldCount + 1
                    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1

                    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
                        line, nil,
                        function() return config[sensor.group] and config[sensor.group][sensor.id] or false end,
                        function(val)
                            if not config[sensor.group] then config[sensor.group] = {} end
                            config[sensor.group][sensor.id] = val
                        end
                    )
                end
            end
        end
    end
    

end   

local function wakeup()
    if enableWakeup == false then return end

end

return {
    openPage = openPage,
    eepromWrite = true,
    reboot = false,
    wakeup = wakeup,
    API = {},
    navButtons = {
        menu   = true,
        save   = true,
        reload = false,
        tool   = false,
        help   = false,
    },    
}
