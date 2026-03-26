--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local toolName = "AM32"

local function getPageValue(page, index) return page[index] end

local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = buffer[i]
        if v == 0 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

-- required by framework
local function getEscModel(self)

    -- we dont have a name for the am32, so we just return the tool name as the model
    return "AM32 "

end


-- required by framework
local function getEscVersion(self)
    return " "
end

-- required by framework
local function getEscFirmware(self)

   local version = "SW" .. getPageValue(self, 6) .. "." .. getPageValue(self, 7)
   return version

end

return {
    mspapi = "ESC_PARAMETERS_AM32",           -- MSP API used for AM32 read/write fields.
    toolName = toolName,                      -- Tool label shown in headers.
    force4WaySwitchOnEntry = true,            -- Always send target select when entering a selected ESC.
    esc4wayEsc1Target = 0,                    -- 4WIF target id for ESC1 button.
    esc4wayEsc2Target = 1,                    -- 4WIF target id for ESC2 button.
    flushFirstReadAfterSwitch = true,         -- Drop first read after switching target to avoid stale reply.
    preSwitchTarget = 100,                    -- Optional pre-target written before selected target.
    preSwitchWriteCount = 1,                  -- Number of pre-target writes per switch attempt.
    preSwitchDelay = 0.8,                     -- Delay after pre-target write before final target write.
    switchWriteCount = 1,                     -- Number of writes for the selected target.
    switchReadDelay = 4.0,                    -- Wait after target switch before normal ESC reads start.
    postSaveSwitchCycle = true,               -- If true, do post-save cycle (reset target then restore selected target).
    postSaveSettleDelay = 1.0,                -- Delay after save before post-save reset write.
    postSaveResetTarget = 100,                -- Target used for post-save reset stage.
    postSaveReturnTargetDelay = 1.0,          -- Delay between reset write and restore-selected write.
    postSaveRestoreSettleDelay = 0.5,         -- Delay after restore/flush before save is finalized.
    postSaveSwitchTimeout = 4.0,              -- Timeout for each post-save 4WIF target write.
    postSaveSwitchRetryCount = 1,             -- Retry count for post-save target writes.
    postSaveSwitchRetryDelay = 0.75,          -- Delay between post-save write retries.
    postSaveQueueIdleTimeout = 3.0,           -- Max time waiting for MSP queue idle before post-save writes.
    postSaveFlushRead = false,                -- Perform one read after restore to flush stale response.
    postSaveFlushReadDelay = 0.35,            -- Delay before the post-save flush read.
    postSaveFlushReadRetryCount = 1,          -- Retry count for post-save flush read.
    postSaveFlushReadRetryDelay = 0.6,        -- Delay between post-save flush read retries.
    postSaveFlushReadTimeout = 5.0,           -- Timeout for post-save flush read.
    useIsolatedSaveDialog = true,             -- Use page-owned save dialog instead of shared global save dialog.
    isolatedSaveTimeout = 32,                 -- Overall timeout for isolated save dialog flow (seconds).
    isolatedSaveProgressProcessingStep = 0.2, -- Progress increment per wakeup while write/postSave is processing.
    isolatedSaveProgressProcessingCap = 90,   -- Max progress while processing before wait stage.
    isolatedSaveProgressIdleStep = 1,         -- Progress increment per wakeup while waiting for completion.
    isolatedSaveProgressIdleCap = 97,         -- Max progress in idle wait stage before final completion.
    isolatedSaveWaitEscMessage = "Waiting for ESC...", -- Message shown during async wait stage near cap.
    isolatedSaveGcCollect = true,             -- Run garbage collection when isolated save dialog closes.
    isolatedSaveGcPasses = 1,                 -- Number of GC passes executed at isolated save close.
    escDetailsPollInterval = 0.6,             -- Poll interval for ESC details read when healthy.
    escDetailsRetryInterval = 1.2,            -- Retry interval when ESC detail read fails/invalid.
    retrySwitchOnReadFail = true,             -- Re-arm ESC switch sequence if detail read fails.
    readSwitchRetryCount = 3,                 -- Max re-arm attempts on read failure.
    readSwitchRetryDelay = 0.25,              -- Delay before re-arm attempt after read failure.
    powerCycle = false,                       -- If true, tool enforces manual power-cycle workflow.
    getEscModel = getEscModel,                -- Callback extracting model string from ESC payload.
    getEscVersion = getEscVersion,            -- Callback extracting version string from ESC payload.
    getEscFirmware = getEscFirmware           -- Callback extracting firmware string from ESC payload.
}
