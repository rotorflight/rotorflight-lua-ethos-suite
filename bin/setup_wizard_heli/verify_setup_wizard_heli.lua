-- The Setup Wizard's helicopter rules (src/rfsuite/lib/setup_wizard_heli.lua)
-- against the numbers rotorflight-configurator's src/tabs/setup_wizard/heli.js
-- produces for the same input.
--
--     lua5.4 bin/setup_wizard_heli/verify_setup_wizard_heli.lua [repo root]
--     lua5.4 bin/setup_wizard_heli/verify_setup_wizard_heli.lua --self-test
--
-- --self-test runs the same checks against a copy of the module whose pitch
-- calibration ignores the measurement, and requires them to fail.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  local last = 0
  for i = 1, #path do
    local ch = path:sub(i, i)
    if ch == "/" or ch == string.char(92) then last = i end
  end
  if last == 0 then return "." end
  return path:sub(1, last - 1)
end

local selfTest = false
local root = scriptDir() .. "/../.."
for i = 1, #(arg or {}) do
  if arg[i] == "--self-test" then selfTest = true else root = arg[i] end
end

local function load()
  package.loaded["rfsuite.lib.setup_wizard_heli"] = nil
  return dofile(root .. "/src/rfsuite/lib/setup_wizard_heli.lua")
end

local function run(M)
  local failures = 0
  local function check(name, got, want)
    if got ~= want then
      failures = failures + 1
      print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
  end

  -- Override units.
  check("swashRaw(9)", M.swashRaw(9), 750)
  check("tailRaw(22)", M.tailRaw(22), 917)
  check("tailRaw(60)", M.tailRaw(60), 2500)
  check("servoRaw(20)", M.servoRaw(20), 400)
  check("limitRaw(12)", M.limitRaw(12), 1000)
  check("limitRaw(60, tail)", M.limitRaw(60, true), 2500)
  check("limitDegrees(1000)", M.limitDegrees(1000), 12)
  check("limitDegrees(-833)", M.limitDegrees(-833), 9.996)
  check("tailTrimDegrees(417)", M.tailTrimDegrees(417), 10)
  check("tailTrimRaw(10)", M.tailTrimRaw(10), 417)
  check("signed16(65286)", M.signed16(65286), -250)
  check("signed16(250)", M.signed16(250), 250)

  -- Pitch calibration keeps the sign and the 200..2000 range.
  check("calibrated 9/12", M.calibratedRate(1000, 9, 12), 750)
  check("calibrated sign", M.calibratedRate(-1000, 9, 6), -1500)
  check("calibrated clamp hi", M.calibratedRate(1800, 9, 4), 2000)
  check("calibrated clamp lo", M.calibratedRate(300, 9, 20), 200)
  check("calibrated no measurement", M.calibratedRate(1000, 9, 0), 1000)

  -- Servos per swash type, with and without a servo tail.
  local s = M.wizardServos(2, M.TAIL_VARIABLE, 4)
  check("120 servo count", #s, 4)
  check("120 tail servo", s[4].servo, 3)
  check("120 tail role", s[4].role, "tail")
  check("120 left angle", s[2].angle, -120)
  s = M.wizardServos(6, M.TAIL_MOTORIZED, 2)
  check("90V motor tail count", #s, 2)
  check("90V front right", s[2].role, "front_right")
  s = M.wizardServos(4, M.TAIL_VARIABLE, 3)
  check("missing tail servo", s[4].missing, true)
  check("present servo", s[3].missing, false)
  check("no swash", #M.wizardServos(0, M.TAIL_MOTORIZED, 8), 0)
  check("pwm count plain", M.pwmServoCount(4), 4)
  check("pwm count with bus", M.pwmServoCount(22), 4)

  -- Servo types.
  local cfg = {mid = 1520, min = -700, max = 700, rneg = 500, rpos = 500, rate = 50}
  check("type analog", M.servoTypeOf(cfg), "analog")
  check("narrow rate change", M.applyServoType(cfg, "narrow"), true)
  check("narrow mid", cfg.mid, 760)
  check("narrow max", cfg.max, 250)
  check("narrow scale", cfg.rpos, 250)
  check("type narrow", M.servoTypeOf(cfg), "narrow")
  check("same rate", M.applyServoType(cfg, "narrow"), false)

  -- Receiver detection.
  check("moved clear", M.moved({10, 420, 30, 5}, nil, 300), 2)
  check("moved too small", M.moved({10, 200, 30, 5}, nil, 300), nil)
  check("moved ambiguous", M.moved({10, 420, 300, 5}, nil, 300), nil)
  check("moved excluded", M.moved({10, 420, 330, 5}, {[2] = true}, 300), 3)
  local map = M.mapFromDetected({[4] = 2, [1] = 0, [2] = 1, [3] = 3, [5] = 5})
  check("detected elrs", M.presetOf(map), "elrs")
  check("detected aux1", map[6], 4)
  check("preset none", M.presetOf({7, 6, 5, 4, 3, 2, 1, 0}), nil)
  local lo, hi = M.throttleEnds({rc_center = 1500, rc_deflection = 510, rc_min_throttle = 0, rc_max_throttle = 0})
  check("throttle zero", lo, 1041)
  check("throttle full", hi, 1959)
  local a, b = M.throttleFromMeasured(1000, 2000)
  check("measured min", a, 1020)
  check("measured max", b, 1980)
  check("measured short", M.throttleFromMeasured(1400, 1600), nil)

  return failures
end

if selfTest then
  local broken = load()
  broken.calibratedRate = function(rate) return rate end
  local failures = run(broken)
  if failures == 0 then
    print("self-test: the broken module passed, so the checks cannot go red")
    os.exit(1)
  end
  print(string.format("self-test: %d check(s) failed against the broken module, as they must", failures))
  os.exit(0)
end

local failures = run(load())
if failures > 0 then
  print(string.format("%d check(s) failed", failures))
  os.exit(1)
end
print("setup_wizard_heli: all checks passed")
os.exit(0)
