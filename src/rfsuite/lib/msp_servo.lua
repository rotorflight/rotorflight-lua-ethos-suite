-- MSP_SERVO (cmd 103, read-only): the live output of every servo, in us.
--
-- Wire layout verified against rotorflight-firmware's src/main/msp/msp.c
-- (MSP_SERVO): one U16 per servo and nothing else, so the count is the reply
-- length / 2. Without bus servos that is MAX_SUPPORTED_SERVOS outputs; with
-- them, the configured PWM servos and then the bus servos. Either way the PWM
-- servos come first, at index 0..n-1, which is all the Setup Wizard reads.
--
-- decode() fills a caller's table in place, so a page polling this several
-- times a second does not allocate a new table per reply.

if package.loaded["rfsuite.lib.msp_servo"] then
  return package.loaded["rfsuite.lib.msp_servo"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 103

-- Eight servos at 1500 us.
local SIMULATOR_RESPONSE = {}
for i = 1, 8 do
  SIMULATOR_RESPONSE[2 * i - 1] = 220
  SIMULATOR_RESPONSE[2 * i] = 5
end

local msp_servo = {READ_COMMAND = READ_COMMAND}

-- Output of servo i (0-based) lands in out[i]; entries past the reply are
-- cleared. Returns the servo count.
function msp_servo.decode(buf, out)
  buf.offset = 1
  local count = math.floor(#buf / 2)
  for i = 0, count - 1 do
    out[i] = mspcodec.readU16(buf)
  end
  local i = count
  while out[i] ~= nil do
    out[i] = nil
    i = i + 1
  end
  return count
end

-- onData(out, count) gets the caller's own `out` table back.
function msp_servo.buildReadMessage(out, onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local count = msp_servo.decode(buf, out)
      if onData then onData(out, count) end
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

package.loaded["rfsuite.lib.msp_servo"] = msp_servo
return msp_servo
