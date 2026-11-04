-- Behaviour check for #2702: the Setup Wizard's governor step leads on to the headspeed screen only for
-- Electric and Nitro, and keeps the throttle type visible for every governor mode.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_governor_screens/verify_setup_wizard_governor_screens.lua
--     lua5.4 bin/setup_wizard_governor_screens/verify_setup_wizard_governor_screens.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_governor.lua, with the UI, art and MSP
-- modules replaced by stubs and the governor config held by a wizard stand-in. For each mode it opens
-- the step, passes the safety card and reads the mode screen. It pins:
--   1. Off: no throttle row and no way on to the headspeed screen;
--   2. Limit and Direct: the throttle row is shown (Direct reads the type: governor.c govDataUpdate),
--      and there is no way on to the headspeed screen (neither mode holds a headspeed);
--   3. Electric and Nitro: the throttle row is shown and the way on leads to the headspeed screen.
--
-- --self-test runs the same checks on two broken copies (the headspeed screen offered for every mode;
-- the throttle row hidden below Electric) and requires both to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local STEP = ROOT .. "/src/rfsuite/app/pages/setup_wizard_governor.lua"

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

local ROW_THROTTLE = "@i18n(app.modules.setup_wizard.gov_throttle)@"
local MODES = {[0] = "Off", [1] = "Limit", [2] = "Direct", [3] = "Electric", [4] = "Nitro"}

local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end

-- A recording screen: the rows, the safety card's Start and the way forward of the last row().
local holder = {}
local function newScreen()
  local s = {rows = nil, start = nil, forward = nil}
  holder.screen = s
  function s.begin() s.rows, s.start, s.forward = nil, nil, nil end
  function s.checks(_, rows) s.rows = rows; return {} end
  function s.row(_, _, _, forward) s.forward = forward; return {} end
  function s.safety(_, _, _, _, startPress) s.start = startPress; return {} end
  return setmetatable(s, { __index = function() return function() return {} end end })
end

local function newWiz(mode)
  local wiz = {}
  function wiz.governorMode() return mode end
  function wiz.governorConfig() return {gov_mode = mode, gov_throttle_type = 0} end
  function wiz.rebuild() end
  return setmetatable(wiz, { __index = function() return function() end end })
end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

-- The label the step uses for the throttle row, read from the module's own T table.
local function throttleLabel(source)
  local key = source:match('rowThrottle = "(@i18n%([^)]+%)@)"')
  return key or ROW_THROTTLE
end

local function run(source)
  local before = failures
  package.loaded["rfsuite.lib.require"] = function(path)
    if path == "app/setup_wizard_ui.lua" then return {new = function() return newScreen() end} end
    if path == "app/setup_wizard_art.lua" then
      return setmetatable({}, {__index = function() return function() return anyObject() end end})
    end
    return anyObject()    -- the MSP codecs: the mode screen reads none of them
  end
  local stepModule = assert(load(source, "@setup_wizard_governor.lua", "t"))()
  local label = throttleLabel(source)

  for mode = 0, 4 do
    local node = stepModule.new(newWiz(mode))
    node.build()
    local scr = holder.screen
    local start = rawget(scr, "start")
    if start then start() end
    node.build()
    local hasThrottle = false
    -- rawget: the stub's metatable answers every missing field with a function.
    for _, r in ipairs(rawget(scr, "rows") or {}) do if r.label == label then hasThrottle = true end end
    local onward = rawget(scr, "forward") ~= nil
    local name = MODES[mode]
    if mode == 0 then
      check(name .. ": no throttle row", not hasThrottle)
      check(name .. ": no way on to the headspeed screen", not onward)
    elseif mode <= 2 then
      check(name .. ": the throttle row is shown", hasThrottle)
      check(name .. ": no way on to the headspeed screen", not onward)
    else
      check(name .. ": the throttle row is shown", hasThrottle)
      check(name .. ": the way on leads to the headspeed screen", onward)
    end
  end
  return failures - before
end

local source = readFile(STEP)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  governor step: headspeed only for Electric and Nitro, throttle type for every governor mode (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

local mutants = {
  {name = "headspeed screen offered for every mode",
   from = "    local forward = nil\n(%s*%-%-[^\n]*\n%s*%-%-[^\n]*\n)    if mode >= 3 then\n",
   to = "    local forward = nil\n%1    if mode > 0 then\n"},
  {name = "throttle row hidden below Electric",
   from = "(%-%- so a stored type must stay visible and changeable there%.\n)    if mode > 0 then\n",
   to = "%1    if mode >= 3 then\n"},
}
local red = 0
for _, m in ipairs(mutants) do
  local mutated, n = source:gsub(m.from, m.to, 1)
  if n ~= 1 then
    print("FAIL  self-test: the lines for '" .. m.name .. "' were not found once; update this harness")
    os.exit(1)
  end
  failures, checks = 0, 0
  local caught = run(mutated)
  if caught > 0 then
    red = red + 1
    print("ok    mutant red: " .. m.name .. " (" .. caught .. " failed checks)")
  else
    print("FAIL  mutant passed the checks: " .. m.name)
  end
end
if red == #mutants then
  print("OK  self-test: both broken copies go red")
  os.exit(0)
end
os.exit(1)
