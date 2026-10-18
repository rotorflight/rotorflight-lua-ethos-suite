-- What a press on a blocked menu tile reports (issue #2319).
--
-- A tile that needs the flight controller is closed while the link is down. Until
-- now the press handler in app/menu_container.lua then returned silently whenever
-- the background task was running. The one-shot "background task not running"
-- alert in app/tool.lua covers only the task being down, so a pilot whose flight
-- controller does not answer saw nothing happen.
--
-- Pure on purpose: no form, no bus, no clock. The caller passes the three facts,
-- so every case runs without a radio (bin/menu_feedback/verify_menu_feedback.lua).
--
-- The rules follow app/menu_container.lua's canOpenEntry: a tile opens only while
-- the task runs, and then if it works offline or the link is up.

local menuFeedback = {}

menuFeedback.TASK_MISSING = "task_missing"
menuFeedback.NOT_CONNECTED = "not_connected"

-- Returns why a press on a tile is blocked, or nil when the tile opens.
--   offline    the tile works without a flight controller
--   running    the background task is running
--   connected  the flight controller answers
function menuFeedback.blockedBy(offline, running, connected)
  if running ~= true then return menuFeedback.TASK_MISSING end
  if offline == true or connected == true then return nil end
  return menuFeedback.NOT_CONNECTED
end

return menuFeedback
