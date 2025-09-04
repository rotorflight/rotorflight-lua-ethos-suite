local i18n = rfsuite.i18n.get
local enableWakeup = false

local mspData = nil
local config = {}
local triggerSave = false
local configLoaded = false
local configApplied = false
local setDefaultSensors = false
local PREV_STATE = {}

-- Lookup table (by ID)
local TELEMETRY_SENSORS = {
  [0]   = { name = i18n("telemetry.sensor_none"),                 id = 0,   group = "system" },
  [1]   = { name = i18n("telemetry.sensor_heartbeat"),            id = 1,   group = "system" },

  [2]   = { name = i18n("telemetry.sensor_battery"),              id = 2,   group = "battery" },
  [3]   = { name = i18n("telemetry.sensor_battery_voltage"),      id = 3,   group = "battery" },
  [4]   = { name = i18n("telemetry.sensor_battery_current"),      id = 4,   group = "battery" },
  [5]   = { name = i18n("telemetry.sensor_battery_consumption"),  id = 5,   group = "battery" },
  [6]   = { name = i18n("telemetry.sensor_battery_charge_level"), id = 6,   group = "battery" },
  [7]   = { name = i18n("telemetry.sensor_battery_cell_count"),   id = 7,   group = "battery" },
  [8]   = { name = i18n("telemetry.sensor_battery_cell_voltage"), id = 8,   group = "battery" },
  [9]   = { name = i18n("telemetry.sensor_battery_cell_voltages"),id = 9,   group = "battery" },

  [10]  = { name = i18n("telemetry.sensor_control"),              id = 10,  group = "control" },
  [11]  = { name = i18n("telemetry.sensor_pitch_control"),        id = 11,  group = "control" },
  [12]  = { name = i18n("telemetry.sensor_roll_control"),         id = 12,  group = "control" },
  [13]  = { name = i18n("telemetry.sensor_yaw_control"),          id = 13,  group = "control" },
  [14]  = { name = i18n("telemetry.sensor_collective_control"),   id = 14,  group = "control" },
  [15]  = { name = i18n("telemetry.sensor_throttle_control"),     id = 15,  group = "control" },

  [16]  = { name = i18n("telemetry.sensor_esc1_data"),            id = 16,  group = "esc1" },
  [17]  = { name = i18n("telemetry.sensor_esc1_voltage"),         id = 17,  group = "esc1" },
  [18]  = { name = i18n("telemetry.sensor_esc1_current"),         id = 18,  group = "esc1" },
  [19]  = { name = i18n("telemetry.sensor_esc1_capacity"),        id = 19,  group = "esc1" },
  [20]  = { name = i18n("telemetry.sensor_esc1_erpm"),            id = 20,  group = "esc1" },
  [21]  = { name = i18n("telemetry.sensor_esc1_power"),           id = 21,  group = "esc1" },
  [22]  = { name = i18n("telemetry.sensor_esc1_throttle"),        id = 22,  group = "esc1" },
  [23]  = { name = i18n("telemetry.sensor_esc1_temp1"),           id = 23,  group = "esc1" },
  [24]  = { name = i18n("telemetry.sensor_esc1_temp2"),           id = 24,  group = "esc1" },
  [25]  = { name = i18n("telemetry.sensor_esc1_bec_voltage"),     id = 25,  group = "esc1" },
  [26]  = { name = i18n("telemetry.sensor_esc1_bec_current"),     id = 26,  group = "esc1" },
  [27]  = { name = i18n("telemetry.sensor_esc1_status"),          id = 27,  group = "esc1" },
  [28]  = { name = i18n("telemetry.sensor_esc1_model"),           id = 28,  group = "esc1" },

  [29]  = { name = i18n("telemetry.sensor_esc2_data"),            id = 29,  group = "esc2" },
  [30]  = { name = i18n("telemetry.sensor_esc2_voltage"),         id = 30,  group = "esc2" },
  [31]  = { name = i18n("telemetry.sensor_esc2_current"),         id = 31,  group = "esc2" },
  [32]  = { name = i18n("telemetry.sensor_esc2_capacity"),        id = 32,  group = "esc2" },
  [33]  = { name = i18n("telemetry.sensor_esc2_erpm"),            id = 33,  group = "esc2" },
  [34]  = { name = i18n("telemetry.sensor_esc2_power"),           id = 34,  group = "esc2" },
  [35]  = { name = i18n("telemetry.sensor_esc2_throttle"),        id = 35,  group = "esc2" },
  [36]  = { name = i18n("telemetry.sensor_esc2_temp1"),           id = 36,  group = "esc2" },
  [37]  = { name = i18n("telemetry.sensor_esc2_temp2"),           id = 37,  group = "esc2" },
  [38]  = { name = i18n("telemetry.sensor_esc2_bec_voltage"),     id = 38,  group = "esc2" },
  [39]  = { name = i18n("telemetry.sensor_esc2_bec_current"),     id = 39,  group = "esc2" },
  [40]  = { name = i18n("telemetry.sensor_esc2_status"),          id = 40,  group = "esc2" },
  [41]  = { name = i18n("telemetry.sensor_esc2_model"),           id = 41,  group = "esc2" },

  [42]  = { name = i18n("telemetry.sensor_esc_voltage"),          id = 42,  group = "voltage" },
  [43]  = { name = i18n("telemetry.sensor_bec_voltage"),          id = 43,  group = "voltage" },
  [44]  = { name = i18n("telemetry.sensor_bus_voltage"),          id = 44,  group = "voltage" },
  [45]  = { name = i18n("telemetry.sensor_mcu_voltage"),          id = 45,  group = "voltage" },

  [46]  = { name = i18n("telemetry.sensor_esc_current"),          id = 46,  group = "current" },
  [47]  = { name = i18n("telemetry.sensor_bec_current"),          id = 47,  group = "current" },
  [48]  = { name = i18n("telemetry.sensor_bus_current"),          id = 48,  group = "current" },
  [49]  = { name = i18n("telemetry.sensor_mcu_current"),          id = 49,  group = "current" },

  [50]  = { name = i18n("telemetry.sensor_esc_temp"),             id = 50,  group = "temps" },
  [51]  = { name = i18n("telemetry.sensor_bec_temp"),             id = 51,  group = "temps" },
  [52]  = { name = i18n("telemetry.sensor_mcu_temp"),             id = 52,  group = "temps" },
  [53]  = { name = i18n("telemetry.sensor_air_temp"),             id = 53,  group = "temps" },
  [54]  = { name = i18n("telemetry.sensor_motor_temp"),           id = 54,  group = "temps" },
  [55]  = { name = i18n("telemetry.sensor_battery_temp"),         id = 55,  group = "temps" },
  [56]  = { name = i18n("telemetry.sensor_exhaust_temp"),         id = 56,  group = "temps" },

  [57]  = { name = i18n("telemetry.sensor_heading"),              id = 57,  group = "gyro" },
  [58]  = { name = i18n("telemetry.sensor_altitude"),             id = 58,  group = "barometer" },
  [59]  = { name = i18n("telemetry.sensor_variometer"),           id = 59,  group = "barometer" },

  [60]  = { name = i18n("telemetry.sensor_headspeed"),            id = 60,  group = "rpm" },
  [61]  = { name = i18n("telemetry.sensor_tailspeed"),            id = 61,  group = "rpm" },
  [62]  = { name = i18n("telemetry.sensor_motor_rpm"),            id = 62,  group = "rpm" },
  [63]  = { name = i18n("telemetry.sensor_trans_rpm"),            id = 63,  group = "rpm" },

  [64]  = { name = i18n("telemetry.sensor_attitude"),             id = 64,  group = "gyro" },
  [65]  = { name = i18n("telemetry.sensor_attitude_pitch"),       id = 65,  group = "gyro" },
  [66]  = { name = i18n("telemetry.sensor_attitude_roll"),        id = 66,  group = "gyro" },
  [67]  = { name = i18n("telemetry.sensor_attitude_yaw"),         id = 67,  group = "gyro" },

  [68]  = { name = i18n("telemetry.sensor_accel"),                id = 68,  group = "gyro" },
  [69]  = { name = i18n("telemetry.sensor_accel_x"),              id = 69,  group = "gyro" },
  [70]  = { name = i18n("telemetry.sensor_accel_y"),              id = 70,  group = "gyro" },
  [71]  = { name = i18n("telemetry.sensor_accel_z"),              id = 71,  group = "gyro" },

  [72]  = { name = i18n("telemetry.sensor_gps"),                  id = 72,  group = "gps" },
  [73]  = { name = i18n("telemetry.sensor_gps_sats"),             id = 73,  group = "gps" },
  [74]  = { name = i18n("telemetry.sensor_gps_pdop"),             id = 74,  group = "gps" },
  [75]  = { name = i18n("telemetry.sensor_gps_hdop"),             id = 75,  group = "gps" },
  [76]  = { name = i18n("telemetry.sensor_gps_vdop"),             id = 76,  group = "gps" },
  [77]  = { name = i18n("telemetry.sensor_gps_coord"),            id = 77,  group = "gps" },
  [78]  = { name = i18n("telemetry.sensor_gps_altitude"),         id = 78,  group = "gps" },
  [79]  = { name = i18n("telemetry.sensor_gps_heading"),          id = 79,  group = "gps" },
  [80]  = { name = i18n("telemetry.sensor_gps_groundspeed"),      id = 80,  group = "gps" },
  [81]  = { name = i18n("telemetry.sensor_gps_home_distance"),    id = 81,  group = "gps" },
  [82]  = { name = i18n("telemetry.sensor_gps_home_direction"),   id = 82,  group = "gps" },
  [83]  = { name = i18n("telemetry.sensor_gps_date_time"),        id = 83,  group = "gps" },

  [84]  = { name = i18n("telemetry.sensor_load"),                 id = 84,  group = "load" },
  [85]  = { name = i18n("telemetry.sensor_cpu_load"),             id = 85,  group = "system" },
  [86]  = { name = i18n("telemetry.sensor_sys_load"),             id = 86,  group = "system" },
  [87]  = { name = i18n("telemetry.sensor_rt_load"),              id = 87,  group = "system" },

  [88]  = { name = i18n("telemetry.sensor_model_id"),             id = 88,  group = "status" },
  [89]  = { name = i18n("telemetry.sensor_flight_mode"),          id = 89,  group = "status" },
  [90]  = { name = i18n("telemetry.sensor_arming_flags"),         id = 90,  group = "status" },
  [91]  = { name = i18n("telemetry.sensor_arming_disable_flags"), id = 91,  group = "status" },
  [92]  = { name = i18n("telemetry.sensor_rescue_state"),         id = 92,  group = "status" },
  [93]  = { name = i18n("telemetry.sensor_governor_state"),       id = 93,  group = "status" },
  [94]  = { name = i18n("telemetry.sensor_governor_flags"),       id = 94,  group = "status" },

  [95]  = { name = i18n("telemetry.sensor_pid_profile"),          id = 95,  group = "profiles" },
  [96]  = { name = i18n("telemetry.sensor_rates_profile"),        id = 96,  group = "profiles" },
  [97]  = { name = i18n("telemetry.sensor_battery_profile"),      id = 97,  group = "profiles" },
  [98]  = { name = i18n("telemetry.sensor_led_profile"),          id = 98,  group = "profiles" },

  [99]  = { name = i18n("telemetry.sensor_adjfunc"),              id = 99,  group = "status" },

  [100] = { name = i18n("telemetry.sensor_debug_0"),              id = 100, group = "debug" },
  [101] = { name = i18n("telemetry.sensor_debug_1"),              id = 101, group = "debug" },
  [102] = { name = i18n("telemetry.sensor_debug_2"),              id = 102, group = "debug" },
  [103] = { name = i18n("telemetry.sensor_debug_3"),              id = 103, group = "debug" },
  [104] = { name = i18n("telemetry.sensor_debug_4"),              id = 104, group = "debug" },
  [105] = { name = i18n("telemetry.sensor_debug_5"),              id = 105, group = "debug" },
  [106] = { name = i18n("telemetry.sensor_debug_6"),              id = 106, group = "debug" },
  [107] = { name = i18n("telemetry.sensor_debug_7"),              id = 107, group = "debug" },

  [108] = { name = i18n("telemetry.sensor_rpm"),                  id = 108, group = "rpm" },
  [109] = { name = i18n("telemetry.sensor_temp"),                 id = 109, group = "temps" },
}

