-- Message-builder for MSP_REBOOT (cmd 68, write-only) --
-- app/pages/configuration.lua triggers this once its own EEPROM write
-- commits, since a PID loop speed change only takes effect after the FC
-- restarts (matching rotorflight-lua-ethos-suite's own
-- app/lib/ui.lua:rebootFc(), which does the same right after its own
-- save's EEPROM_WRITE completes).
--
-- Confirmed directly against rotorflight-firmware's own wire handler
-- (src/main/msp/msp.c, MSP_REBOOT case): an optional 1-byte reboot mode,
-- defaulting to MSP_REBOOT_FIRMWARE (0) when the payload is empty --
-- this always sends that byte explicitly, matching
-- rotorflight-lua-ethos-suite's own REBOOT.lua buildWritePayload(),
-- which does the same rather than relying on the empty-payload default.
--
-- **No armed-state safety check in this module** -- deliberately kept a
-- plain, stateless message-builder like every other lib/msp_*.lua codec
-- (no session/business-state reads). rotorflight-lua-ethos-suite's own
-- REBOOT.lua *does* gate this at the API layer (`validateWrite()`,
-- blocking the write while `resolveArmedState()` says armed) --
-- firmware's own MSP_REBOOT handler has no such guard at all (confirmed
-- reading the same wire handler above: it validates the reboot *mode*
-- byte, nothing about arm state), so that Lua-side check is the only
-- safety net that exists for this command, on either project. This
-- rebuild ports the same gate, just one layer up: app/page_runtime.lua's
-- own reboot-after-save flow (see its own comment) checks
-- `tasks/session.lua`'s `isArmed` before ever building this message, not
-- this file.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/configuration.lua reloads fresh via loadfile() on every
-- open, so without caching this was rebuilt on every navigation too. See
-- lib/msp_pid_tuning.lua's own comment for the full reasoning (added
-- after a live memory investigation, see AGENTS.md's "Memory stats
-- printing" section).
if package.loaded["rfsuite.lib.msp_reboot"] then
  return package.loaded["rfsuite.lib.msp_reboot"]
end

local WRITE_COMMAND = 68
local REBOOT_MODE_FIRMWARE = 0

local msp_reboot = {
  WRITE_COMMAND = WRITE_COMMAND,
}

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the command (the FC then actually
-- restarts -- callers shouldn't expect a live connection right after
-- this); `onError(reason)` on failure/disconnect before that ack arrives.
--
-- maxRetries = 1 (one resend, two attempts total) rather than
-- tasks/msp/queue.lua's generic default (5): a lost ack here is the
-- *expected* outcome, not a communication failure -- the FC accepts this
-- command and immediately starts resetting, so its reply routinely never
-- makes it out before the link drops. The queue can't tell that apart from
-- a genuine timeout, so with the generic default it would keep resending
-- this same REBOOT command for up to 5 attempts -- and any resend that
-- lands after the FC has already come back up and reconnected commands
-- *another* reboot -- matching a real "FBL keeps rebooting" report seen
-- after applying telemetry sensor changes (see app/pages/telemetry.lua's
-- rebootAfterSave, though the mechanism is shared by every such page).
-- Matches rotorflight-lua-ethos-suite's own tasks/scheduler/msp/mspQueue.lua,
-- which special-cases command 68 (REBOOT) the same way: force-completed
-- after retryCount == 2 regardless of whether a reply ever arrived.
function msp_reboot.buildWriteMessage(onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = {REBOOT_MODE_FIRMWARE},
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    maxRetries = 1,
    simulatorResponse = {REBOOT_MODE_FIRMWARE},
  }
end

package.loaded["rfsuite.lib.msp_reboot"] = msp_reboot
return msp_reboot
