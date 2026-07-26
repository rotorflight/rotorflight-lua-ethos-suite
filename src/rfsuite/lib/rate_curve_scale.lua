-- Per-rates_type display scaling for MSP_RC_TUNING's three "curve shape"
-- fields per axis: rcRates_N (RC Rate), rcExpo_N (RC Expo), rates_N
-- ("Super Rate"/"Max Rate"/"Shape", depending on rates_type). All three
-- wire fields are reused unchanged across every rate table (Betaflight/
-- Raceflight/Kiss/Actual/Quick/Rotorflight) -- only how a human-friendly
-- number maps to the raw U8 byte differs per table. Used only by
-- app/pages/rates.lua; lib/msp_rc_tuning.lua itself stays raw-values-only
-- like every other codec (see its own header comment).
--
-- Derived from rotorflight-configurator's own source, not guessed at or
-- ported from rotorflight-lua-ethos-suite's own (considerably more
-- convoluted, decimals+scale+mult-per-field) ratetables/*.lua scheme:
--   1. src/js/msp/MSPHelper.js's MSP_RC_TUNING case shows every one of
--      these 12 fields is ALWAYS decoded as raw/100 at the wire level,
--      regardless of rates_type -- e.g.
--      `FC.RC_TUNING.roll_rc_rate = parseFloat((data.readU8()/100).toFixed(2))`.
--   2. src/js/tabs/rates.js's save-side code then divides that same
--      "universal" (raw/100) value by a further type-specific constant
--      before undoing step 1's /100 to re-encode the wire byte -- e.g.
--      Actual's rc_rate: `FC.RC_TUNING.pitch_rc_rate /= 1000`. Where a
--      type's case has NO such line for a given field at all (e.g.
--      Betaflight never appears in this switch, KISS's rc_rate/expo
--      don't either), the UI's own typed number *is* the universal
--      value directly -- i.e. that's a divisor of 1, not 100 -- confirmed
--      by checking that Betaflight's own rcRateDef (1.20) only reaches
--      the known-correct raw byte 120 when treated as divisor=1
--      (raw = round(1.20 * 100 / 1) = 120), not divisor=100
--      (which would wrongly give raw = round(1.20 * 100/100) = 1).
--
-- Cross-checked field-by-field against every one of
-- rotorflight-lua-ethos-suite's own app/modules/rates/ratetables/*.lua
-- default byte values (reconciling that suite's own decimals+scale+mult
-- chain by hand, not assumed) -- every one matched once reconciled
-- (including ratetables/quick.lua's `rates_4 = {default = 104.16, mult =
-- 4.807}`, which looks like it should encode to raw 500 at a glance, but
-- resolves to raw 104 once that suite's own preSave()-then-
-- saveFieldValue() chain is worked through -- matching this module's own
-- formula computing raw 104 for the same field independently). Also
-- round-trip-verified in isolation (every raw byte 0-255, every type,
-- every role/axis-class combination converts to a displayed integer and
-- back to the exact same raw byte, with zero mismatches) before this was
-- ever put in front of Ethos.
--
-- The relationship: given a raw wire byte (0-255) and the divisor for
-- the active rates_type/role/axis-class, the *true* human-friendly value
-- is `raw * divisor / 100` (a real number, e.g. 1.20, 12.5, 240). Ethos's
-- own number-field widget works in an integer domain, showing that
-- integer divided by 10^decimals for the final render -- see
-- DECIMALS_TABLE below for how many decimals each (rates_type, role,
-- axis-class) combination actually needs, and app/pages/rates.lua's own
-- header comment for how it gets to use the *real* decimals instead of a
-- worst-case guess.

if package.loaded["rfsuite.lib.rate_curve_scale"] then
  return package.loaded["rfsuite.lib.rate_curve_scale"]
end

-- rates_type values (matches rotorflight-lua-ethos-suite's own
-- tasks/scheduler/msp/api/RC_TUNING.lua TBL_RATE_TABLE, confirmed
-- against rotorflight-configurator's TABS.rates.RATES_TYPE too -- this
-- rebuild's API >= 12.09 floor is above the {12,0,9} gate that adds
-- ROTORFLIGHT as a 7th entry, so, matching this project's existing "no
-- version branching" rule, all 7 are always valid).
local RATE_TYPE_NONE = 0
local RATE_TYPE_BETAFLIGHT = 1
local RATE_TYPE_RACEFLIGHT = 2
local RATE_TYPE_KISS = 3
local RATE_TYPE_ACTUAL = 4
local RATE_TYPE_QUICK = 5
local RATE_TYPE_ROTORFLIGHT = 6

-- [rates_type] = {rcRate = {main = divisor, col = divisor}, srate = {...}, expo = {...}}
-- "main" = roll/pitch/yaw (axes 1-3, always share one scale); "col" =
-- collective (axis 4, frequently scaled differently). divisor = 1 means
-- rotorflight-configurator's own save-side code has no `/=` line for
-- this field/type at all (the UI's typed number *is* the raw/100
-- universal value directly) -- NOT the same thing as an explicit
-- `/= 100` line (which appears for real, e.g. Raceflight/Rotorflight's
-- srate/expo, and happens to also produce "displayed equals raw" but
-- for a different, explicit reason).
local SCALE_TABLE = {
  [RATE_TYPE_NONE] = {
    rcRate = {main = 1, col = 1},
    srate = {main = 1, col = 1},
    expo = {main = 1, col = 1},
  },
  [RATE_TYPE_BETAFLIGHT] = {
    rcRate = {main = 1, col = 1},
    srate = {main = 1, col = 1},
    expo = {main = 1, col = 1},
  },
  [RATE_TYPE_RACEFLIGHT] = {
    rcRate = {main = 1000, col = 25},
    srate = {main = 100, col = 100},
    expo = {main = 100, col = 100},
  },
  [RATE_TYPE_KISS] = {
    rcRate = {main = 1, col = 1},
    srate = {main = 1, col = 1},
    expo = {main = 1, col = 1},
  },
  [RATE_TYPE_ACTUAL] = {
    rcRate = {main = 1000, col = 25},
    srate = {main = 1000, col = 25},
    expo = {main = 1, col = 1},
  },
  [RATE_TYPE_QUICK] = {
    rcRate = {main = 1, col = 1},
    srate = {main = 1000, col = 480},
    expo = {main = 1, col = 1},
  },
  [RATE_TYPE_ROTORFLIGHT] = {
    rcRate = {main = 500, col = 12.5},
    srate = {main = 100, col = 100},
    expo = {main = 100, col = 100},
  },
}

local rate_curve_scale = {
  RATE_TYPE_NONE = RATE_TYPE_NONE,
  RATE_TYPE_BETAFLIGHT = RATE_TYPE_BETAFLIGHT,
  RATE_TYPE_RACEFLIGHT = RATE_TYPE_RACEFLIGHT,
  RATE_TYPE_KISS = RATE_TYPE_KISS,
  RATE_TYPE_ACTUAL = RATE_TYPE_ACTUAL,
  RATE_TYPE_QUICK = RATE_TYPE_QUICK,
  RATE_TYPE_ROTORFLIGHT = RATE_TYPE_ROTORFLIGHT,
}

-- Human-readable name per rates_type, matching rotorflight-lua-ethos-
-- suite's own TBL_RATE_TABLE labels (tasks/scheduler/msp/api/RC_TUNING.lua).
-- The one place these 7 strings live -- app/pages/rates.lua shows the
-- active table's name below the page title (matching that suite's own
-- rates.lua, which renders formdata.name -- e.g. "Rotorflight" -- at the
-- top-left of its grid), and app/pages/rates_type.lua's picker builds its
-- option list from this same table, so the two can never drift apart.
rate_curve_scale.NAMES = {
  [RATE_TYPE_NONE] = "@i18n(app.modules.rates.tbl_none)@",
  [RATE_TYPE_BETAFLIGHT] = "@i18n(app.modules.rates.tbl_betaflight)@",
  [RATE_TYPE_RACEFLIGHT] = "@i18n(app.modules.rates.tbl_raceflight)@",
  [RATE_TYPE_KISS] = "@i18n(app.modules.rates.tbl_kiss)@",
  [RATE_TYPE_ACTUAL] = "@i18n(app.modules.rates.tbl_actual)@",
  [RATE_TYPE_QUICK] = "@i18n(app.modules.rates.tbl_quick)@",
  [RATE_TYPE_ROTORFLIGHT] = "@i18n(app.modules.rates.tbl_rotorflight)@",
}

-- role: "rcRate" | "srate" | "expo". axisClass: "main" | "col".
-- Falls back to RATE_TYPE_ACTUAL's scale if rateType is nil/unrecognized
-- (e.g. before the first MSP read completes) -- an arbitrary but stable
-- choice, matching firmware's own default rates_type (see
-- lib/msp_rc_tuning.lua's SIMULATOR_RESPONSE comment).
local function scaleFor(rateType, role, axisClass)
  local byType = SCALE_TABLE[rateType] or SCALE_TABLE[RATE_TYPE_ACTUAL]
  return byType[role][axisClass]
end
rate_curve_scale.scaleFor = scaleFor

-- How many decimal places each (rates_type, role, axis-class) actually
-- needs to render without silently losing precision -- e.g. Actual/
-- Raceflight/Rotorflight's main-axis RC Rate is naturally a whole number
-- (decimals=0), while Betaflight/Kiss/Quick Rates' RC Rate needs 2 to
-- show fractional values like 1.20. Ported directly from
-- rotorflight-lua-ethos-suite's own app/modules/rates/ratetables/*.lua --
-- every field there either has an explicit `decimals = N` or, when it
-- doesn't, Ethos's own number field defaults to 0 -- read field-by-field
-- for every one of the 7 tables (e.g. betaflight.lua's uniform
-- `decimals = 2` on all 12 fields; actual.lua's `decimals = 1` only on
-- the two collective fields, decimals = 2 only on the 4 expo fields,
-- everything else defaulting to 0). Cross-checked against
-- rotorflight-configurator's own src/js/tabs/rates.js
-- (rcRateDec/rateDec/rcColDec/colDec/expoDec per RATES_TYPE case) --
-- both independent sources agree on every single entry. RATE_TYPE_NONE
-- is the one deliberate departure from ratetables/none.lua: that file
-- disables every field outright (min=max=0) since firmware treats "no
-- rate table" as nothing to tune, but this rebuild has no per-table
-- field-disable mechanism, so its fields stay editable -- decimals=2
-- (not the source's implied 0) so a divisor of 1 (same as Betaflight/
-- Kiss) still renders without precision loss.
--
-- Round-trip-verified in isolation, same rigor as SCALE_TABLE above:
-- every raw byte 0-255, every type, every role/axis-class combination,
-- converts to a displayed integer and back to the exact same raw byte,
-- zero mismatches -- confirming these reduced decimal counts lose no
-- real precision despite showing fewer digits than a flat 2 would.
local DECIMALS_TABLE = {
  [RATE_TYPE_NONE] = {
    rcRate = {main = 2, col = 2},
    srate = {main = 2, col = 2},
    expo = {main = 2, col = 2},
  },
  [RATE_TYPE_BETAFLIGHT] = {
    rcRate = {main = 2, col = 2},
    srate = {main = 2, col = 2},
    expo = {main = 2, col = 2},
  },
  [RATE_TYPE_RACEFLIGHT] = {
    rcRate = {main = 0, col = 1},
    srate = {main = 0, col = 0},
    expo = {main = 0, col = 0},
  },
  [RATE_TYPE_KISS] = {
    rcRate = {main = 2, col = 2},
    srate = {main = 2, col = 2},
    expo = {main = 2, col = 2},
  },
  [RATE_TYPE_ACTUAL] = {
    rcRate = {main = 0, col = 1},
    srate = {main = 0, col = 1},
    expo = {main = 2, col = 2},
  },
  [RATE_TYPE_QUICK] = {
    rcRate = {main = 2, col = 2},
    srate = {main = 0, col = 0},
    expo = {main = 2, col = 2},
  },
  [RATE_TYPE_ROTORFLIGHT] = {
    rcRate = {main = 0, col = 2},
    srate = {main = 0, col = 0},
    expo = {main = 0, col = 0},
  },
}

local function decimalsFor(rateType, role, axisClass)
  local byType = DECIMALS_TABLE[rateType] or DECIMALS_TABLE[RATE_TYPE_ACTUAL]
  return byType[role][axisClass]
end
rate_curve_scale.decimalsFor = decimalsFor

-- Raw wire byte -> the integer Ethos's own number-field widget should
-- get()/be constructed with (still subject to the widget's own
-- field:decimals(n) call for final cosmetic display -- see
-- decimalsFor() above). displayInt = raw * divisor/100 (the true
-- friendly value) * 10^decimals.
function rate_curve_scale.toDisplayInt(raw, rateType, role, axisClass)
  local divisor = scaleFor(rateType, role, axisClass)
  local scale = 10 ^ decimalsFor(rateType, role, axisClass)
  return math.floor((raw or 0) * divisor / 100 * scale + 0.5)
end

-- The widget's edited integer (already in the same displayInt domain
-- toDisplayInt() produces) -> the raw wire byte to store/send. Clamped
-- to a real U8's range so a stale widget bound (built under a different
-- rates_type's scale, see displayBounds() below) can never produce a
-- value mspcodec.writeU8() would silently wrap via `value % 256` --
-- the clamp only matters in that edge case (edit a field, change
-- rates_type, edit again, all before reloading/reopening the page);
-- ordinary use always stays comfortably inside range.
function rate_curve_scale.fromDisplayInt(displayInt, rateType, role, axisClass)
  local divisor = scaleFor(rateType, role, axisClass)
  local scale = 10 ^ decimalsFor(rateType, role, axisClass)
  local raw = math.floor((displayInt or 0) / scale * 100 / divisor + 0.5)
  if raw < 0 then return 0 end
  if raw > 255 then return 255 end
  return raw
end

-- Display-domain bounds AND decimals for a field's widget. Called twice
-- in practice, both from app/pages/rates.lua (see its own header
-- comment): once at construction with rateType=nil (an unavoidable
-- guess, falls back to RATE_TYPE_ACTUAL -- the real rates_type isn't
-- known until after the first MSP read), and again every time that read
-- succeeds, with the by-then-real rateType, to re-apply the correct
-- bounds/decimals to the already-existing fields via :minimum()/
-- :maximum()/:decimals(). Min is always 0 in every source checked; max
-- is derived from the same divisor the live conversion uses, so it can
-- never drift out of sync with it.
function rate_curve_scale.displayBounds(rateType, role, axisClass)
  return 0, rate_curve_scale.toDisplayInt(255, rateType, role, axisClass), decimalsFor(rateType, role, axisClass)
end

function rate_curve_scale.displayStep(rateType, role, axisClass)
  local step = rate_curve_scale.toDisplayInt(1, rateType, role, axisClass)
  return step > 0 and step or 1
end

package.loaded["rfsuite.lib.rate_curve_scale"] = rate_curve_scale
return rate_curve_scale
