-- MSP_ANALOG helper (cmd 110, read only): the battery and link readings the flight controller
-- measures itself. Used by the ESC telemetry step to show the voltage and current of a source
-- that is not the ESC (ADC or FrSky F.BUS). Same wire shape as the EdgeTX suite's
-- tasks/msp/api/analog.lua.
--
-- Nine bytes: legacy voltage (U8, 0.1 V), mAh drawn (U16), RSSI (U16, 0..1023), current (U16,
-- 0.01 A), voltage (U16, 0.01 V). A shorter reply is refused, not read with zeros.

if package.loaded["rfsuite.lib.msp_analog"] then
  return package.loaded["rfsuite.lib.msp_analog"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 110
local REPLY_BYTES = 9

local msp_analog = {
  READ_COMMAND = READ_COMMAND,
  REPLY_BYTES = REPLY_BYTES,
}

local SIMULATOR_RESPONSE = {
  248,     -- legacy voltage 24.8 V
  0, 0,    -- mAh drawn 0
  255, 3,  -- RSSI 1023
  50, 0,   -- current 0.50 A
  176, 9,  -- voltage 24.80 V
}

function msp_analog.decode(buf)
  buf.offset = 1
  return {
    legacy_voltage = mspcodec.readU8(buf),
    mah_drawn = mspcodec.readU16(buf),
    rssi = mspcodec.readU16(buf),
    current = mspcodec.readU16(buf),
    voltage = mspcodec.readU16(buf),
  }
end

function msp_analog.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      if #buf < REPLY_BYTES then
        if onError then onError() end
        return
      end
      if onData then onData(msp_analog.decode(buf)) end
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

package.loaded["rfsuite.lib.msp_analog"] = msp_analog
return msp_analog
