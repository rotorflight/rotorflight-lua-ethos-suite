-- The Setup Wizard's art module (src/rfsuite/app/setup_wizard_art.lua) must not
-- load lib/heli3d.lua when it is loaded itself.
--
-- The wizard loads the art module when it opens (app/pages/setup_wizard.lua and
-- app/setup_wizard_ui.lua require it at the top). The solid helicopter of
-- lib/heli3d.lua (~35 kB of source) is drawn on one screen only: the
-- orientation check of the Sensors step, which the step does not open on
-- (setup_wizard_sensors.lua starts on "intro"). Loaded with the art module, it
-- sat on the heap from the first frame of the wizard, and opening the wizard
-- stopped Lua with "Lua has used too much RAM, it has been killed" in the
-- Ethos simulator.
--
-- Checked here, with lib/heli3d.lua replaced by a counting stub:
--   1. loading the art module loads no lib/heli3d.lua;
--   2. art.service() and art.draw() for the wire style load none either;
--   3. the first art.service() of the solid style loads it, once, and runs its
--      service; the first art.draw() of a valid solid attitude draws with it;
--   4. later calls load it no second time.
-- The same checks then run against a copy of the module that loads
-- lib/heli3d.lua at the top again, and that copy has to fail them, so this
-- script can go red.
--
-- Run from the repository root: lua5.4 bin/setup_wizard_art_load/verify_setup_wizard_art_load.lua

local ART = "src/rfsuite/app/setup_wizard_art.lua"
local HELI = "lib/heli3d.lua"

local function readAll(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return s
end

-- Ethos globals the solid attitude's paint touches before it hands over.
lcd = {
  font = function() end,
  getTextSize = function() return 10, 12 end,
  color = function() end,
  drawText = function() end,
}
FONT_S = FONT_S or 0
LEFT = LEFT or 0

-- Loads one copy of the module with a counting stand-in for lib/heli3d.lua and
-- returns the list of failed checks (empty when all pass).
local function check(source, chunkName)
  local failures = {}
  local function expect(ok, what)
    if not ok then failures[#failures + 1] = what end
  end

  local loads = 0
  local calls = { service = 0, setup = 0, pose = 0, draw = 0 }
  local stub = {}
  for name in pairs(calls) do
    stub[name] = function() calls[name] = calls[name] + 1 end
  end

  local savedRequire = package.loaded["rfsuite.lib.require"]
  package.loaded["rfsuite.lib.require"] = function(path)
    if path == HELI then
      loads = loads + 1
      return stub
    end
    return {}
  end
  package.loaded["rfsuite.app.setup_wizard_art"] = nil
  local chunk = assert(load(source, "@" .. chunkName, "t"))
  local ok, art = pcall(chunk)
  package.loaded["rfsuite.lib.require"] = savedRequire
  package.loaded["rfsuite.app.setup_wizard_art"] = nil
  if not ok then
    failures[#failures + 1] = "module did not load: " .. tostring(art)
    return failures
  end

  -- 1. Loading the module.
  expect(loads == 0, "loading the art module loaded " .. HELI .. " " .. loads .. " time(s), expected 0")

  -- 2. The wire style never needs the solid model.
  local wire = art.attitude({ valid = true, roll = 0, pitch = 0, yaw = 0 }, "wire")
  art.service(wire)
  art.draw(art.attitude({ valid = false }, "wire"), 0, 0, 200, 120, {})
  expect(loads == 0, "the wire attitude loaded " .. HELI .. ", expected no load")

  -- 3. The solid style loads it on first use and uses it.
  local solid = art.attitude({ valid = true, roll = 1, pitch = 2, yaw = 3 })
  art.service(solid)
  expect(loads == 1, "the first solid art.service() loaded " .. HELI .. " " .. loads .. " time(s), expected 1")
  expect(calls.service == 1, "art.service() ran the model's service " .. calls.service .. " time(s), expected 1")
  art.draw(solid, 0, 0, 200, 120, { text = 1, muted = 2 })
  expect(calls.draw == 1, "art.draw() of a valid solid attitude drew the model " .. calls.draw .. " time(s), expected 1")

  -- 4. Memoised: no second load.
  art.service(solid)
  art.draw(solid, 0, 0, 200, 120, { text = 1, muted = 2 })
  expect(loads == 1, "repeated use loaded " .. HELI .. " " .. loads .. " time(s), expected 1")

  return failures
end

local source = readAll(ART)

local failures = check(source, "setup_wizard_art.lua")
for _, f in ipairs(failures) do print("FAIL  " .. f) end

-- Negative control: the module as it was, with the require at the top.
local eager, n = source:gsub("local heli3d(\r?\n)", 'local heli3d = requireModule("' .. HELI .. '")%1', 1)
local controlOk = false
if n ~= 1 then
  print("FAIL  negative control: 'local heli3d' declaration not found in " .. ART .. "; update this harness")
else
  local controlFailures = check(eager, "setup_wizard_art.eager.lua")
  controlOk = #controlFailures > 0
  if not controlOk then
    print("FAIL  negative control: an art module that loads " .. HELI .. " at the top passed the checks")
  end
end

if #failures == 0 and controlOk then
  print("OK  setup_wizard_art.lua loads " .. HELI .. " only on first use (the eager copy is caught)")
  os.exit(0)
end
os.exit(1)
