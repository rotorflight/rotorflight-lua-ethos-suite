-- Waits for the flight controller to finish the accelerometer calibration that
-- MSP_ACC_CALIBRATION (cmd 205) starts, before the accelerometer page commits
-- to EEPROM and reports "done" (issue #2347).
--
-- The acknowledgement of MSP_ACC_CALIBRATION only means the command arrived:
-- src/main/msp/msp.c:3366-3368 calls accStartCalibration(), which sets a
-- counter (src/main/sensors/acceleration_init.c:390-393). While that counter is
-- running, isCalibrating() holds and the firmware sets ARMING_DISABLED_CALIBRATING,
-- bit 12 of arming_disable_flags (src/main/fc/core.c:298-299, runtime_config.h:55).
--
-- The state machine decides from MSP_STATUS polls. It has no clock of its own:
-- the caller passes `now` (os.clock()) in every call, so the harness can drive it.
--
--   "wait"    keep the dialog open and poll again
--   "done"    the bit was seen set and is now clear: commit to EEPROM
--   "timeout" the bit did not clear in time: show an error, do not commit
--
-- One timing assumption, stated here so it can be checked on the radio: if the
-- bit was never seen set within NOT_SEEN_DONE seconds, the calibration is taken
-- as finished. Polls run every POLL_INTERVAL seconds, so a calibration shorter
-- than one poll is never seen with the bit set. Without this fallback such a
-- calibration would wait until TIMEOUT and report an error every time.

if package.loaded["rfsuite.lib.acc_calibration_wait"] then
  return package.loaded["rfsuite.lib.acc_calibration_wait"]
end

local CALIBRATING_BIT_VALUE = 4096 -- 1 << 12, ARMING_DISABLED_CALIBRATING

local M = {
  POLL_INTERVAL = 0.5,
  NOT_SEEN_DONE = 3.0,
  TIMEOUT = 15.0,
}

-- true while the calibrating bit is set, false when clear, nil when unknown.
function M.isCalibrating(flags)
  local value = tonumber(flags)
  if value == nil then return nil end
  return math.floor(value / CALIBRATING_BIT_VALUE) % 2 == 1
end

function M.new(now)
  return {startedAt = now, nextPollAt = now, seenSet = false}
end

function M.shouldPoll(state, now)
  return now >= state.nextPollAt
end

local function failed(state, now)
  state.nextPollAt = now + M.POLL_INTERVAL
  if now - state.startedAt >= M.TIMEOUT then return "timeout" end
  return "wait"
end

-- Called with the arming_disable_flags of one MSP_STATUS reply.
function M.onStatus(state, flags, now)
  local calibrating = M.isCalibrating(flags)
  if calibrating == nil then return failed(state, now) end

  state.nextPollAt = now + M.POLL_INTERVAL
  local elapsed = now - state.startedAt
  if calibrating then
    state.seenSet = true
  elseif state.seenSet then
    return "done"
  end
  if elapsed >= M.TIMEOUT then return "timeout" end
  if not state.seenSet and elapsed >= M.NOT_SEEN_DONE then return "done" end
  return "wait"
end

-- Called when a poll fails (no reply or an error); keeps waiting until the timeout.
function M.onError(state, now)
  return failed(state, now)
end

package.loaded["rfsuite.lib.acc_calibration_wait"] = M
return M
