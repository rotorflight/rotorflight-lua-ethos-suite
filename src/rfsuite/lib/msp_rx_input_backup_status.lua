-- Schema + message-builder for rotorflight-firmware's read-only backup-RX
-- diagnostics -- MSP2_GET_RX_INPUT_BACKUP_STATUS (cmd 0x5F0B / 24331
-- decimal -- see src/main/msp/msp_protocol_v2_rotorflight.h). Read-only:
-- there is no SET_ variant.
--
-- Wire layout verified directly against rotorflight-firmware's own
-- serializer (src/main/msp/msp.c, MSP2_GET_RX_INPUT_BACKUP_STATUS case):
-- U8 payload version -> U8 enabled (a port has FUNCTION_RX_INPUT_BACKUP
-- assigned) -> [version >= 2 only] U8 provider (0 = SBUS) -> U8 linkUp (a
-- valid frame decoded within the last ~50ms) -> U8 activeSource (0 = main
-- RX currently driving the aircraft, 1 = backup is) -> U8 channelCount ->
-- channelCount x U16 channel values, in the same ~880-2012us convention
-- MSP_RC/RX_CHANNELS already use (drivers/rx_input_backup.c's
-- rxInputBackupGetChannel()).
--
-- The `provider` byte was added in payload version 2, once the feature
-- stopped being SBUS-only; a version 1 firmware doesn't send it at all, so
-- this decoder branches on the version byte rather than assuming a fixed
-- offset - unlike the version-1-only decoder this replaced, which read and
-- discarded that byte.
--
-- Self-caches via package.loaded (same mechanism lib/bus.lua uses).
if package.loaded["rfsuite.lib.msp_rx_input_backup_status"] then
  return package.loaded["rfsuite.lib.msp_rx_input_backup_status"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 0x5F0B

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua): backup not configured, no channels -- matches
-- what a fresh Ports page with no port assigned this function looks like.
local SIMULATOR_RESPONSE = {
  2, -- payload version
  0, -- enabled = false
  0, -- provider = SBUS
  0, -- linkUp = false
  0, -- activeSource = main
  0, -- channelCount = 0
}

local msp_rx_input_backup_status = {
  READ_COMMAND = READ_COMMAND,
}

function msp_rx_input_backup_status.decode(buf)
  buf.offset = 1
  local payloadVersion = mspcodec.readU8(buf)

  local enabled = mspcodec.readU8(buf) ~= 0
  local provider = payloadVersion >= 2 and mspcodec.readU8(buf) or 0 -- 0 = SBUS
  local linkUp = mspcodec.readU8(buf) ~= 0
  local activeSource = mspcodec.readU8(buf) ~= 0 and "backup" or "main"
  local channelCount = mspcodec.readU8(buf) or 0

  local channels = {}
  for i = 1, channelCount do
    channels[i] = mspcodec.readU16(buf)
  end

  return {
    enabled = enabled,
    provider = provider,
    linkUp = linkUp,
    activeSource = activeSource,
    channels = channels,
  }
end

function msp_rx_input_backup_status.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_rx_input_backup_status.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

package.loaded["rfsuite.lib.msp_rx_input_backup_status"] = msp_rx_input_backup_status
return msp_rx_input_backup_status
