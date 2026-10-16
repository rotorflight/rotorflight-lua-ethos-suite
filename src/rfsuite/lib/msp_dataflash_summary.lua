-- MSP_DATAFLASH_SUMMARY helper (cmd 70 read).

if package.loaded["rfsuite.lib.msp_dataflash_summary"] then
  return package.loaded["rfsuite.lib.msp_dataflash_summary"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 70
-- flags (1) + sectors, total and used (4 each).
local SUMMARY_SIZE = 13
local SIMULATOR_RESPONSE = {
  3, -- ready + supported
  235, 3, 0, 0, -- sectors
  0, 0, 214, 7, -- total
  0, 112, 13, 0, -- used
}

local msp_dataflash_summary = {READ_COMMAND = READ_COMMAND}

function msp_dataflash_summary.decode(buf)
  buf.offset = 1
  return {
    flags = mspcodec.readU8(buf),
    sectors = mspcodec.readU32(buf),
    total = mspcodec.readU32(buf),
    used = mspcodec.readU32(buf),
  }
end

function msp_dataflash_summary.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      -- A short reply would decode its missing bytes as zero, which reads as "no dataflash".
      -- It is an error instead, and the caller decides how to retry.
      if type(buf) ~= "table" or #buf < SUMMARY_SIZE then
        if onError then onError("short_payload") end
        return
      end
      onData(msp_dataflash_summary.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

package.loaded["rfsuite.lib.msp_dataflash_summary"] = msp_dataflash_summary
return msp_dataflash_summary
