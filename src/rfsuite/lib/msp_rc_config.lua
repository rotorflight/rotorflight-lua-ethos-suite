-- Schema + message-builders for the MSP_RC_CONFIG /
-- MSP_SET_RC_CONFIG command pair (cmd 66 read / 67 write) -- used by
-- app/pages/radio_config.lua.
--
-- Rotorflight 2.3 / MSP API >= 12.09 is this rebuild's floor, so the
-- page only exposes the current field set used by the original suite's
-- >= 12.0.9 branch: stick center/deflection, min/max throttle, and
-- cyclic/yaw deadband. rc_arm_throttle remains wire-present in the
-- command for read/write round-tripping, but is not shown on the page.

if package.loaded["rfsuite.lib.msp_rc_config"] then
  return package.loaded["rfsuite.lib.msp_rc_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 66
local WRITE_COMMAND = 67

-- {name, wireType}, in exact wire order -- matches the original suite's
-- tasks/scheduler/msp/api/RC_CONFIG.lua FIELD_SPEC.
local FIELDS = {
  {"rc_center", "U16"},
  {"rc_deflection", "U16"},
  {"rc_arm_throttle", "U16"},
  {"rc_min_throttle", "U16"},
  {"rc_max_throttle", "U16"},
  {"rc_deadband", "U8"},
  {"rc_yaw_deadband", "U8"},
}

local SIMULATOR_RESPONSE = {
  220, 5, -- rc_center
  254, 1, -- rc_deflection
  232, 3, -- rc_arm_throttle
  242, 3, -- rc_min_throttle
  208, 7, -- rc_max_throttle
  4,      -- rc_deadband
  4,      -- rc_yaw_deadband
}

local FIELD_META = {
  rc_center = {min = 1400, max = 1600, default = 1500, suffix = "us"},
  rc_deflection = {min = 200, max = 700, default = 510, suffix = "us"},
  rc_arm_throttle = {min = 850, max = 1500, default = 1050, suffix = "us"},
  rc_min_throttle = {min = 860, max = 1500, default = 1100, suffix = "us"},
  rc_max_throttle = {min = 1510, max = 2150, default = 1900, suffix = "us"},
  rc_deadband = {min = 0, max = 100, default = 2, suffix = "us"},
  rc_yaw_deadband = {min = 0, max = 100, default = 2, suffix = "us"},
}

local msp_rc_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
}

function msp_rc_config.decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    if wireType == "U16" then
      data[name] = mspcodec.readU16(buf)
    else
      data[name] = mspcodec.readU8(buf)
    end
  end
  return data
end

function msp_rc_config.encode(data)
  local payload = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    if wireType == "U16" then
      mspcodec.writeU16(payload, data[name] or 0)
    else
      mspcodec.writeU8(payload, data[name] or 0)
    end
  end
  return payload
end

function msp_rc_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_rc_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_rc_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_rc_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_rc_config"] = msp_rc_config
return msp_rc_config
