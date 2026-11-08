-- Message-builder + parser for MSP_BOARD_INFO (cmd 4, read-only).
--
-- Reply layout, as read by the Rotorflight Configurator
-- (src/js/msp/MSPHelper.js, case MSP_BOARD_INFO) and as written by the
-- firmware (src/main/msp/msp.c, MSP_BOARD_INFO case):
--   4 bytes   boardIdentifier
--   u16       boardVersion
--   u8        boardType
--   u8        targetCapabilities
--   u8 len + len bytes   targetName
--   u8 len + len bytes   boardName
--   u8 len + len bytes   boardDesign
--   u8 len + len bytes   manufacturerId        (USE_BOARD_INFO builds only)
--   32 bytes             signature
--   u8                   mcuTypeId
--   u8                   configurationState
--   u16                  sampleRateHz          (the gyro sample rate, see readSampleRate())
--   ...                  configuration problems, SPI and I2C counts, and later fields
-- boardDesign selects the port labels in lib/port_labels.lua. sampleRateHz labels the PID
-- loop speeds on the Configuration page.
--
-- An empty boardDesign (length 0) is the generic-board case: lookups return nil
-- and the Ports page falls back to the plain UART name.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 4
local IDENTIFIER_LENGTH = 4

local msp_board_info = {
  READ_COMMAND = READ_COMMAND,
}

-- Fixed header before the first string: identifier (4), version (u16), type (u8),
-- capabilities (u8).
local HEADER_LENGTH = IDENTIFIER_LENGTH + 2 + 1 + 1

-- Reads one length-prefixed ASCII string. mspcodec reads past the end of a buffer as
-- 0, not nil, so the length is checked against the buffer here. Returns nil when the
-- string does not fit, so a truncated reply never produces a half-read name.
local function readLengthPrefixed(buf)
  local offset = buf.offset or 1
  if offset > #buf then return nil end
  local length = mspcodec.readU8(buf)
  if offset + length > #buf then return nil end
  local chars = {}
  for i = 1, length do
    chars[i] = string.char(mspcodec.readU8(buf))
  end
  return table.concat(chars)
end

-- The gyro sample rate that follows the manufacturer id: the signature (32 bytes), the MCU
-- type, the configuration state, then the rate (u16). The firmware writes this layout with
-- the manufacturer id only in builds with USE_BOARD_INFO. Other builds have no manufacturer
-- id and a reply one byte shorter, and the reads below would then run past the end of the
-- reply or read the wrong bytes.
-- In MSP API 1.44+ every reply of this layout carries configuration problems (u32) and SPI
-- and I2C counts (u8 each), for 42 bytes after manufacturerId (32 + 1 + 1 + 2 + 4 + 1 + 1).
-- Older MSP API 1.43 carries configuration problems but not the SPI/I2C counts, for 40 bytes
-- (32 + 1 + 1 + 2 + 4). The rate is taken only when the reply matches one of these complete
-- layouts (#2648).
local SIGNATURE_LENGTH = 32
local SPAN_API_143 = SIGNATURE_LENGTH + 1 + 1 + 2 + 4
local SPAN_API_144 = SIGNATURE_LENGTH + 1 + 1 + 2 + 4 + 1 + 1

local function readSampleRate(buf)
  local offset = buf.offset or 1
  local rem = #buf - offset + 1
  if rem < SPAN_API_144 and rem ~= SPAN_API_143 then return nil end
  buf.offset = offset + SIGNATURE_LENGTH
  mspcodec.readU8(buf) -- MCU type
  mspcodec.readU8(buf) -- configuration state
  local rate = mspcodec.readU16(buf)
  if rate <= 0 then return nil end
  return rate
end

-- Parses a reply buffer (table of bytes, 1-based). Returns
-- {boardDesign = "...", targetName = "...", boardName = "...", sampleRateHz = n} or nil if
-- the reply is truncated. boardDesign is "" when the firmware reports none. sampleRateHz is
-- nil when the reply does not carry it (see readSampleRate()).
function msp_board_info.parse(buf)
  if #buf < HEADER_LENGTH then return nil end
  buf.offset = HEADER_LENGTH + 1

  local targetName = readLengthPrefixed(buf)
  local boardName = readLengthPrefixed(buf)
  local boardDesign = readLengthPrefixed(buf)
  if targetName == nil or boardName == nil or boardDesign == nil then return nil end

  local manufacturerId = readLengthPrefixed(buf)
  local sampleRateHz = nil
  if manufacturerId ~= nil then sampleRateHz = readSampleRate(buf) end

  return {
    targetName = targetName,
    boardName = boardName,
    boardDesign = boardDesign,
    sampleRateHz = sampleRateHz,
  }
end

function msp_board_info.buildReadMessage(onData, onError, simulatorResponse)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local info = msp_board_info.parse(buf)
      if info == nil then
        if onError then onError() end
        return
      end
      onData(info)
    end,
    errorHandler = onError,
    -- Simulator fixture: the identifier "RFLT", version 0, no names, so the simulator
    -- shows the generic fallback labels. It must not claim a real board design.
    simulatorResponse = simulatorResponse or {82, 70, 76, 84, 0, 0, 0, 0, 0, 0, 0},
  }
end

return msp_board_info
