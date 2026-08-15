-- MSP_BEEPER_CONFIG helper (cmd 184 read / 185 write).
--
-- The UI exposes enabled beepers, but the wire fields are "off flags":
-- set bits mean disabled conditions.

if package.loaded["rfsuite.lib.msp_beeper_config"] then
  return package.loaded["rfsuite.lib.msp_beeper_config"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 184
local WRITE_COMMAND = 185

local SIMULATOR_RESPONSE = {
  0, 0, 0, 0, -- beeper_off_flags
  1, -- dshotBeaconTone
  0, 0, 0, 0, -- dshotBeaconOffFlags
}

local msp_beeper_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
}

local function clampTone(value)
  value = tonumber(value or 1) or 1
  if value < 1 or value > 5 then return 1 end
  return value
end

function msp_beeper_config.defaultConfig()
  return {
    beeper_off_flags = 0,
    dshotBeaconTone = 1,
    dshotBeaconOffFlags = 0,
  }
end

function msp_beeper_config.decode(buf)
  buf.offset = 1
  local config = msp_beeper_config.defaultConfig()
  config.beeper_off_flags = mspcodec.readU32(buf)
  config.dshotBeaconTone = clampTone(mspcodec.readU8(buf))
  if #buf >= 9 then
    config.dshotBeaconOffFlags = mspcodec.readU32(buf)
  end
  return config
end

function msp_beeper_config.clone(config)
  config = config or {}
  return {
    beeper_off_flags = tonumber(config.beeper_off_flags or 0) or 0,
    dshotBeaconTone = clampTone(config.dshotBeaconTone),
    dshotBeaconOffFlags = tonumber(config.dshotBeaconOffFlags or 0) or 0,
  }
end

function msp_beeper_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_beeper_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_beeper_config.buildWriteMessage(config, onWritten, onError)
  config = msp_beeper_config.clone(config)
  local payload = {}
  mspcodec.writeU32(payload, config.beeper_off_flags)
  mspcodec.writeU8(payload, config.dshotBeaconTone)
  mspcodec.writeU32(payload, config.dshotBeaconOffFlags)
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

package.loaded["rfsuite.lib.msp_beeper_config"] = msp_beeper_config
return msp_beeper_config