-- Display sections (groups)
local SENSOR_GROUPS = {
  voltage = {
    title = i18n("telemetry.group_voltage"),
    ids = { 42, 43, 44, 45 },
  },
  battery = {
    title = i18n("telemetry.group_battery"),
    ids = { 3, 4, 5, 6, 7, 8 },
  },
  control = {
    title = i18n("telemetry.group_control"),
    ids = { 10, 11, 12, 13, 14, 15 },
  },
  esc1 = {
    title = i18n("telemetry.group_esc1"),
    ids = { 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 },
  },
  esc2 = {
    title = i18n("telemetry.group_esc2"),
    ids = { 30, 31, 32, 33, 36, 41 },
  },
  current = {
    title = i18n("telemetry.group_current"),
    ids = { 46, 47, 48, 49 },
  },
  temps = {
    title = i18n("telemetry.group_temperatures"),
    ids = { 50, 51, 52 },
  },
  barometer = {
    title = i18n("telemetry.group_barometer"),
    ids = { 58, 59 },
  },
  rpm = {
    title = i18n("telemetry.group_rpm"),
    ids = { 60, 61 },
  },
  gyro = {
    title = i18n("telemetry.group_gyro"),
    ids = { 57, 64, 65, 66, 67, 68, 69, 70, 71 },
  },
  gps = {
    title = i18n("telemetry.group_gps"),
    ids = { 73, 74, 77, 78, 79, 80, 81, 82 },
  },
  system = {
    title = i18n("telemetry.group_load"),
    ids = { 1, 85, 86, 87 },
  },
  status = {
    title = i18n("telemetry.group_status"),
    ids = { 88, 89, 90, 91, 92, 93, 99 },
  },
  profiles = {
    title = i18n("telemetry.group_profiles"),
    ids = { 95, 96, 98 },
  },
  tuning = {
    title = i18n("telemetry.group_tuning"),
    ids = { 99 },
  },
  debug = {
    title = i18n("telemetry.group_debug"),
    ids = { 100, 101, 102, 103, 104, 105, 106, 107 },
  },
}

