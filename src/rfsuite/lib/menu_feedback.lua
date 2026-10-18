-- Whether a menu tile is closed because the flight controller does not answer
-- (issue #2319).
--
-- A tile that needs the flight controller is closed while the link is down. With
-- the background task running, that used to leave the pilot with nothing: the
-- one-shot "background task not running" alert covers only the task being down,
-- and a disabled tile gets no press, so no message could come from a tap either.
-- app/menu_container.lua asks this rule from the menu's own state and raises a
-- notice once per link loss.
--
-- Pure on purpose: no form, no bus, no clock. The caller passes the facts, so
-- every case runs without a radio (bin/menu_feedback/verify_menu_feedback.lua).
--
-- The rule follows app/menu_container.lua's canOpenEntry: a tile is closed by the
-- link when the task runs, the tile needs the flight controller, and the link is down.

local menuFeedback = {}

-- offline    the tile works without a flight controller
-- running    the background task is running
-- connected  the flight controller answers
function menuFeedback.closedByLink(offline, running, connected)
  return running == true and connected ~= true and offline ~= true
end

return menuFeedback
