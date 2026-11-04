-- Behaviour check for #2693: the Setup Wizard's Gyro step must not assume an answer.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_gyro/verify_setup_wizard_gyro.lua
--     lua5.4 bin/setup_wizard_gyro/verify_setup_wizard_gyro.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_gyro.lua, with the
-- UI and art modules replaced by recording stubs. It walks the Start page and
-- the roll page and pins:
--   1. an axis starts unanswered: the switch does not read Against, the way
--      forward is disabled, and no wrong-answer note is shown;
--   2. Against enables the way forward;
--   3. With shows the wrong-answer note and keeps the way forward disabled.
--
-- --self-test runs the same checks on a copy of the module with the old
-- default restored (an unanswered axis counts as Against). It must go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local MODULE = ROOT .. "/src/rfsuite/app/pages/setup_wizard_gyro.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

-- ── recording stubs ───────────────────────────────────────────────────

local scr
local function newScreen()
  local s = { rows = nil, forward = nil, start = nil, notes = 0 }
  function s.begin() s.rows, s.forward, s.start = nil, nil, nil end
  function s.text() end
  function s.step() end
  function s.picture() end
  function s.paint() end
  function s.refresh() end
  function s.checks(_, rows)
    s.rows = rows
    for _, r in ipairs(rows) do
      if r.note then s.notes = s.notes + 1 end
    end
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
  return s
end

local stubs = {}
stubs["app/setup_wizard_ui.lua"] = {
  new = function() scr = newScreen(); return scr end,
}
stubs["app/setup_wizard_art.lua"] = {
  image = function() return {} end,
}
package.loaded["rfsuite.lib.require"] = function(path)
  local s = stubs[path]
  if not s then error("unexpected require: " .. tostring(path)) end
  return s
end

-- ── drive the step ────────────────────────────────────────────────────

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return s
end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local function run(source)
  local before = failures
  local chunk = assert(load(source, "@setup_wizard_gyro.lua", "t"))
  local gyro = chunk()
  local rebuilds = 0
  local wiz = {
    motorised = function() return false end,
    rebuild = function() rebuilds = rebuilds + 1 end,
    forward = function(fn) return { text = "Save", press = fn } end,
    finishStep = function() end,
    goToStep = function() end,
  }
  local step = gyro.new(wiz)

  -- Start page: press Start to reach the roll check.
  step.build()
  check("the safety page offers Start", scr.start ~= nil)
  if scr.start then scr.start() end
  step.build()

  local toggle = scr.rows and scr.rows[1] and scr.rows[1].toggle
  check("the roll page has its Against/With switch", toggle ~= nil)
  if not toggle then return failures - before end
  local getter, setter = toggle[1], toggle[2]

  -- 1. Unanswered.
  check("an unanswered axis does not read as Against", getter() ~= true, "getter=" .. tostring(getter()))
  check("the way forward is disabled while unanswered",
    scr.forward ~= nil and scr.forward.disabled == true)
  check("no wrong-answer note while unanswered", scr.notes == 0, "notes=" .. scr.notes)

  -- 2. Against enables the way forward.
  setter(true)
  step.build()
  check("Against enables the way forward",
    scr.forward ~= nil and not scr.forward.disabled)
  check("no wrong-answer note after Against", scr.notes == 0)

  -- 3. With: note shown, way forward disabled.
  setter(false)
  step.build()
  check("With shows the wrong-answer note", scr.notes == 1, "notes=" .. scr.notes)
  check("With keeps the way forward disabled",
    scr.forward ~= nil and scr.forward.disabled == true)

  return failures - before
end

local source = readFile(MODULE)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  gyro step: no axis is answered by default; Next waits for Against (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- The old default: an unanswered axis reads as Against and enables Next.
local oldGetter = "return against[ci] == true"
local oldIsAgainst = "local isAgainst = against[ci] == true"
local mutated = source
local n1, c1 = mutated:gsub(oldGetter:gsub("%p", "%%%0"), "return against[ci] ~= false")
local n2, c2 = n1:gsub(oldIsAgainst:gsub("%p", "%%%0"), "local isAgainst = against[ci] ~= false")
if c1 ~= 1 or c2 ~= 1 then
  print("FAIL  self-test: the lines to break were not found once each; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = run(n2)
if caught > 0 then
  print("ok    mutant red: unanswered axis counted as Against (" .. caught .. " failed checks)")
  print("OK  self-test: the old default goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: the old default")
os.exit(1)
