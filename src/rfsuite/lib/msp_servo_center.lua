-- MSP_SET_SERVO_CENTER helper (cmd 213).

if package.loaded["rfsuite.lib.msp_servo_center"] then
  return package.loaded["rfsuite.lib.msp_servo_center"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local WRITE_COMMAND = 213

local msp_servo_center = {
  WRITE_COMMAND = WRITE_COMMAND,
}

function msp_servo_center.buildWriteMessage(index, mid, onWritten, onError)
  local payload = {tonumber(index) or 0}
  mspcodec.writeU16(payload, mid or 1500)
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

package.loaded["rfsuite.lib.msp_servo_center"] = msp_servo_center
return msp_servo_center
