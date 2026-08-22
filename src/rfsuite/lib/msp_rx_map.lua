-- Message-builder for MSP_RX_MAP (cmd 64, read-only here -- this suite never
-- writes it). Standard MultiWii-lineage command: 8 bytes, each a U8 giving
-- the physical RX channel index for one logical control -- not
-- Rotorflight-specific, but the collective/throttle split (heli-specific)
-- matches Rotorflight's own field naming.
--
-- Restores what widgets/dashboard/flightmode.lua's inFlight() needs to read
-- the *radio's own* throttle channel (a local, instant, always-accurate
-- signal) rather than the FC's telemetry-reported throttle_percent -- see
-- that file's own header comment for why. Fetched once per connect by
-- tasks/session.lua, same as lib/msp_handshake.lua's reads.

if package.loaded["rfsuite.lib.msp_rx_map"] then
  return package.loaded["rfsuite.lib.msp_rx_map"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 64

local SIMULATOR_RESPONSE = {
  0, -- aileron
  1, -- elevator
  2, -- rudder
  3, -- collective
  4, -- throttle
  5, -- aux1
  6, -- aux2
  7, -- aux3
}

local msp_rx_map = {
  READ_COMMAND = READ_COMMAND,
}

function msp_rx_map.decode(buf)
  buf.offset = 1
  return {
    aileron = mspcodec.readU8(buf),
    elevator = mspcodec.readU8(buf),
    rudder = mspcodec.readU8(buf),
    collective = mspcodec.readU8(buf),
    throttle = mspcodec.readU8(buf),
    aux1 = mspcodec.readU8(buf),
    aux2 = mspcodec.readU8(buf),
    aux3 = mspcodec.readU8(buf),
  }
end

function msp_rx_map.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_rx_map.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

package.loaded["rfsuite.lib.msp_rx_map"] = msp_rx_map
return msp_rx_map
