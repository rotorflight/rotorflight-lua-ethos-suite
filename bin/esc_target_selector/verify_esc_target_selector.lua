-- Behaviour check for the ESC target selector of the 4-way forward-programming
-- pages (#2338).
--
-- Run it:
--     lua5.4 bin/esc_target_selector/verify_esc_target_selector.lua
--     lua5.4 bin/esc_target_selector/verify_esc_target_selector.lua --self-test
--
-- What the defect under test is:
--   Every 4-way page -- AM32, BLHeli_S, Bluejay, FlyRotor, Scorpion, HW5, OMP,
--   XDFly, YGE, ZTW -- opens on app/pages/esc_forward_4way.lua, which asks the FC
--   how many ESCs there are and then builds its selector. It built ALL FOUR rows
--   ("ESC 1".."ESC 4") and greyed out the surplus with button:enable(i <= count).
--
--   So a single-ESC helicopter showed three dead lines. Nothing in the UI said
--   they were dead, and on a 480x320 screen they were a third of the page. The
--   issue reported this as an inert "ESC Target 1 / 2" combo box; what is actually
--   built is a four-row list, and the defect is the same one: a control that
--   cannot be used is not a disabled control, it is noise.
--
--   Two halves, and the second is the one with the trap in it:
--     * render only the ESCs that exist;
--     * with exactly ONE ESC there is no choice to offer, so there is no selector
--       at all -- the page goes straight to that ESC.
--
--   The trap: the FC's answer has three distinguishable states, not two. A count
--   of 1 means one ESC. NO count means the reply carried no motor_count_blheli --
--   which is not one ESC, it is ignorance, and collapsing the two enters
--   pass-through on a two-ESC helicopter because the read came back thin. So an
--   unknown count keeps the selector and keeps this page's long-standing
--   conservative default of ESC 1 only.
--
--   The issue's other half -- dropping the parsed cache on page exit -- needs no
--   code. It has been in place since the total rewrite (#2256, 2026-08-07),
--   seventeen days before the issue was filed: esc_forward_vendor.lua:124-156
--   resets the FBL control with clearQueue, closes the dialog, nils pendingData
--   and pendingError, disposes the runtime, drops every handler, unloads the
--   codec from package.loaded and collects. open() issues a fresh read on every
--   call (esc_forward_vendor.lua:295), so there is no cache that could survive.
--   --the-teardown-that-already-existed below PINS that, because "no cache" is a
--   claim about code that has to keep being true.
--
-- What it drives, and why:
--   * The real app/pages/esc_forward_4way.lua, loaded from its path rather than
--     through the suite's require, because --self-test has to run the SAME checks
--     against a staged copy of it. No existing harness loads this page at all: the
--     others stub it precisely to avoid its os.clock() delays
--     (verify_esc_signature.lua:464-470), which is why the dead rows survived.
--   * bus, msp_motor_config, msp_4wif_esc_fwd_prog, progress_dialog and esc_error
--     are stubs. The bus records every published message, which is how the
--     auto-open case is observed at all: an auto-open is a 4-way write to the
--     pre-switch target with no tap behind it.
--   * The real app/header.lua and app/close_key.lua -- both are thin and both are
--     on the path. form.getFieldSlots() has to hand back real rects for header's
--     buildTitleRect(), or a too-thin stub looks like a defect in the page.
--
-- Which checks go RED without the fix:
--   5 gates, and 6 checks in total. --self-test proves that rather than asserting
--   it: it cuts the four pieces out, re-runs every check against the sabotaged page
--   and requires each of the five gates to turn red, comparing verdicts BY NAME so
--   a reorder cannot pass it. The sixth red check is a plain one that happens to
--   detect the change as well ("one ESC publishes the pre-switch write").
--
--   The remaining twelve are not gates, and saying so is part of the result. Four
--   of them guard behaviour this change must NOT alter -- the press path, the three
--   unknown-count cases -- and one pins the teardown #2256 already shipped. They
--   would be green before and after, so calling them gates would be claiming a
--   detection they do not have. The self-test found that on its own: the first
--   version marked them all as gates and reported nine that could not fail, then two
--   more once the sabotage was corrected.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = (ROOT .. "/src/rfsuite"):gsub("\\", "/")
local PREFIX = SUITE .. "/"
local REAL_PAGE = SUITE .. "/app/pages/esc_forward_4way.lua"

package.path = PREFIX .. "?.lua;" .. package.path
_G.PREFIX = PREFIX

-- String repetition is NOT available here: "ab" * 3 raises "attempt to mul a
-- 'string' with a 'number'" on both toolchain builds (lua-5.4.3 and lua-5.4.6,
-- correct bytes, verified in isolation). That is why no file under src/ uses it.
-- string.rep is the only form, and it cost an hour to find.
local function rule() return string.rep("-", 62) end
local function bar() return string.rep("=", 72) end

local failures = 0
local total = 0
local selfTest = arg[1] == "--self-test"

local function say(fmt, ...)
  io.write(string.format(fmt, ...), "\n")
end

-- ---------------------------------------------------------------------------
-- Scaffolding
-- ---------------------------------------------------------------------------

local REAL_LOADFILE = loadfile
local function harnessLoadfile(path, ...)
  path = tostring(path):gsub("\\", "/")
  if path:sub(1, 4) == "app/" or path:sub(1, 4) == "lib/" then
    return REAL_LOADFILE(PREFIX .. path, ...)
  end
  return REAL_LOADFILE(path, ...)
end

_G.loadfile = harnessLoadfile
_G.package = package
_G.os = os
_G.math = math
_G.string = string
_G.table = table

_G.system = {getVersion = function() return {simulation = false, radio = {name = "stub"}} end}
-- app/header.lua loads its nav-button icon masks when the module loads.
_G.lcd = {loadMask = function(p) return {path = p} end}
_G.LEFT, _G.CENTERED, _G.RIGHT = 1, 2, 3
_G.FONT_XS, _G.FONT_S, _G.FONT_M, _G.FONT_L = 6, 7, 8, 9
_G.EVT_CLOSE = 0x01
_G.EVT_KEY = 0x02

local obs = {}
local function resetObs()
  obs.lines = {}
  obs.buttons = {}
  obs.writes = {}
  obs.requests = {}
end

local function widgetStub(kind, line)
  return {
    enable = function(self, v) self.enabled = (v ~= false); return self end,
    press = function(self) if self.onPress then self.onPress() end end,
    _kind = kind,
    _line = line,
    enabled = true,
  }
end

_G.form = {
  clear = function() obs.lines = {}; obs.buttons = {} end,
  addLine = function(text)
    obs.lines[#obs.lines + 1] = text
    return text
  end,
  getFieldSlots = function()
    return {
      {x = 0, y = 0, w = 300, h = 30},
      {x = 310, y = 0, w = 80, h = 30},
    }
  end,
  addStaticText = function(line, _rect, text)
    local w = widgetStub("staticText", line)
    w.text = text
    w.value = function(_, v) w.text = v end
    return w
  end,
  addTextButton = function() return widgetStub("textbutton") end,
  addButton = function(line, _slot, opts)
    local b = widgetStub("button", line)
    b.onPress = opts and opts.press
    b.text = opts and opts.text
    obs.buttons[#obs.buttons + 1] = b
    return b
  end,
  addNumberField = function() return widgetStub("number") end,
  addChoiceField = function() return widgetStub("choice") end,
  setText = function() end,
  getText = function() return "" end,
}

package.loaded["rfsuite.lib.bus"] = {
  subscribe = function() end,
  publish = function(topic, message)
    if topic ~= "msp.request" then return end
    obs.requests[#obs.requests + 1] = message
    if message and message.target ~= nil then
      obs.writes[#obs.writes + 1] = message.target
    end
  end,
}

package.loaded["rfsuite.lib.msp_4wif_esc_fwd_prog"] = {
  buildWriteMessage = function(target, onWritten, onError, opts)
    return {target = target, onWritten = onWritten, onError = onError, opts = opts, clearQueue = false}
  end,
}

local readError = false
package.loaded["rfsuite.lib.msp_motor_config"] = {
  buildReadMessage = function(onData, onError)
    return {
      topic = "msp.request",
      reply = function(data)
        if readError then
          if onError then onError("timeout") end
        elseif onData then
          onData(data or {})
        end
      end,
    }
  end,
}

package.loaded["rfsuite.app.progress_dialog"] = {
  SPEED = {DEFAULT = 1, SLOW = 2, VSLOW = 3},
  open = function() return {value = function() end, close = function() end} end,
}
package.loaded["rfsuite.app.esc_error"] = {
  addLines = function(reason)
    obs.errorLines = (obs.errorLines or 0) + 1
    obs.lastError = reason
  end,
}
package.loaded["rfsuite.app.header"] = nil
package.loaded["rfsuite.app.close_key"] = nil

-- ---------------------------------------------------------------------------
-- Driving one open of the selector page
-- ---------------------------------------------------------------------------

local handlers = {}
local opts = {
  setEventHandler = function(h) handlers.event = h end,
  setWakeupHandler = function(h) handlers.wakeup = h end,
  setPaintHandler = function(h) handlers.paint = h end,
  setCleanupHandler = function(h) handlers.cleanup = h end,
  onBack = function() obs.back = true end,
}

local function tick()
  if handlers.wakeup then handlers.wakeup() end
end

-- Open the page, deliver the count, and settle one wakeup -- the order the radio
-- does it in: open() publishes the read, the reply arrives, the next wakeup either
-- builds the selector or bypasses it.
local function driveSelector(pagePath, reply, mode)
  resetObs()
  readError = (mode == "error")
  handlers = {}
  package.loaded["rfsuite.app.pages.esc_forward_4way"] = nil
  local chunk = assert(loadfile(pagePath))
  local page = chunk()

  page.open(opts, {
    pageTitle = "Test",
    preSwitchDelay = 0,
    switchReadDelay = 0,
    openEditor = function(_, selection) obs.editorOpened = selection end,
  })

  local read
  for _, m in ipairs(obs.requests) do
    if m and m.reply then read = m end
  end
  if read then
    local payload
    if mode == "error" then
      payload = nil
    elseif mode == "nofield" then
      payload = {motors = 1}
    else
      payload = {motor_count_blheli = reply}
    end
    read.reply(payload)
  end
  tick()
end

-- Which ESC rows the pilot can see.
--
-- Matched EXACTLY ("ESC 1", not "anything containing ESC 1"): the auto-open path
-- puts "Selecting ESC 1..." on screen through the same form.addLine(), so a
-- substring match counts the status line as a selector row and the one-ESC case
-- reports a row that is not there. A count assertion that a status message can
-- satisfy is not a count assertion.
local function escRows()
  local rows = {}
  for _, line in ipairs(obs.lines) do
    local n = tonumber(string.match(line, "^ESC (%d)$"))
    if n then rows[#rows + 1] = n end
  end
  return rows
end

-- Counts only the ESC rows, not the header's Menu button: header.build() goes
-- through the same form.addButton, so counting every button reports one too many.
local function enabledCount()
  local n = 0
  for _, b in ipairs(obs.buttons) do
    if b._line and string.match(b._line, "^ESC %d$") and b.enabled then n = n + 1 end
  end
  return n
end

local function rowFor(n)
  for _, b in ipairs(obs.buttons) do
    if b._line and tonumber(string.match(b._line, "^ESC (%d)$")) == n then return b end
  end
end

local function rowsText(rows)
  if #rows == 0 then return "(none)" end
  local parts = {}
  for _, n in ipairs(rows) do parts[#parts + 1] = tostring(n) end
  return table.concat(parts, ",")
end

-- Gate bookkeeping. A gate is a check that must be red in pass 2, so both the name
-- and its verdict are kept and compared across the two passes.
local gateOrder, gateGreen = {}, {}
local VERDICT, GATE = {}, {}

local function record(name, ok, detail, isGate)
  total = total + 1
  if ok then
    say("  ok    %s", name)
  else
    failures = failures + 1
    say("  FAIL  %s%s", name, detail and (" -- " .. tostring(detail)) or "")
  end
  VERDICT[name] = ok
  if isGate then
    gateOrder[#gateOrder + 1] = name
    gateGreen[name] = ok
    GATE[#GATE + 1] = isGate
  end
end

local function pass(name, ok, detail) record(name, ok, detail, false) end
local function gate(name, ok, detail) record(name, ok, detail, true) end

-- ---------------------------------------------------------------------------
-- The cases
-- ---------------------------------------------------------------------------

local function runChecks(pagePath)
  failures = 0
  total = 0
  gateOrder, gateGreen = {}, {}

  say("")
  say("ESC target selector: only the ESCs that exist get a row (#2338)")
  say("")

  -- one ESC: no selector at all ------------------------------------------
  driveSelector(pagePath, 1)
  local rows = escRows()
  gate("one ESC renders no selector row at all", #rows == 0,
    "rendered ESC rows: " .. rowsText(rows))
  gate("one ESC goes straight into pass-through, with no tap", #obs.writes > 0,
    "4-way writes published: " .. #obs.writes)
  pass("one ESC publishes the pre-switch write to the all-targets value",
    obs.writes[1] == 100, "first write target was " .. tostring(obs.writes[1]))

  -- two ESCs: two rows, and both work -------------------------------------
  driveSelector(pagePath, 2)
  rows = escRows()
  gate("two ESCs render exactly two rows",
    #rows == 2 and rows[1] == 1 and rows[2] == 2, "rendered ESC rows: " .. rowsText(rows))
  -- "every rendered row is openable", not "two are enabled". Counting enabled
  -- rows passes on the pre-fix page too -- it renders four rows and enables the
  -- first two -- so that assertion cannot see the defect. The dead control IS the
  -- rendered-but-disabled row, so the count that matters is rendered vs enabled.
  gate("no rendered row is left dead on a known count", enabledCount() == #rows,
    string.format("%d ESC rows rendered, %d openable", #rows, enabledCount()))

  -- three and four ESCs ---------------------------------------------------
  driveSelector(pagePath, 3)
  gate("three ESCs render exactly three rows", #escRows() == 3,
    "rendered ESC rows: " .. rowsText(escRows()))
  -- Four ESCs render four rows before AND after, so this cannot be a gate. Kept as
  -- a check because it pins the upper end: a row bound written as `< count` instead
  -- of `<= count` would drop ESC 4 and this is what would notice.
  driveSelector(pagePath, 4)
  pass("four ESCs render exactly four rows", #escRows() == 4,
    "rendered ESC rows: " .. rowsText(escRows()))

  -- a row that is there can be pressed ------------------------------------
  --
  -- NOT a gate, and deliberately so: a rendered row was pressable before this
  -- change as well, so a gate here would be a check that cannot fail. It earns its
  -- place as a regression guard on the press path the new row bound feeds.
  driveSelector(pagePath, 3)
  local b = rowFor(2)
  pass("a rendered row opens that ESC", b ~= nil and (function()
    local before = #obs.writes
    b:press()
    return #obs.writes > before
  end)(), "row 2 button missing or inert")

  -- the trap: an unknown count is not one ESC ------------------------------
  --
  -- None of these three are gates either, and that is the point of them. The
  -- pre-fix page already refused to enter pass-through on an unanswered read and
  -- already listed all four targets, so a gate would be a check that cannot fail.
  -- What they guard is the OTHER direction: the single-ESC bypass introduced here
  -- must not swallow the unknown case. They are the reason a future "simplify the
  -- count handling" edit cannot quietly enter pass-through on a two-ESC heli.
  for _, case in ipairs({
    {mode = "nofield", label = "a reply with no motor_count_blheli"},
    {mode = "error", label = "a read that failed"},
    {reply = 0, label = "a reported count of 0"},
  }) do
    driveSelector(pagePath, case.reply, case.mode)
    local shown = escRows()
    pass("unknown count (" .. case.label .. ") does NOT go straight in", #obs.writes == 0,
      "4-way writes published: " .. #obs.writes)
    pass("unknown count (" .. case.label .. ") shows all four targets", #shown == 4,
      "rendered ESC rows: " .. rowsText(shown))
    pass("unknown count (" .. case.label .. ") leaves only ESC 1 openable",
      enabledCount() == 1, "enabled buttons: " .. enabledCount())
  end

  -- --the-teardown-that-already-existed -----------------------------------
  --
  -- Also not a gate: it pins behaviour that #2256 put in place seventeen days
  -- before the issue was filed, so it cannot go red without this change.
  driveSelector(pagePath, 2)
  local before = #obs.requests
  if handlers.cleanup then handlers.cleanup() end
  local released = false
  for i = before + 1, #obs.requests do
    local m = obs.requests[i]
    if m and m.target == 100 and m.clearQueue == true then released = true end
  end
  pass("leaving the page releases the FBL control with the queue cleared", released,
    "no reset write with clearQueue after cleanup")

  say("")
  say(string.format("checks: %d   failures: %d", total, failures))
end

runChecks(REAL_PAGE)
-- Remembered, because pass 2 is SUPPOSED to fail: the exit code has to report pass
-- 1, or a correct self-test reports failure.
local pass1Failures = failures

-- ---------------------------------------------------------------------------
-- --self-test: every gate must be able to go red
-- ---------------------------------------------------------------------------

if selfTest then
  say("")
  say(bar())
  say("self-test: the gate checks must go red without the fix")
  say(bar())

  local function readFile(p)
    local fh = assert(io.open(p, "rb"))
    local s = fh:read("a")
    fh:close()
    return s
  end

  local function replace(src, open_, close_, replacement, what, nl)
    local at = src:find(open_, 1, true)
    if not at then error("sabotage: could not find the start of " .. tostring(what), 0) end
    local last = src:find(close_, at, true)
    if not last then error("sabotage: could not find the end of " .. tostring(what), 0) end
    return src:sub(1, at - 1) .. replacement .. nl .. src:sub(last + #close_)
  end

  local src = readFile(REAL_PAGE)
  local nl = src:find("\r\n", 1, true) and "\r\n" or "\n"

  -- (1) the row bound goes back to "all four".
  local staged = replace(src,
    "local shown = countKnown and targetCount or #TARGETS",
    "local shown = countKnown and targetCount or #TARGETS",
    "local shown = #TARGETS", "the row bound", nl)
  -- (2) and the enable expression goes back to the pre-fix one.
  --
  -- Both halves are needed for a pre-fix shape. The self-test said so: with only
  -- (1) reverted, four rows are built but the NEW enable expression switches them
  -- all on, so "no rendered row is left dead" stayed green. The dead row in the
  -- pre-fix page came from button:enable(i <= targetCount), so that line is part of
  -- the defect and part of the sabotage.
  staged = replace(staged,
    "button:enable(countKnown or i == 1)",
    "button:enable(countKnown or i == 1)",
    "button:enable(i <= targetCount)", "the enable expression", nl)
  -- (3) the single-ESC bypass goes away.
  staged = replace(staged,
    "if countKnown and targetCount == 1 then",
    "if countKnown and targetCount == 1 then",
    "if false then", "the single-ESC bypass", nl)
  -- (4) and the reply callbacks go back to the pre-fix ones.
  --
  -- This one was not obvious. With (1) and (2) reverted but the new callbacks left
  -- in place, pass 2 CRASHED on the first unknown-count case: the pre-fix enable
  -- line is button:enable(i <= targetCount), and an unknown count now leaves
  -- targetCount nil, so "i <= nil" raises. Which is the real story about the old
  -- code -- its "targetCount = 1" on a failed read was not tidiness, it was the
  -- only thing stopping that comparison from throwing. The sabotage has to restore
  -- it, or pass 2 dies before the remaining checks can report.
  staged = replace(staged,
    "targetCount = readTargetCount(data and data.motor_count_blheli)",
    "targetCount = readTargetCount(data and data.motor_count_blheli)",
    "targetCount = clampTargetCount(data and data.motor_count_blheli)",
    "the success callback", nl)
  staged = replace(staged,
    "    targetCount = nil" .. nl .. "    countKnown = false",
    "    targetCount = nil" .. nl .. "    countKnown = false",
    "    targetCount = 1" .. nl .. "    countKnown = false",
    "the error callback", nl)

  if staged == src then
    say("  FAIL  the sabotage changed nothing")
    os.exit(1)
  end

  local stagedPath = REAL_PAGE .. ".selftest"
  local fh = assert(io.open(stagedPath, "wb"))
  fh:write(staged)
  fh:close()

  if readFile(stagedPath) ~= staged then
    say("  FAIL  the sabotaged page does not read back byte-identical")
    os.remove(stagedPath)
    os.exit(1)
  end

  -- Pass 2 runs the SAME checks against the sabotaged page. Comparing verdicts by
  -- name, not by position, so reordering a check cannot quietly pass this.
  local greenBefore = {}
  for _, name in ipairs(gateOrder) do greenBefore[name] = gateGreen[name] end

  say("")
  say("pass 2, against the sabotaged page:")
  runChecks(stagedPath)

  local problems = {}
  local turnedRed = 0
  for _, name in ipairs(gateOrder) do
    if greenBefore[name] then
      if VERDICT[name] == false then
        turnedRed = turnedRed + 1
      else
        problems[#problems + 1] = "still green without the fix: " .. name
      end
    end
  end

  os.remove(stagedPath)

  say("")
  for i = 1, #problems do say("  FAIL  %s", problems[i]) end
  if #problems > 0 then
    say("")
    say(string.format("SELF-TEST FAILED -- %d gate check(s) cannot detect the defect", #problems))
    os.exit(1)
  end

  say("")
  say(string.format("SELF-TEST PASSED -- all %d gate checks go red without the fix", turnedRed))
end

if pass1Failures > 0 then os.exit(1) end