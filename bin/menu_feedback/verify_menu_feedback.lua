-- Behaviour check for the not-connected notice on the Rotorflight menu (#2319).
--
-- Run it from the repository root:
--     lua5.4 bin/menu_feedback/verify_menu_feedback.lua
--
-- What it drives, and why:
--   * lib/menu_feedback.lua decides whether a tile is closed by the link. It has no
--     dependency at all, so every case runs here rather than on a radio.
--   * The open rule is a copy of app/menu_container.lua's canOpenEntry. The first
--     block checks that a tile is closed by the link exactly when canOpenEntry
--     closes it while the task runs. Tiles closed because the task is down are the
--     one-shot alert's case, not this one.
--   * The fix case is the one a pilot hit: the task runs, the flight controller does
--     not answer, the tile needs it. Before, nothing was shown.
--   * --self-test replaces the rule with one that never raises the notice and
--     requires the fix case to fail, so the case cannot pass by accident.
--   * The wiring is read from the source: the menu raises the notice from its own
--     state, the tool latches it once per link loss and re-arms when the link returns,
--     and the locale sources carry the strings.
--
-- A disabled tile gets no press on the radio (app/menu_container.lua sets
-- button:enable), so the notice cannot depend on a tap. The Ethos simulator showed
-- that: a tap on a greyed tile raised nothing. See the Wellen note for the run.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SELF_TEST = arg and arg[1] == "--self-test"

local failures = 0
local checks = 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local function readFile(path)
  local f = assert(io.open(ROOT .. "/" .. path, "rb"))
  local text = f:read("*a")
  f:close()
  -- Source files are CRLF in a Windows checkout; the searches use LF.
  return (text:gsub("\r\n", "\n"))
end

local menuFeedback = dofile(ROOT .. "/src/rfsuite/lib/menu_feedback.lua")

-- The rule menu_container.lua applies to a tile: open when the task runs and the
-- tile works offline or the link is up.
local function canOpen(offline, running, connected)
  return running == true and (offline == true or connected == true)
end

-- The rule before this notice existed: nothing was ever raised for a closed tile.
local function oldClosedByLink(offline, running, connected)
  return false
end

local closedByLink = SELF_TEST and oldClosedByLink or menuFeedback.closedByLink
if SELF_TEST then print("self-test: the rule that never raises the notice replaces the decision") end

local function describe(offline, running, connected)
  return string.format("offline=%s running=%s connected=%s",
    tostring(offline), tostring(running), tostring(connected))
end

print("agreement with the open rule")

for _, offline in ipairs({ false, true }) do
  for _, running in ipairs({ false, true }) do
    for _, connected in ipairs({ false, true }) do
      local closed = not canOpen(offline, running, connected)
      local byLink = closedByLink(offline, running, connected)
      local expected = running == true and connected ~= true and offline ~= true
      check("a tile is closed by the link exactly when the link is down with the task running: "
          .. describe(offline, running, connected),
        byLink == expected and (not byLink or closed),
        string.format("closedByLink=%s closed=%s", tostring(byLink), tostring(closed)))
    end
  end
end

print("the fix")

check("a flight-controller tile with the task running and no link is closed by the link",
  closedByLink(false, true, false) == true, "got " .. tostring(closedByLink(false, true, false)))

check("a flight-controller tile with the task down is not the notice's case",
  closedByLink(false, false, false) == false, "got " .. tostring(closedByLink(false, false, false)))

check("a flight-controller tile with the link up is not closed by the link",
  closedByLink(false, true, true) == false, "got " .. tostring(closedByLink(false, true, true)))

print("tiles that work offline")

check("an offline tile with the task running and no link is not closed by the link",
  closedByLink(true, true, false) == false, "got " .. tostring(closedByLink(true, true, false)))

check("a missing running flag is not closed by the link",
  closedByLink(false, nil, false) == false, "got " .. tostring(closedByLink(false, nil, false)))

if not SELF_TEST then
  print("wiring")

  local menu = readFile("src/rfsuite/app/menu_container.lua")
  check("the menu asks the rule", menu:find("menuFeedback.closedByLink(", 1, true) ~= nil)
  check("the menu loads the rule", menu:find('requireModule("lib/menu_feedback.lua")', 1, true) ~= nil)
  check("the menu raises the notice from its state, after the grace period",
    menu:find("closedByLinkOn(entries, taskGuard) and taskGuard.requestNotConnectedAlert", 1, true) ~= nil)
  check("the menu no longer raises it from a press (a disabled tile gets none)",
    menu:find("blocked == menuFeedback", 1, true) == nil)

  local tool = readFile("src/rfsuite/app/tool.lua")
  check("the task guard carries the request",
    tool:find("requestNotConnectedAlert = requestNotConnectedAlert,", 1, true) ~= nil)
  check("the request is latched once per link loss",
    tool:find("if notConnectedOpen or notConnectedShown then return end", 1, true) ~= nil)
  check("the latch re-arms when the link returns",
    tool:find("if sessionConnected then notConnectedShown = false end", 1, true) ~= nil)
  check("a new tool open clears the latch",
    tool:find("notConnectedShown = false\n  updateDeveloperMode()", 1, true) ~= nil)
  check("the wakeup shows the dialog", tool:find("showNotConnectedAlert()\nend", 1, true) ~= nil)

  for _, locale in ipairs({ "cs", "de", "en", "es", "fr", "he", "it", "nl", "no", "pl", "pt-br", "zh-cn" }) do
    local text = readFile("src/rfsuite/i18n/" .. locale .. ".json")
    check("the strings resolve in " .. locale,
      text:find('"msg_fc_not_connected_title"', 1, true) ~= nil
        and text:find('"msg_fc_not_connected_body"', 1, true) ~= nil)
  end
end

if SELF_TEST then
  -- The fix case must fail under the old rule, or the case proves nothing.
  local oldFails = oldClosedByLink(false, true, false) ~= true
  check("the rule that never raises the notice fails the fix case", oldFails)
  print(string.format("%d checks, %d failures (self-test: failures expected)", checks, failures))
  os.exit(oldFails and 0 or 1)
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
