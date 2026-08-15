-- MSP_BATTERY_PROFILE helper (cmd 175 read / 176 write).

if package.loaded["rfsuite.lib.msp_battery_profile"] then
  return package.loaded["rfsuite.lib.msp_battery_profile"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 175
local WRITE_COMMAND = 176

local PROFILE_CHOICES = {
  {"1", 0},
  {"2", 1},
  {"3", 2},
  {"4", 3},
  {"5", 4},
  {"6", 5},
}

local FIELD_META = {
  batteryProfile = {choices = PROFILE_CHOICES},
}

local msp_battery_profile = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELD_META = FIELD_META,
  PROFILE_CHOICES = PROFILE_CHOICES,
}

function msp_battery_profile.decode(buf)
  buf.offset = 1
  return {batteryProfile = mspcodec.readU8(buf)}
end

function msp_battery_profile.encode(data)
  local payload = {}
  mspcodec.writeU8(payload, data and data.batteryProfile or 0)
  return payload
end

function msp_battery_profile.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_battery_profile.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = {0},
  }
end

function msp_battery_profile.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_battery_profile.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_battery_profile"] = msp_battery_profile
return msp_battery_profile
