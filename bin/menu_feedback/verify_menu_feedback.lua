-- Behaviour check for the press on a blocked menu tile (#2319).
--
-- Run it from the repository root:
--     lua5.4 bin/menu_feedback/verify_menu_feedback.lua
--
-- What it drives, and why:
--   * lib/menu_feedback.lua decides what a press reports. It has no dependency at
--     all, so every case runs here rather than on a radio.
--   * The open rule is a copy of app/menu_container.lua's canOpenEntry. The first
--     block checks that the copy and the decision agree in all eight combinations,
--     so the press reports exactly the tiles that are closed.
--   * The fix is the case a pilot hit: the task runs, the flight controller does not
--     answer, the tile needs it. Before, that press returned silently.
--   * --self-test replaces the rule with the old silent one and requires the fix case
--     to fail, so the case cannot pass by accident.
--   * The wiring is read from the source: the press handler calls the decision, the
--     task guard carries the new request, and both locale sources carry the strings.

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

-- The rule menu_container.lua applies to a press. It mirrors canOpenEntry: no task,
-- closed; otherwise open when the tile works offline or the link is up.
local function canOpen(offline, running, connected)
  return running == true and (offline == true or connected == true)
end

-- The rule before #2319: the same closed tiles, but a press reported nothing for
-- a flight-controller tile while the task ran.
local function oldBlockedBy(offline, running, connected)
  if running ~= true then return menuFeedback.TASK_MISSING end
  return nil
end

local blockedBy = SELF_TEST and oldBlockedBy or menuFeedback.blockedBy
if SELF_TEST then print("self-test: the old silent rule replaces the decision") end

local function describe(offline, running, connected)
  return string.format("offline=%s running=%s connected=%s",
    tostring(offline), tostring(running), tostring(connected))
end

print("agreement with the open rule")

for _, offline in ipairs({ false, true }) do
  for _, running in ipairs({ false, true }) do
    for _, connected in ipairs({ false, true }) do
      local open = canOpen(offline, running, connected)
      local blocked = blockedBy(offline, running, connected)
      check("a press reports a block exactly when the tile is closed: " .. describe(offline, running, connected),
        (blocked == nil) == open,
        string.format("open=%s blocked=%s", tostring(open), tostring(blocked)))
    end
  end
end

print("the fix")

check("a flight-controller tile with the task running and no link reports the link",
  blockedBy(false, true, false) == menuFeedback.NOT_CONNECTED,
  "got " .. tostring(blockedBy(false, true, false)))

check("a flight-controller tile with the task down still reports the task",
  blockedBy(false, false, false) == menuFeedback.TASK_MISSING,
  "got " .. tostring(blockedBy(false, false, false)))

check("a flight-controller tile with the task down and a link reports the task",
  blockedBy(false, false, true) == menuFeedback.TASK_MISSING,
  "got " .. tostring(blockedBy(false, false, true)))

print("tiles that work offline")

check("an offline tile with the task running and no link opens",
  blockedBy(true, true, false) == nil, "got " .. tostring(blockedBy(true, true, false)))

check("an offline tile with the task down still reports the task",
  blockedBy(true, false, false) == menuFeedback.TASK_MISSING,
  "got " .. tostring(blockedBy(true, false, false)))

check("an open flight-controller tile with the link up opens",
  blockedBy(false, true, true) == nil, "got " .. tostring(blockedBy(false, true, true)))

check("a missing running flag is treated as the task down",
  blockedBy(false, nil, true) == menuFeedback.TASK_MISSING,
  "got " .. tostring(blockedBy(false, nil, true)))

if not SELF_TEST then
  print("wiring")

  local press = readFile("src/rfsuite/app/menu_container.lua")
  check("the press handler asks the decision", press:find("menuFeedback.blockedBy(", 1, true) ~= nil)
  check("the press handler reports the link", press:find("taskGuard.requestNotConnectedAlert()", 1, true) ~= nil)
  check("menu_container loads the decision module", press:find('requireModule("lib/menu_feedback.lua")', 1, true) ~= nil)

  local tool = readFile("src/rfsuite/app/tool.lua")
  check("the task guard carries the request",
    tool:find("requestNotConnectedAlert = requestNotConnectedAlert,", 1, true) ~= nil)
  check("the wakeup shows the dialog", tool:find("showNotConnectedAlert()\nend", 1, true) ~= nil)
  check("a new tool open clears the dialog state",
    tool:find("notConnectedOpen = false\n  updateDeveloperMode()", 1, true) ~= nil)

  local TITLE, BODY = "app.msg_fc_not_connected_title", "app.msg_fc_not_connected_body"
  for _, locale in ipairs({ "cs", "de", "en", "es", "fr", "he", "it", "nl", "no", "pl", "pt-br", "zh-cn" }) do
    local text = readFile("src/rfsuite/i18n/" .. locale .. ".json")
    check("the strings resolve in " .. locale,
      text:find('"msg_fc_not_connected_title"', 1, true) ~= nil
        and text:find('"msg_fc_not_connected_body"', 1, true) ~= nil)
  end
  check("the English sources carry the title and body",
    readFile("bin/i18n/json/en.json"):find(TITLE:match("%.([^.]+)$"), 1, true) ~= nil
      and readFile("bin/i18n/json/en.json"):find(BODY:match("%.([^.]+)$"), 1, true) ~= nil)
end

if SELF_TEST then
  -- The fix case must fail under the old rule, or the case proves nothing.
  local oldFails = oldBlockedBy(false, true, false) ~= menuFeedback.NOT_CONNECTED
  check("the old silent rule fails the fix case", oldFails)
  print(string.format("%d checks, %d failures (self-test: failures expected)", checks, failures))
  os.exit(oldFails and 0 or 1)
end

print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
