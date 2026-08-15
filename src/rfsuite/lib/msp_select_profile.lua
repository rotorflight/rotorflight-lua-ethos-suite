-- MSP_SELECT_PROFILE helper (cmd 210 write-only).

if package.loaded["rfsuite.lib.msp_select_profile"] then
  return package.loaded["rfsuite.lib.msp_select_profile"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local WRITE_COMMAND = 210

local msp_select_profile = {
  WRITE_COMMAND = WRITE_COMMAND,
}

function msp_select_profile.buildWriteMessage(profile, onWritten, onError)
  local payload = {}
  mspcodec.writeU8(payload, tonumber(profile or 0) or 0)
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

package.loaded["rfsuite.lib.msp_select_profile"] = msp_select_profile
return msp_select_profile
