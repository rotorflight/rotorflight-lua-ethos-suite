-- MSP_SERVO_OVERRIDE / MSP_SERVO_OVERRIDE_ALL helpers
-- (cmd 193 indexed write / 196 all-servos write).

if package.loaded["rfsuite.lib.msp_servo_override"] then
  return package.loaded["rfsuite.lib.msp_servo_override"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local WRITE_COMMAND = 193
local WRITE_ALL_COMMAND = 196
local OVERRIDE_OFF = 2001
local OVERRIDE_CENTER = 0

local msp_servo_override = {
  WRITE_COMMAND = WRITE_COMMAND,
  WRITE_ALL_COMMAND = WRITE_ALL_COMMAND,
  OVERRIDE_OFF = OVERRIDE_OFF,
  OVERRIDE_CENTER = OVERRIDE_CENTER,
}

local function writeValue(value)
  local payload = {}
  mspcodec.writeU16(payload, value or OVERRIDE_OFF)
  return payload
end

function msp_servo_override.buildWriteMessage(index, value, onWritten, onError)
  local payload = {tonumber(index) or 0}
  mspcodec.writeU16(payload, value or OVERRIDE_OFF)
  return {
    command = WRITE_COMMAND,
    payload = payload,
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

function msp_servo_override.buildWriteAllMessage(value, onWritten, onError)
  return {
    command = WRITE_ALL_COMMAND,
    payload = writeValue(value),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_servo_override"] = msp_servo_override
return msp_servo_override
