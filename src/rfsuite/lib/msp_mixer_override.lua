-- Message-builder for MSP_MIXER_OVERRIDE / MSP_SET_MIXER_OVERRIDE
-- (cmd 190 read / 191 write).

if package.loaded["rfsuite.lib.msp_mixer_override"] then
  return package.loaded["rfsuite.lib.msp_mixer_override"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local WRITE_COMMAND = 191
local OVERRIDE_OFF = 2501
local OVERRIDE_PASSTHROUGH = 2502

local msp_mixer_override = {
  WRITE_COMMAND = WRITE_COMMAND,
  OVERRIDE_OFF = OVERRIDE_OFF,
  OVERRIDE_PASSTHROUGH = OVERRIDE_PASSTHROUGH,
}

function msp_mixer_override.encode(index, value)
  local payload = {}
  mspcodec.writeU8(payload, index or 0)
  mspcodec.writeU16(payload, value or 0)
  return payload
end

function msp_mixer_override.buildWriteMessage(index, value, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_mixer_override.encode(index, value),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_mixer_override"] = msp_mixer_override
return msp_mixer_override
