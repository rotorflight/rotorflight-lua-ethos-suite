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
-- stops page, and pins for each:
--   1. on entry the yaw input is held at 0, not at the stored limit;
--   2. the side button starts the hold: the yaw input is held at the page's value.
--
-- --self-test runs the same checks on a copy where the hold is taken on entry (the
-- old behaviour). It must go red.

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

local scr
local function newScreen()
  local s = { title = nil, rows = nil, forward = nil, start = nil }
  function s.begin() s.rows, s.forward, s.start = nil, nil, nil end
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
  function s.row(_, _, _, forward)
    s.forward = forward
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

  -- Calibrate page.
  if reach(TITLE_CAL) then
    check("calibrate: nothing is held on entry", lastHold() == nil or lastHold() == 0,
      "held=" .. tostring(lastHold()))
    local btn = sideButton()
    check("calibrate: the side button is there", btn ~= nil)
    if btn then
      btn.press()
      step.build()
      check("calibrate: the side button starts the hold", lastHold() ~= nil and lastHold() ~= 0,
        "held=" .. tostring(lastHold()))
    end
  else
    check("the calibrate page is reached", false)
  end

  -- End stops page.
  holds = {}
  if reach(TITLE_LIM) then
    check("end stops: nothing is held on entry", lastHold() == nil or lastHold() == 0,
      "held=" .. tostring(lastHold()))
    local btn = sideButton()
    check("end stops: the side button is there", btn ~= nil)
    if btn then
      btn.press()
      step.build()
      check("end stops: the side button starts the hold", lastHold() ~= nil and lastHold() ~= 0,
        "held=" .. tostring(lastHold()))
    end
  else
    check("the end stops page is reached", false)
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

-- The old behaviour: the hold is taken on entry.
local mutated = source
local count = 0
for _, pat in ipairs({ "      if not calHeld then return 0 end\r?\n", "      if not limitHeld then return 0 end\r?\n" }) do
  local n
  mutated, n = mutated:gsub(pat, "")
  count = count + n
end
if count ~= 2 then
  print("FAIL  self-test: the entry guards were not found twice; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = run(mutated)
if caught > 0 then
  print("ok    mutant red: hold taken on entry (" .. caught .. " failed checks)")
  print("OK  self-test: the old behaviour goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: hold taken on entry")
os.exit(1)
