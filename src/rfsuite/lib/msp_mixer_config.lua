-- Schema + message-builders for MSP_MIXER_CONFIG /
-- MSP_SET_MIXER_CONFIG (cmd 42 read / 43 write).
--
-- Rotorflight 2.3 / MSP API >= 12.09 is the floor for this rebuild, so
-- the >=12.0.7/12.0.8 mixer fields from the original API are always
-- present here.

if package.loaded["rfsuite.lib.msp_mixer_config"] then
  return package.loaded["rfsuite.lib.msp_mixer_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 42
local WRITE_COMMAND = 43

local SIMULATOR_RESPONSE = {
  0,        -- main_rotor_dir
  0,        -- tail_rotor_mode
  0,        -- tail_motor_idle
  165, 1,   -- tail_center_trim
  0,        -- swash_type
  2,        -- swash_ring
  100, 0,   -- swash_phase
  131, 6,   -- swash_pitch_limit
  0, 0,     -- swash_trim_0
  0, 0,     -- swash_trim_1
  0, 0,     -- swash_trim_2
  0,        -- swash_tta_precomp
  10,       -- swash_geo_correction
  3,        -- collective_tilt_correction_pos
  11,       -- collective_tilt_correction_neg
}

local msp_mixer_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
}

function msp_mixer_config.decode(buf)
  buf.offset = 1
  return {
    main_rotor_dir = mspcodec.readU8(buf),
    tail_rotor_mode = mspcodec.readU8(buf),
    tail_motor_idle = mspcodec.readU8(buf),
    tail_center_trim = mspcodec.readS16(buf),
    swash_type = mspcodec.readU8(buf),
    swash_ring = mspcodec.readU8(buf),
    swash_phase = mspcodec.readS16(buf),
    swash_pitch_limit = mspcodec.readU16(buf),
    swash_trim_0 = mspcodec.readS16(buf),
    swash_trim_1 = mspcodec.readS16(buf),
    swash_trim_2 = mspcodec.readS16(buf),
    swash_tta_precomp = mspcodec.readU8(buf),
    swash_geo_correction = mspcodec.readS8(buf),
    collective_tilt_correction_pos = mspcodec.readS8(buf),
    collective_tilt_correction_neg = mspcodec.readS8(buf),
  }
end

function msp_mixer_config.encode(data)
  data = data or {}
  local payload = {}
  mspcodec.writeU8(payload, data.main_rotor_dir or 0)
  mspcodec.writeU8(payload, data.tail_rotor_mode or 0)
  mspcodec.writeU8(payload, data.tail_motor_idle or 0)
  mspcodec.writeS16(payload, data.tail_center_trim or 0)
  mspcodec.writeU8(payload, data.swash_type or 0)
  mspcodec.writeU8(payload, data.swash_ring or 0)
  mspcodec.writeS16(payload, data.swash_phase or 0)
  mspcodec.writeU16(payload, data.swash_pitch_limit or 0)
  mspcodec.writeS16(payload, data.swash_trim_0 or 0)
  mspcodec.writeS16(payload, data.swash_trim_1 or 0)
  mspcodec.writeS16(payload, data.swash_trim_2 or 0)
  mspcodec.writeU8(payload, data.swash_tta_precomp or 0)
  mspcodec.writeS8(payload, data.swash_geo_correction or 0)
  mspcodec.writeS8(payload, data.collective_tilt_correction_pos or 0)
  mspcodec.writeS8(payload, data.collective_tilt_correction_neg or 0)
  return payload
end

function msp_mixer_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_mixer_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_mixer_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_mixer_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_mixer_config"] = msp_mixer_config
return msp_mixer_config
