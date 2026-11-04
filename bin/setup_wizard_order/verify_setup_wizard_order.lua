-- Check for #2703: the Setup Wizard's Motor & ESC step comes before the Connect gate, and the
-- ESC telemetry step after it, and the wizard docs number the steps the same way.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_order/verify_setup_wizard_order.lua
--     lua5.4 bin/setup_wizard_order/verify_setup_wizard_order.lua --self-test
--
-- The step list is a local table in src/rfsuite/app/pages/setup_wizard.lua, so this reads its
-- keys in order. It pins:
--   1. motor comes before connect, connect is a gate, and esctelemetry is a gate after it;
--   2. the step numbers in the docs (Step N of the Model setup wizard) are the positions in that list;
--   3. the wizard's overview states the same numbers for the Connect step.
--
-- --self-test puts Connect back in front of Motor and requires check 1 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

-- The step list: keys in order, with their gate flag.
local function stepList(source)
  local body = source:match("local STEPS = {(.-)\n}")
  assert(body, "could not find the STEPS table in setup_wizard.lua")
  local steps = {}
  for line in body:gmatch("[^\n]+") do
    local key = line:match('{key = "(%w+)"')
    if key then
      steps[#steps + 1] = { key = key, gate = line:find("gate = true", 1, true) ~= nil }
    end
  end
  return steps
end

local function indexOf(steps, key)
  for i, s in ipairs(steps) do if s.key == key then return i, s end end
  return nil
end

local function run(wizardSource)
  local before = failures
  local steps = stepList(wizardSource)
  local iMotor = indexOf(steps, "motor")
  local iConnect, sConnect = indexOf(steps, "connect")
  local iTel, sTel = indexOf(steps, "esctelemetry")

  check("the motor step is in the list", iMotor ~= nil)
  check("the connect step is in the list", iConnect ~= nil)
  check("the ESC telemetry step is in the list", iTel ~= nil)
  if not (iMotor and iConnect and iTel) then return failures - before end

  check("motor comes before connect", iMotor < iConnect, "motor=" .. iMotor .. " connect=" .. iConnect)
  check("connect is the gate", sConnect.gate == true)
  check("ESC telemetry comes after connect", iTel > iConnect, "connect=" .. iConnect .. " telemetry=" .. iTel)
  check("ESC telemetry is a gate", sTel.gate == true)
  return failures - before
end

local function runDocs()
  local before = failures
  local steps = stepList(readFile(ROOT .. "/src/rfsuite/app/pages/setup_wizard.lua"))
  local function docStep(path)
    local text = readFile(ROOT .. "/docs/pages/wizards/setup_wizard/" .. path)
    return tonumber(text:match("Step (%d+) of the Model setup wizard"))
  end
  local iMotor = indexOf(steps, "motor")
  local iConnect = indexOf(steps, "connect")
  local iTel = indexOf(steps, "esctelemetry")
  check("motor.md gives the position of Motor & ESC", docStep("motor.md") == iMotor,
    "doc=" .. tostring(docStep("motor.md")) .. " list=" .. tostring(iMotor))
  check("connect.md gives the position of Connect servos", docStep("connect.md") == iConnect,
    "doc=" .. tostring(docStep("connect.md")) .. " list=" .. tostring(iConnect))
  check("esctelemetry.md gives the position of ESC telemetry", docStep("esctelemetry.md") == iTel,
    "doc=" .. tostring(docStep("esctelemetry.md")) .. " list=" .. tostring(iTel))
  local overview = readFile(ROOT .. "/docs/pages/wizards/setup_wizard.md")
  check("the overview names Connect servos at its position",
    overview:find("Connect servos (step " .. tostring(iConnect) .. ")", 1, true) ~= nil)
  return failures - before
end

local wizard = readFile(ROOT .. "/src/rfsuite/app/pages/setup_wizard.lua")

if not SELF_TEST then
  local n = run(wizard) + runDocs()
  if n == 0 then
    print("OK  wizard order: motor, connect gate, ESC telemetry; docs number them the same (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- Connect back in front of Motor: swap the two lines in the list.
local motorLine = '  {key = "motor", title = "@i18n(app.modules.setup_wizard.step_motor)@"},\n'
local connectLine = '  {key = "connect", title = "@i18n(app.modules.setup_wizard.step_connect)@", gate = true},\n'
local oldOrder = connectLine .. motorLine
local s1, c1 = wizard:gsub(motorLine:gsub("%p", "%%%0") .. connectLine:gsub("%p", "%%%0"),
  (oldOrder:gsub("%%", "%%%%")))
if c1 ~= 1 then
  print("FAIL  self-test: the two step lines were not found once; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = run(s1)
if caught > 0 then
  print("ok    mutant red: connect before motor (" .. caught .. " failed checks)")
  print("OK  self-test: the old order goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: connect before motor")
os.exit(1)
