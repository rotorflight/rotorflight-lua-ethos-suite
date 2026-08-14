-- MSP_GOVERNOR_CONFIG helper (cmd 142 read / 143 write).

if package.loaded["rfsuite.lib.msp_governor_config"] then
  return package.loaded["rfsuite.lib.msp_governor_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 142
local WRITE_COMMAND = 143

local MODE_CHOICES = {
  {"@i18n(api.GOVERNOR_CONFIG.tbl_govmode_off)@", 0},
  {"@i18n(api.GOVERNOR_CONFIG.tbl_govmode_limit)@", 1},
  {"@i18n(api.GOVERNOR_CONFIG.tbl_govmode_direct)@", 2},
  {"@i18n(api.GOVERNOR_CONFIG.tbl_govmode_electric)@", 3},
  {"@i18n(api.GOVERNOR_CONFIG.tbl_govmode_nitro)@", 4},
}

local THROTTLE_TYPE_CHOICES = {
  {"@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_normal)@", 0},
  {"@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_switch)@", 1},
  {"@i18n(api.GOVERNOR_CONFIG.tbl_throttle_type_function)@", 2},
}

local FIELDS = {
  {"gov_mode", "U8"},
  {"gov_startup_time", "U16"},
  {"gov_spoolup_time", "U16"},
  {"gov_tracking_time", "U16"},
  {"gov_recovery_time", "U16"},
  {"gov_throttle_hold_timeout", "U16"},
  {"spare_0", "U16"},
  {"gov_autorotation_timeout", "U16"},
  {"spare_1", "U16"},
  {"spare_2", "U16"},
  {"gov_handover_throttle", "U8"},
  {"gov_pwr_filter", "U8"},
  {"gov_rpm_filter", "U8"},
  {"gov_tta_filter", "U8"},
  {"gov_ff_filter", "U8"},
  {"spare_3", "U8"},
  {"gov_d_filter", "U8"},
  {"gov_spooldown_time", "U16"},
  {"gov_throttle_type", "U8"},
  {"spare_4", "S8"},
  {"spare_5", "S8"},
  {"governor_idle_throttle", "U8"},
  {"governor_auto_throttle", "U8"},
  {"gov_bypass_throttle_curve_1", "U8"},
  {"gov_bypass_throttle_curve_2", "U8"},
  {"gov_bypass_throttle_curve_3", "U8"},
  {"gov_bypass_throttle_curve_4", "U8"},
  {"gov_bypass_throttle_curve_5", "U8"},
  {"gov_bypass_throttle_curve_6", "U8"},
  {"gov_bypass_throttle_curve_7", "U8"},
  {"gov_bypass_throttle_curve_8", "U8"},
  {"gov_bypass_throttle_curve_9", "U8"},
}

local FIELD_META = {
  gov_mode = {choices = MODE_CHOICES},
  gov_startup_time = {min = 0, max = 600, default = 200, decimals = 1},
  gov_spoolup_time = {min = 0, max = 600, default = 100, decimals = 1, suffix = "s"},
  gov_tracking_time = {min = 0, max = 100, default = 10, decimals = 1, suffix = "s"},
  gov_recovery_time = {min = 0, max = 100, default = 21, decimals = 1, suffix = "s"},
  gov_throttle_hold_timeout = {min = 0, max = 250, default = 5, decimals = 1, suffix = "s"},
  gov_autorotation_timeout = {min = 0, max = 250, default = 0, suffix = "s"},
  gov_handover_throttle = {min = 0, max = 50, default = 20, suffix = "%"},
  gov_pwr_filter = {min = 0, max = 250, default = 20, suffix = "Hz"},
  gov_rpm_filter = {min = 0, max = 250, default = 20, suffix = "Hz"},
  gov_tta_filter = {min = 0, max = 250, default = 20, suffix = "Hz"},
  gov_ff_filter = {min = 0, max = 25, default = 10, suffix = "Hz"},
  gov_d_filter = {min = 0, max = 250, default = 50, decimals = 1, suffix = "Hz"},
  gov_spooldown_time = {min = 0, max = 600, default = 100, decimals = 1, suffix = "s"},
  gov_throttle_type = {choices = THROTTLE_TYPE_CHOICES},
  governor_idle_throttle = {min = 0, max = 250, default = 0, decimals = 1, suffix = "%"},
  governor_auto_throttle = {min = 0, max = 250, default = 0, decimals = 1, suffix = "%"},
}

local SIMULATOR_RESPONSE = {
  2,
  200, 0,
  100, 0,
  20, 0,
  20, 0,
  50, 0,
  0, 0,
  0, 0,
  0, 0,
  0, 0,
  20,
  20,
  20,
  0,
  10,
  0,
  50,
  30, 0,
  0,
  0,
  0,
  10,
  10,
  0,
  10,
  20,
  30,
  50,
  60,
  70,
  80,
  100,
}

local msp_governor_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELD_META = FIELD_META,
  MODE_CHOICES = MODE_CHOICES,
  THROTTLE_TYPE_CHOICES = THROTTLE_TYPE_CHOICES,
}

local function readByType(buf, wireType)
  if wireType == "U16" then return mspcodec.readU16(buf) end
  if wireType == "S8" then return mspcodec.readS8(buf) end
  return mspcodec.readU8(buf)
end

local function writeByType(buf, wireType, value)
  if wireType == "U16" then
    mspcodec.writeU16(buf, value or 0)
  elseif wireType == "S8" then
    mspcodec.writeS8(buf, value or 0)
  else
    mspcodec.writeU8(buf, value or 0)
  end
end

function msp_governor_config.decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    data[name] = readByType(buf, wireType)
  end
  return data
end

function msp_governor_config.encode(data)
  local payload = {}
  data = data or {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    writeByType(payload, wireType, data[name])
  end
  return payload
end

function msp_governor_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_governor_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_governor_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_governor_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_governor_config"] = msp_governor_config
return msp_governor_config
