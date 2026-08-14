-- MSP_SDCARD_SUMMARY helper (cmd 79 read).

if package.loaded["rfsuite.lib.msp_sdcard_summary"] then
  return package.loaded["rfsuite.lib.msp_sdcard_summary"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 79
local SIMULATOR_RESPONSE = {
  0, -- flags
  0, -- state
  0, -- filesystemLastError
  0, 0, 0, 0, -- freeSizeKB
  0, 0, 0, 0, -- totalSizeKB
}

local msp_sdcard_summary = {READ_COMMAND = READ_COMMAND}

function msp_sdcard_summary.decode(buf)
  buf.offset = 1
  return {
    flags = mspcodec.readU8(buf),
    state = mspcodec.readU8(buf),
    filesystemLastError = mspcodec.readU8(buf),
    freeSizeKB = mspcodec.readU32(buf),
    totalSizeKB = mspcodec.readU32(buf),
  }
end

function msp_sdcard_summary.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_sdcard_summary.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

package.loaded["rfsuite.lib.msp_sdcard_summary"] = msp_sdcard_summary
return msp_sdcard_summary
