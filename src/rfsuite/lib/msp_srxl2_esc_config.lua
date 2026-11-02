-- MSP2_GET_SRXL2_ESC_CONFIG helper (0x5F16 read / 0x5F17 write): the SRXL2 ESC
-- bus settings, firmware pg/srxl2_esc.h. The read reply starts with a payload
-- version byte; the write takes the same fields without it. A changed setting
-- takes effect at the next boot, so the page reboots after saving.
--
-- Read reply (firmware msp.c, MSP2_GET_SRXL2_ESC_CONFIG), payload version 1:
--   U8 version, U16 throttle_rate_hz, U8 telem_interval_frames,
--   U8 motor2_channel                                         = 5 bytes
-- The write is the same four field bytes without the version; the firmware
-- rejects any other length.

if package.loaded["rfsuite.lib.msp_srxl2_esc_config"] then
  return package.loaded["rfsuite.lib.msp_srxl2_esc_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 0x5F16
local WRITE_COMMAND = 0x5F17
local PAYLOAD_VERSION = 1
local REPLY_LENGTH = 5

-- 0 = single motor; 1..31 = the SRXL2 channel carrying motor 2 (channel 0 is
-- always motor 1). For dual-motor Smart ESCs such as the Spektrum SPMXAE1020.
local MOTOR2_CHANNEL_CHOICES = {{"@i18n(api.SRXL2_ESC_CONFIG.tbl_off)@", 0}}
for ch = 1, 31 do
  MOTOR2_CHANNEL_CHOICES[#MOTOR2_CHANNEL_CHOICES + 1] = {tostring(ch), ch}
end

local FIELD_META = {
  -- Read back and written unchanged: the firmware derives the throttle rate
  -- from the motor PWM rate (srxl2escSetThrottleRateHz()), so no page edits it.
  throttle_rate_hz = {min = 1, max = 2000, default = 250, suffix = "Hz"},
  telem_interval_frames = {min = 0, max = 255, default = 7},
  motor2_channel = {choices = MOTOR2_CHANNEL_CHOICES},
}

local SIMULATOR_RESPONSE = {1, 250, 0, 7, 0}

local msp_srxl2_esc_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  PAYLOAD_VERSION = PAYLOAD_VERSION,
  REPLY_LENGTH = REPLY_LENGTH,
  FIELD_META = FIELD_META,
  MOTOR2_CHANNEL_CHOICES = MOTOR2_CHANNEL_CHOICES,
}

-- Returns the fields, or nil, a reason, and true when the reply was REFUSED.
-- A reply of another version or length is refused rather than decoded: a
-- reworded record would otherwise come out as plausible numbers, and the page
-- writes them back on save.
function msp_srxl2_esc_config.decode(buf)
  local length = #buf
  if buf[1] ~= PAYLOAD_VERSION then
    return nil, "SRXL2 ESC config payload version " .. tostring(buf[1]) .. ", expected " .. PAYLOAD_VERSION, true
  end
  if length ~= REPLY_LENGTH then
    return nil, "SRXL2 ESC config reply is " .. length .. " bytes, expected " .. REPLY_LENGTH, true
  end
  buf.offset = 1
  local data = {}
  data.version = mspcodec.readU8(buf)
  data.throttle_rate_hz = mspcodec.readU16(buf)
  data.telem_interval_frames = mspcodec.readU8(buf)
  data.motor2_channel = mspcodec.readU8(buf)
  return data
end

function msp_srxl2_esc_config.encode(data)
  data = data or {}
  local payload = {}
  mspcodec.writeU16(payload, data.throttle_rate_hz or 250)
  mspcodec.writeU8(payload, data.telem_interval_frames or 0)
  mspcodec.writeU8(payload, data.motor2_channel or 0)
  return payload
end

function msp_srxl2_esc_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local data, reason, refused = msp_srxl2_esc_config.decode(buf)
      if not data then
        -- page_runtime treats onError on a read as a failed load.
        if onError then onError(reason, refused) end
        return
      end
      onData(data)
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_srxl2_esc_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_srxl2_esc_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_srxl2_esc_config"] = msp_srxl2_esc_config
return msp_srxl2_esc_config