local NOT_AT_SAME_TIME = {
  [10] = {11, 12, 13, 14},  -- control
  [64] = {65, 66, 67},      -- attitude
  [68] = {69, 70, 71},      -- accel

}

-- Optional: control the visual order of sections when rendering
local GROUP_ORDER = {
  "battery",
  "voltage",
  "current",
  "temps",
  "esc1",
  "esc2",
  "rpm",
  "barometer",
  "gyro",
  "gps",
  "status",
  "profiles",
  "control",
  "system",
  "debug",
}

local function countEnabledSensors()
  local count = 0
  for _, v in pairs(config) do
    if v == true then
      count = count + 1
    end
  end
  return count
end

local function alertIfTooManySensors()
  local buttons = {{
    label = i18n("app.modules.profile_select.ok"),
    action = function()
      return true
    end,
  }}

  form.openDialog({
    width = nil,
    title = i18n("app.modules.telemetry.name"),
    message = i18n("app.modules.telemetry.no_more_than_40"),
    buttons = buttons,
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })
end

local function openPage(pidx, title, script)
  form.clear()

  -- track page
  rfsuite.app.lastIdx    = pidx
  rfsuite.app.lastTitle  = title
  rfsuite.app.lastScript = script

  -- header
  rfsuite.app.ui.fieldHeader(i18n("app.modules.telemetry.name"))

  rfsuite.app.formLineCnt = 0
  rfsuite.app.formFields = {}

  -- quick exit if running unsupported version of msp protocol
  if rfsuite.utils.apiVersionCompare("<", "12.08") then
    rfsuite.app.triggers.closeProgressLoader = true

    rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine(i18n("app.modules.telemetry.invalid_version"))

    rfsuite.app.formNavigationFields["save"]:enable(false)
    rfsuite.app.formNavigationFields["reload"]:enable(false)

    return
  end

  local formFieldCount = 0

  for _, key in ipairs(GROUP_ORDER) do
    local group = SENSOR_GROUPS[key]
    if group and group.ids and #group.ids > 0 then
      local panel = form.addExpansionPanel(group.title)
      panel:open(false)
      for _, id in ipairs(group.ids) do
        local sensor = TELEMETRY_SENSORS[id]
        if sensor then
          local line = panel:addLine(sensor.name)
          formFieldCount = id -- keep index aligned with sensor ID
          rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1

          rfsuite.app.formFields[formFieldCount] = form.addBooleanField(
            line,
            nil,
            function()
              return config[sensor.id] or false
            end,
            function(val)
              local count = countEnabledSensors()
              if count > 40 then
                alertIfTooManySensors()
                return false
              end

              if val == true and NOT_AT_SAME_TIME[sensor.id] then
                -- disable conflicting sensors
                for _, conflictId in ipairs(NOT_AT_SAME_TIME[sensor.id]) do
                  -- remember previous state
                  PREV_STATE[conflictId] = config[conflictId]

                  config[conflictId] = false
                  if rfsuite.app.formFields[conflictId] then
                    rfsuite.app.formFields[conflictId]:enable(false)
                  end
                end

              elseif val == false and NOT_AT_SAME_TIME[sensor.id] then
                -- re-enable conflicting sensors
                for _, conflictId in ipairs(NOT_AT_SAME_TIME[sensor.id]) do
                  if rfsuite.app.formFields[conflictId] then
                    rfsuite.app.formFields[conflictId]:enable(true)
                  end

                  -- restore previous state if we saved one
                  if PREV_STATE[conflictId] ~= nil then
                    config[conflictId] = PREV_STATE[conflictId]
                    PREV_STATE[conflictId] = nil -- clear after restoring
                  end
                end
              end            

              config[sensor.id] = val
            end
          )
        end
      end
    end
  end

  enableWakeup = true
