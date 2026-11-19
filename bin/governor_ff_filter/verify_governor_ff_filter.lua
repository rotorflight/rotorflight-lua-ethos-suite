-- Range check for the Governor > Filters "Precomp Bandwidth" field (#2783).
--
-- Run it from the repository root:
--     lua bin/governor_ff_filter/verify_governor_ff_filter.lua
--
-- The firmware (src/main/cli/settings.c, gov_ff_filter, VAR_UINT8, {0, 250})
-- accepts 0..250 and uses the value as a cutoff in Hz. The field's FIELD_META
-- must allow the same range, as the other filter cutoffs in the table do.

-- The module loads its codec helper through this; the range check needs none of it.
package.loaded["rfsuite.lib.require"] = function() return {} end

local chunk = assert(loadfile("src/rfsuite/lib/msp_governor_config.lua"))
local config = chunk()

local meta = config.FIELD_META.gov_ff_filter
local failures = 0

local function check(label, expected, actual)
  if expected == actual then
    print("PASS " .. label)
  else
    failures = failures + 1
    print(string.format("FAIL %s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

check("gov_ff_filter min", 0, meta.min)
check("gov_ff_filter max", 250, meta.max)
check("gov_ff_filter default", 10, meta.default)

if failures > 0 then
  print(string.format("%d check(s) failed", failures))
  os.exit(1)
end
print("all checks passed")
