-- Background task heartbeat, as Diagnostics / Info shows it (issue #2518).
--
-- Pure on purpose: no form, no bus, no os.clock. The caller passes the clock,
-- so every case runs without a radio (bin/bgtask_status/verify_bgtask_status.lua).
--
-- The heartbeat is the "task.status" event that tasks/background.lua publishes
-- every 0.5 s, with the revival count the watchdog keeps (#2516). A heartbeat
-- older than STALE_SECONDS is "stale". The value is a second copy of
-- app/tool.lua's TASK_STATUS_TIMEOUT, so the page and the one-shot "background
-- task missing" alert agree on what stale means; the harness checks that copy.

local status = {}

status.STALE_SECONDS = 3.0

local function updatedAtOf(snapshot)
  return snapshot and tonumber(snapshot.updatedAt) or nil
end

-- "running" while the last heartbeat is fresh, "stale" once it is older than
-- STALE_SECONDS, "none" before any heartbeat has been seen.
function status.state(snapshot, now)
  local updatedAt = updatedAtOf(snapshot)
  if not updatedAt or not now then return "none" end
  if now - updatedAt <= status.STALE_SECONDS then return "running" end
  return "stale"
end

-- Age of the last heartbeat in seconds, clamped at zero so a heartbeat stamped
-- a moment ahead of the reader's clock does not show a negative age.
function status.heartbeatText(snapshot, now)
  local updatedAt = updatedAtOf(snapshot)
  if not updatedAt or not now then return "-" end
  local age = now - updatedAt
  if age < 0 then age = 0 end
  return string.format("%.1f s", age)
end

-- The number of watchdog rebuilds since the task started; "-" before a heartbeat.
function status.revivalsText(snapshot)
  local revivals = snapshot and tonumber(snapshot.revivals) or nil
  if not revivals then return "-" end
  return tostring(math.floor(revivals))
end

return status