end

local function rebootFC()
  local RAPI = rfsuite.tasks.msp.api.load("REBOOT")
  RAPI.setUUID("123e4567-e89b-12d3-a456-426614174000")
  RAPI.setCompleteHandler(function(self)
    rfsuite.utils.log("Rebooting FC", "info")
    rfsuite.utils.onReboot()
  end)
  RAPI.write()
end

local function applySettings()
  local EAPI = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
  EAPI.setUUID("550e8400-e29b-41d4-a716-446655440000")
  EAPI.setCompleteHandler(function(self)
    rfsuite.utils.log("Writing to EEPROM", "info")
    rebootFC()
  end)
  EAPI.write()
end

local function getDefaultSensors(sensorList)
  local defaultSensors = {}
  local i = 0
  for _, sensor in pairs(sensorList) do
    if sensor["mandatory"] == true and sensor["set_telemetry_sensors"] ~= nil then
      defaultSensors[i] = sensor["set_telemetry_sensors"]
      i = i + 1
    end
  end
  return defaultSensors
end

local function wakeup()
  if enableWakeup == false then return end

  -- get the current config from fbl
  if not rfsuite.app.Page.configLoaded then
    local API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
    API.setCompleteHandler(function(self, buf)
      local hasData = API.readValue("telem_sensor_slot_40")
      if hasData then
        rfsuite.app.Page.mspData = API.data()
        rfsuite.app.Page.configLoaded = true
      end
    end)
    API.setUUID("a23e4567-e89b-12d3-a456-426614174001")
    API.read()
  end

  -- if we have data, populate config if empty (stop as soon as config has something in it)
  if rfsuite.app.Page and rfsuite.app.Page.configLoaded == true and rfsuite.app.Page.configApplied == false then
    local parsed = rfsuite.app.Page.mspData.parsed
    for _, value in pairs(parsed) do
      -- by default field is 'false' so only set true values
      if value ~= 0 then
        config[value] = true
      end
    end
    rfsuite.app.Page.configApplied = true
    rfsuite.app.triggers.closeProgressLoader = true
  end

  -- save?
  if triggerSave == true then
    rfsuite.app.ui.progressDisplaySave(i18n("app.modules.profile_select.save_settings"))

    local selectedSensors = {}

    -- add selected sensors first
    for k, v in pairs(config) do
      if v == true then
        table.insert(selectedSensors, k)
      end
    end

    local WRITEAPI = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
    WRITEAPI.setUUID("123e4567-e89b-12d3-a456-426614174000")
    WRITEAPI.setCompleteHandler(function(self, buf)
      applySettings()
    end)

    local buffer = rfsuite.app.Page.mspData["buffer"] -- Existing buffer
    local sensorIndex = 13 -- Start at byte 13 (1-based indexing)

    -- Insert new sensors into buffer
    for _, sensor_id in ipairs(selectedSensors) do
      if sensorIndex <= 52 then -- 13 bytes + 40 sensor slots = 53 max (1-based)
        buffer[sensorIndex] = sensor_id
        sensorIndex = sensorIndex + 1
      else
        break -- Stop if buffer limit is reached
      end
    end

    -- Fill remaining slots with zeros
    for i = sensorIndex, 52 do
      buffer[i] = 0
    end

    -- Send updated buffer
    WRITEAPI.write(buffer)

    triggerSave = false
  end

  if setDefaultSensors == true then
    local sensorList = getDefaultSensors(rfsuite.tasks.telemetry.listSensors())
    for _, v in pairs(sensorList) do
      config[v] = true
    end
    setDefaultSensors = false
  end
