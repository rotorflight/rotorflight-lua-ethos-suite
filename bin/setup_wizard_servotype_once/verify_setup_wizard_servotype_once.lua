-- Behaviour check for #2695: the Setup Wizard's servo type step applies a group's default type only the
-- first time it shows the group in a wizard session, and keeps a hand-set rate on later visits.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_servotype_once/verify_setup_wizard_servotype_once.lua
--     lua5.4 bin/setup_wizard_servotype_once/verify_setup_wizard_servotype_once.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_servotype.lua and the real
-- lib/setup_wizard_heli.lua, with the UI and art modules replaced by recording stubs and the servo
-- configs held by a wizard stand-in. It pins:
--   1. the module loads (a broken line in it once passed CI, because nothing loaded it);
--   2. on the first visit a group whose servos match no type gets the group's first type;
--   3. a rate set by hand after that is kept when the step is opened again in the same wizard;
--   4. a new wizard session applies the default again (the "once" is per session).
--
-- --self-test runs the same checks on a copy that forgets the applied groups on every visit (the old
-- behaviour) and requires check 3 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local STEP = ROOT .. "/src/rfsuite/app/pages/setup_wizard_servotype.lua"
local HELI = ROOT .. "/src/rfsuite/lib/setup_wizard_heli.lua"
local STORE_KEY = "rfsuite.setup_wizard.servotype.opened"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local HAND_RATE = 400        -- a wide-band rate that matches no preset (custom)

_G.lcd = setmetatable({RGB = function() return 0 end}, {__index = function() return function() end end})

local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end

-- A recording screen: the safety card's Start, everything else a no-op.
local holder = {}
local function newScreen()
  local s = {start = nil}
  holder.screen = s
  function s.begin() s.start = nil end
  function s.safety(_, _, _, _, startPress) s.start = startPress; return {} end
  return setmetatable(s, { __index = function() return function() return {} end end })
end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local heli = assert(loadfile(HELI))()

-- A wizard session: three cyclic servos with a hand-set rate, and the edits the step makes.
local function newWiz()
  local wiz = {configs = {}, edits = 0}
  for servo = 0, 2 do wiz.configs[servo] = {mid = 1520, min = -500, max = 500, rate = HAND_RATE} end
  function wiz.servos()
    return {{servo = 0, tail = false}, {servo = 1, tail = false}, {servo = 2, tail = false}}
  end
  function wiz.editServo(servo, fn)
    wiz.edits = wiz.edits + 1
    fn(wiz.configs[servo])
  end
  function wiz.rebuild() end
  function wiz.requestReboot() end
  function wiz.rebootPending() return false end
  return setmetatable(wiz, { __index = function() return function() end end })
end

-- Opens the step on `wiz` and goes from the safety card to the first group.
local function visit(stepModule, wiz)
  local node = stepModule.new(wiz)
  node.build()
  local start = holder.screen and holder.screen.start
  if start then start() end
  node.build()
end

local function run(source)
  local before = failures
  package.loaded[STORE_KEY] = nil
  package.loaded["rfsuite.lib.require"] = function(path)
    if path == "app/setup_wizard_ui.lua" then return {new = function() return newScreen() end} end
    if path == "app/setup_wizard_art.lua" then
      return setmetatable({}, {__index = function() return function() return anyObject() end end})
    end
    if path == "lib/setup_wizard_heli.lua" then return heli end
    error("unexpected require: " .. tostring(path))
  end

  -- 1. The module loads.
  local chunk, err = load(source, "@setup_wizard_servotype.lua", "t")
  check("1. the servo type module loads", chunk ~= nil, tostring(err))
  if not chunk then return failures - before end
  local stepModule = chunk()

  -- 2. First visit: the default type is applied to the custom group.
  local wiz = newWiz()
  visit(stepModule, wiz)
  local afterFirst = wiz.configs[0].rate
  check("2. the first visit applies the group's first type", afterFirst ~= HAND_RATE and wiz.edits > 0,
    "rate=" .. tostring(afterFirst) .. " edits=" .. wiz.edits)

  -- 3. The pilot sets a rate by hand; the next visit in the same wizard keeps it.
  for servo = 0, 2 do wiz.configs[servo].rate = HAND_RATE end
  local editsBefore = wiz.edits
  visit(stepModule, wiz)
  check("3. a hand-set rate is kept on the next visit", wiz.configs[0].rate == HAND_RATE
    and wiz.edits == editsBefore, "rate=" .. tostring(wiz.configs[0].rate) .. " edits=" .. (wiz.edits - editsBefore))

  -- 4. A new wizard session applies the default again.
  local wiz2 = newWiz()
  visit(stepModule, wiz2)
  check("4. a new wizard session applies the default again", wiz2.configs[0].rate ~= HAND_RATE)

  return failures - before
end

local source = readFile(STEP)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  servo type: default type once per wizard, a hand-set rate is kept on later visits (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- Forget the applied groups on every visit, as before the fix.
local mutated, n = source:gsub("    if not openedStore%[wiz%] then openedStore%[wiz%] = {} end\n",
  "    openedStore[wiz] = {}\n")
if n ~= 1 then
  print("FAIL  self-test: the store line was not found once; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = run(mutated)
if caught > 0 then
  print("ok    mutant red: the default is applied on every visit (" .. caught .. " failed checks)")
  print("OK  self-test: forgetting the applied groups goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: forgetting the applied groups")
os.exit(1)
