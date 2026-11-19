-- Range check for Governor > Ramp Time "Tracking time" and "Recovery time", and
-- Governor > General "Handover throttle%".
--
-- Run it from the repository root:
--     lua5.4 bin/governor_ramp_handover_ranges/verify_governor_ramp_handover_ranges.lua
--
-- The firmware (src/main/cli/settings.c, API 12.09 and later, the suite's floor):
--   gov_tracking_time      VAR_UINT16 {0, 600}, tenths of a second, default 50
--   gov_recovery_time      VAR_UINT16 {0, 600}, tenths of a second, default 30
--   gov_handover_throttle  VAR_UINT8  {10, 100}, percent, default 25
--                          (governor.c also constrains it to 10..100 at init)
-- Defaults are from src/main/pg/governor.c. The Configurator's 12.9 pages use the
-- same ranges (0 - 60 s, 10% - 100%). The field's FIELD_META must match, as it is
-- what the number field offers and what its reset-to-default restores.

-- The module loads its codec helper through this; the range check needs none of it.
package.loaded["rfsuite.lib.require"] = function() return {} end

local chunk = assert(loadfile("src/rfsuite/lib/msp_governor_config.lua"))
local meta = chunk().FIELD_META
local failures = 0

local function check(label, expected, actual)
  if expected == actual then
    print("PASS " .. label)
  else
    failures = failures + 1
    print(string.format("FAIL %s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local EXPECTED = {
  {"gov_tracking_time", 0, 600, 50, 1},
  {"gov_recovery_time", 0, 600, 30, 1},
  {"gov_handover_throttle", 10, 100, 25, nil},
}

for _, e in ipairs(EXPECTED) do
  local key, m = e[1], meta[e[1]]
  check(key .. " min", e[2], m.min)
  check(key .. " max", e[3], m.max)
  check(key .. " default", e[4], m.default)
  check(key .. " decimals", e[5], m.decimals)
end

if failures > 0 then
  print(string.format("%d check(s) failed", failures))
  os.exit(1)
end
print("all checks passed")