end

local function onSaveMenu()
  local buttons = {{
    label = i18n("app.btn_ok_long"),
    action = function()
      triggerSave = true
      return true
    end,
  }, {
    label = i18n("app.modules.profile_select.cancel"),
    action = function()
      triggerSave = false
      return true
    end,
  }}

  form.openDialog({
    width = nil,
    title = i18n("app.modules.profile_select.save_settings"),
    message = i18n("app.modules.profile_select.save_prompt"),
    buttons = buttons,
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })

  triggerSave = false
end

local function onToolMenu(self)
  local buttons = {{
    label = rfsuite.i18n.get("app.btn_ok"),
    action = function()
      -- we push this to the background task to do its job
      setDefaultSensors = true
      return true
    end,
  }, {
    label = rfsuite.i18n.get("app.btn_cancel"),
    action = function()
      return true
    end,
  }}

  form.openDialog({
    width = nil,
    title = rfsuite.i18n.get("app.modules.telemetry.name"),
    message = rfsuite.i18n.get("app.modules.telemetry.msg_set_defaults"),
    buttons = buttons,
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })
end

return {
  mspData = mspData, -- expose for other modules
  openPage = openPage,
  eepromWrite = true,
  onSaveMenu = onSaveMenu,
  onToolMenu = onToolMenu,
  reboot = false,
  wakeup = wakeup,
  API = {},
  configLoaded = configLoaded,
  configApplied = configApplied,
  navButtons = {
    menu   = true,
    save   = true,
    reload = true,
    tool   = true,
    help   = false,
  },
}
