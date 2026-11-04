-- Behaviour check for #2692: the Setup Wizard's tail calibrate and end stops pages
-- must not move the tail on entry.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_tail_hold/verify_setup_wizard_tail_hold.lua
--     lua5.4 bin/setup_wizard_tail_hold/verify_setup_wizard_tail_hold.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_tail.lua, with the
-- UI and art modules replaced by recording stubs and the real lib/setup_wizard_heli.lua
-- for the raw units. It pages from the Start page to the calibrate page and to the end
-- stops page, back to the calibrate page and forward again, and pins for each:
--   1. on entry the yaw input is held at 0, not at the stored limit, and the Held side
--      row shows no side;
--   2. the first press of the side button holds the side the row then shows, the next
--      press the other side;
--   3. a page entered again (Back, then Next) holds nothing until its button is pressed
--      again, even if it held when it was left.
--
-- --self-test runs the same checks on copies with parts of the fix taken out: the hold
-- taken on entry (the old behaviour), the reset on entry, the empty side row, and the
-- first press holding the shown side. Each must go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local MODULE = ROOT .. "/src/rfsuite/app/pages/setup_wizard_tail.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return s
end

-- ── stubs ─────────────────────────────────────────────────────────────

local TITLE_CAL = "@i18n(app.modules.setup_wizard.tal_cal_title)@"
local TITLE_LIM = "@i18n(app.modules.setup_wizard.tal_lim_title)@"
local LABEL_SIDE = "@i18n(app.modules.setup_wizard.tal_side)@"
local SIDE_CW = "@i18n(app.modules.setup_wizard.fin_cw)@"
local SIDE_CCW = "@i18n(app.modules.setup_wizard.fin_ccw)@"
local NO_SIDE = "--"

local scr
local function newScreen()
  local s = { title = nil, rows = nil, forward = nil, start = nil }
  function s.begin() s.rows, s.back, s.forward, s.start = nil, nil, nil, nil end
  function s.text(_, title) s.title = title end
  function s.step() end
  function s.picture() end
  function s.paint() end
  function s.refresh() end
  function s.grid() return {} end
  function s.checks(_, rows)
    s.rows = rows
    return {}
  end
  function s.row(_, back, _, forward)
    s.back, s.forward = back, forward
    return {}
  end
  function s.safety(_, _, _, _, startPress)
    s.start = startPress
    return {}
  end
  -- Any other drawing call is a no-op: the pictures and the paint are not under test.
  return setmetatable(s, { __index = function() return function() end end })
end

