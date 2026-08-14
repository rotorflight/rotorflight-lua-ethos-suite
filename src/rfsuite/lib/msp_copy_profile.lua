-- MSP_COPY_PROFILE helper (cmd 183 write-only).

if package.loaded["rfsuite.lib.msp_copy_profile"] then
  return package.loaded["rfsuite.lib.msp_copy_profile"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local WRITE_COMMAND = 183

local msp_copy_profile = {
  WRITE_COMMAND = WRITE_COMMAND,
}

function msp_copy_profile.buildWriteMessage(profileType, destProfile, sourceProfile, onWritten, onError)
  local payload = {}
  mspcodec.writeU8(payload, tonumber(profileType or 0) or 0)
  mspcodec.writeU8(payload, tonumber(destProfile or 0) or 0)
  mspcodec.writeU8(payload, tonumber(sourceProfile or 0) or 0)
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

package.loaded["rfsuite.lib.msp_copy_profile"] = msp_copy_profile
return msp_copy_profile
