-- MSP_MOTOR (cmd 104, read-only): the live output of the first eight motors.
--
-- rotorflight-firmware src/main/msp/msp.c (MSP_MOTOR): eight U16. 0 means the
-- motor is not configured or not enabled; otherwise the output + 1000 (a
-- reversing motor below zero is sent as output - 1000).
--
-- decode() fills a caller's table in place (out[1] is motor 1).

if package.loaded["rfsuite.lib.msp_motor"] then
  return package.loaded["rfsuite.lib.msp_motor"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 104

-- Main motor present and stopped, no tail motor.
local SIMULATOR_RESPONSE = {232, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

local M = {READ_COMMAND = READ_COMMAND}

function M.decode(buf, out)
  buf.offset = 1
  local count = math.floor(#buf / 2)
  for i = 1, count do out[i] = mspcodec.readU16(buf) end
  for i = #out, count + 1, -1 do out[i] = nil end
  return count
end

function M.buildReadMessage(out, onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local count = M.decode(buf, out)
      if onData then onData(out, count) end
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

package.loaded["rfsuite.lib.msp_motor"] = M
return M