local realHeli = assert(loadfile(ROOT .. "/src/rfsuite/lib/setup_wizard_heli.lua"))()
local holds = {}
local wiz
local function newWiz()
  local w = {
    inputs = { yaw = { rate = 1000 } },
    holdAxis = function(name, value) holds[#holds + 1] = { name = name, value = value }; return true end,
    releaseAxes = function() holds[#holds + 1] = { name = "yaw", value = nil } end,
    editInput = function() end,
    editMix = function() end,
    rebuild = function() end,
    forward = function(fn) return { text = "Save", press = fn } end,
    finishStep = function() end,
    motorRunning = function() return false end,
    motorised = function() return false end,
    mixConfig = function() return {} end,
    releaseMotor = function() end,
    holdMotor = function() end,
    canSpin = function() return false end,
  }
  return w
end

local stubs = {}
stubs["app/setup_wizard_ui.lua"] = { new = function() scr = newScreen(); return scr end }
-- Every art call returns an empty layout: the pictures are not under test.
local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end
stubs["app/setup_wizard_art.lua"] = setmetatable({}, {
  __index = function() return function() return anyObject() end end,
})
stubs["lib/setup_wizard_heli.lua"] = realHeli
package.loaded["rfsuite.lib.require"] = function(path)
  local s = stubs[path]
  if not s then error("unexpected require: " .. tostring(path)) end
  return s
end

-- ── drive the step ────────────────────────────────────────────────────

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local function lastHold()
  local last = holds[#holds]
  return last and last.value
end

local function run(source)
  local before = failures
  holds = {}
  wiz = newWiz()
  local chunk = assert(load(source, "@setup_wizard_tail.lua", "t"))
  local tail = chunk()
  local step = tail.new(wiz)

  step.build()
  check("the intro page offers Start", scr.start ~= nil)
  if not scr.start then return failures - before end
  scr.start()

  -- Page forward until the requested title is on screen, with a bound.
  local function reach(title)
    for _ = 1, 12 do
      step.build()
      if scr.title == title then return true end
      if not (scr.forward and scr.forward.press) then return false end
      scr.forward.press()
    end
    return false
  end

  -- The row that carries the side button: the answer with a press.
  local function sideButton()
    for _, r in ipairs(scr.rows or {}) do
      if r.answer and r.press and r.needsMotion then return r end
    end
    return nil
  end

  -- The value the Held side row shows.
  local function shownSide()
    for _, r in ipairs(scr.rows or {}) do
      if r.label == LABEL_SIDE then return r.value end
    end
    return nil
  end

  local function sign(v) return v and (v > 0 and 1 or (v < 0 and -1 or 0)) end

  -- One page with a side button: nothing held and no side shown on entry, the first press
  -- holds the side shown afterwards (firstSide, firstSign), the second press the other one.
  local function pageChecks(name, firstSide, firstSign)
    check(name .. ": nothing is held on entry", lastHold() == nil or lastHold() == 0,
      "held=" .. tostring(lastHold()))
    check(name .. ": no side is shown before the side button", shownSide() == NO_SIDE,
      "shown=" .. tostring(shownSide()))
    local btn = sideButton()
    check(name .. ": the side button is there", btn ~= nil)
    if not btn then return end
    btn.press()
    step.build()
    check(name .. ": the first press holds the side it then shows",
      sign(lastHold()) == firstSign and shownSide() == firstSide,
      "held=" .. tostring(lastHold()) .. " shown=" .. tostring(shownSide()))
    btn = sideButton()
    if btn then btn.press() end
    step.build()
    check(name .. ": the next press holds the other side",
      sign(lastHold()) == -firstSign and shownSide() ~= firstSide and shownSide() ~= NO_SIDE,
      "held=" .. tostring(lastHold()) .. " shown=" .. tostring(shownSide()))
  end

  -- Calibrate page: +1 is the counter-clockwise side.
  if reach(TITLE_CAL) then
    pageChecks("calibrate", SIDE_CCW, 1)
  else
    check("the calibrate page is reached", false)
  end

  -- End stops page, entered from a calibrate page that holds: -1 is the clockwise end.
  holds = {}
  if reach(TITLE_LIM) then
    pageChecks("end stops", SIDE_CW, -1)
  else
    check("the end stops page is reached", false)
  end

  -- Back from an end stops page that holds, into the calibrate page it held before:
  -- a page entered again holds nothing until its side button is pressed again.
  holds = {}
  if scr.back then scr.back() end
  step.build()
  check("calibrate again: back from the end stops page is the calibrate page", scr.title == TITLE_CAL,
    "title=" .. tostring(scr.title))
  check("calibrate again: nothing is held on entry", lastHold() == nil or lastHold() == 0,
    "held=" .. tostring(lastHold()))
  check("calibrate again: no side is shown", shownSide() == NO_SIDE, "shown=" .. tostring(shownSide()))
  holds = {}
  if reach(TITLE_LIM) then
    check("end stops again: nothing is held on entry", lastHold() == nil or lastHold() == 0,
      "held=" .. tostring(lastHold()))
    check("end stops again: no side is shown", shownSide() == NO_SIDE, "shown=" .. tostring(shownSide()))
  else
    check("the end stops page is reached again", false)
  end

  return failures - before
end

local source = readFile(MODULE)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  tail hold: calibrate and end stops hold nothing on entry (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- Each mutant removes or changes lines of the fix; every one must go red.
local MUTANTS = {
  { name = "hold taken on entry (the old behaviour)", edits = {
    { "      if not calHeld then return 0 end\r?\n", "" },
    { "      if not limitHeld then return 0 end\r?\n", "" },
  } },
  { name = "a page entered again keeps its earlier hold", edits = {
    { "    if name == \"calibrate\" then calHeld = false end\r?\n", "" },
    { "    if name == \"limits\" then limitHeld = false end\r?\n", "" },
  } },
  { name = "a side is shown before the side button", edits = {
    { "value = not calHeld and NO_SIDE or ", "value = " },
    { "value = not limitHeld and NO_SIDE or ", "value = " },
  } },
  { name = "the first press flips the side", edits = {
    { "if calHeld then calSide = %-calSide end", "calSide = -calSide" },
    { "if limitHeld then limitSide = %-limitSide end", "limitSide = -limitSide" },
  } },
}

local allRed = true
for _, m in ipairs(MUTANTS) do
  local mutated, count = source, 0
  for _, e in ipairs(m.edits) do
    local n
    mutated, n = mutated:gsub(e[1], e[2])
    count = count + n
  end
  if count ~= #m.edits then
    print("FAIL  self-test: the lines of mutant '" .. m.name .. "' were not found; update this harness")
    os.exit(1)
  end
  failures, checks = 0, 0
  local caught = run(mutated)
  if caught > 0 then
    print("ok    mutant red: " .. m.name .. " (" .. caught .. " failed checks)")
  else
    print("FAIL  mutant passed the checks: " .. m.name)
    allRed = false
  end
end
if allRed then
  print("OK  self-test: every mutant goes red")
  os.exit(0)
end
os.exit(1)
