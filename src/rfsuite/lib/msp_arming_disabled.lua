-- MSP_SET_ARMING_DISABLED (cmd 99, write-only): blocks arming while a setup
-- tool holds the flight controller, as the Configurator does on every tab
-- (mspHelper.setArmingEnabled(false)).
--
-- rotorflight-firmware src/main/msp/msp.c (MSP_SET_ARMING_DISABLED): one U8,
-- non-zero to block. The block is recorded per MSP link, and arming is only
-- allowed again once every link that blocked it has released it, so the
-- Setup Wizard must always send the release when it closes.

if package.loaded["rfsuite.lib.msp_arming_disabled"] then
  return package.loaded["rfsuite.lib.msp_arming_disabled"]
end

local WRITE_COMMAND = 99

local M = {WRITE_COMMAND = WRITE_COMMAND}

-- disabled: true blocks arming, false releases the block.
function M.buildWriteMessage(disabled, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = {disabled and 1 or 0},
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_arming_disabled"] = M
return M
