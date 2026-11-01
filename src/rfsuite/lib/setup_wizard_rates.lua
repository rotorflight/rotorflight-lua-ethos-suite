-- Pure helpers for the Setup Wizard's Rates step: the flying styles, how a style
-- is written into an RC_TUNING (MSP_RC_TUNING, Rotorflight rates type), how to
-- tell which style a profile matches, and the curve the rates give. Ported from
-- the Configurator's rates.js and RateCurve.js, so both wizards write the same.
--
-- The rates type is Rotorflight (6). The fields are raw bytes: rcRates_N is the
-- RC rate times 100, rcExpo_N the expo in %, rates_N the curve shape times 100.
-- Axis 1 is roll, 2 pitch, 3 yaw, 4 collective (left as it is: the Blade pitch
-- step sets it).

if package.loaded["rfsuite.lib.setup_wizard_rates"] then
  return package.loaded["rfsuite.lib.setup_wizard_rates"]
end

local M = {}

-- The rates type (fc/rates.h RATES_TYPE_ROTORFLIGHT); the wizard writes only this.
M.ROTORFLIGHT = 6
-- The Rotorflight curve's shape (srate), the firmware default: 12 / 100.
M.SHAPE = 12
-- Rate profiles are selected with MSP_SELECT_SETTING, the profile plus this mask.
M.RATE_PROFILE_MASK = 128
-- The curve's scale, deg/s, the same for every curve so they compare: the largest
-- cyclic rate of the styles (the Configurator's SCALE).
M.MAX_DEG = 400

-- Rates in deg/s at full stick, expo in %. Trainer is slower, 3D faster.
M.STYLES = {
  {key = "trainer", cyclic = 180, yaw = 270, expo = {cyclic = 40, yaw = 50}},
  {key = "sport", cyclic = 250, yaw = 400, expo = {cyclic = 40, yaw = 50}},
  {key = "3d", cyclic = 400, yaw = 600, expo = {cyclic = 30, yaw = 40}},
}

-- The axes the styles set: roll and pitch use the cyclic rates, yaw the yaw rates.
local AXES = {{index = 1, kind = "cyclic"}, {index = 2, kind = "cyclic"}, {index = 3, kind = "yaw"}}

local function round(v)
  return math.floor(v + 0.5)
end

-- A copy of an RC_TUNING table (flat, numbers only).
function M.copy(tuning)
  local out = {}
  for k, v in pairs(tuning) do out[k] = v end
  return out
end

-- The style written into a copy of `tuning`: the rates and expo of the three
-- axes; the shape of each axis; the collective is not touched.
function M.applyStyle(tuning, style)
  local out = M.copy(tuning)
  out.rates_type = M.ROTORFLIGHT
  for _, a in ipairs(AXES) do
    out["rcRates_" .. a.index] = round(style[a.kind] / 5)
    out["rates_" .. a.index] = M.SHAPE
    out["rcExpo_" .. a.index] = style.expo[a.kind]
  end
  return out
end

-- The key of the style the tuning already has, or nil (a custom tuning).
function M.matchingStyle(tuning)
  if not tuning or tuning.rates_type ~= M.ROTORFLIGHT then return nil end
  for _, style in ipairs(M.STYLES) do
    local same = true
    for _, a in ipairs(AXES) do
      if tuning["rcRates_" .. a.index] ~= round(style[a.kind] / 5)
        or tuning["rates_" .. a.index] ~= M.SHAPE
        or tuning["rcExpo_" .. a.index] ~= style.expo[a.kind] then
        same = false
      end
    end
    if same then return style.key end
  end
  return nil
end

-- The style with this key.
function M.styleByKey(key)
  for _, style in ipairs(M.STYLES) do
    if style.key == key then return style end
  end
  return nil
end

-- The angular rate (deg/s) of the axis at a stick position r (-1..1), as the
-- Rotorflight curve gives it: rcRate * 500 * the expo curve.
function M.degPerSecond(tuning, index, r)
  local rcRate = (tuning["rcRates_" .. index] or 0) / 100
  local expo = (tuning["rcExpo_" .. index] or 0) / 100
  local shape = (tuning["rates_" .. index] or M.SHAPE) / 100 / 16 + 2
  local a = math.abs(r)
  local sign = r < 0 and -1 or 1
  local expof = r * (1 - expo) + sign * (a ^ shape) * expo
  return 500 * rcRate * expof
end

-- The full-stick rates of roll (cyclic) and yaw, deg/s.
function M.fullStick(tuning)
  return round(M.degPerSecond(tuning, 1, 1)), round(M.degPerSecond(tuning, 3, 1))
end

-- The collective pitch at full stick, degrees (the Configurator's
-- collectiveAtFullStick() for the Rotorflight type: the rate / 100 times 12.5).
M.COLLECTIVE_DEG = 12.5
function M.collectiveFullStick(tuning)
  local raw = tuning.rcRates_4 or 0
  return math.floor(raw / 100 * M.COLLECTIVE_DEG * 10 + 0.5) / 10
end

package.loaded["rfsuite.lib.setup_wizard_rates"] = M
return M
