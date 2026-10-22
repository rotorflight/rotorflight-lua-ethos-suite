-- Message-builders for MSP_RX_MAP (cmd 64) and MSP_SET_RX_MAP (cmd 65, written
-- only by the Setup Wizard's Receiver step). Standard MultiWii-lineage command: 8 bytes, each a U8 giving
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
local WRITE_COMMAND = 65

-- Field order on the wire (rotorflight-firmware msp.c, MSP_SET_RX_MAP: one U8
-- per mappable channel).
local FIELDS = {"aileron", "elevator", "rudder", "collective", "throttle", "aux1", "aux2", "aux3"}

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
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
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

-- data: the decode() table. Fields left out are written as their slot index.
function msp_rx_map.encode(data)
  local payload = {}
  for i = 1, #FIELDS do
    mspcodec.writeU8(payload, (data and data[FIELDS[i]]) or (i - 1))
  end
  return payload
end

function msp_rx_map.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_rx_map.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_rx_map"] = msp_rx_map
return msp_rx_map
