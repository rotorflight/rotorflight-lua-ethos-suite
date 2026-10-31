-- Pure helpers for the Setup Wizard's Profiles & gain step: the adjustment
-- ranges it writes (rotorflight-firmware fc/rc_adjustments.c) and reading them
-- back. Ported from the Configurator's adjust.js, so both wizards write the same.
--
-- The step fits an 8-channel link: CH1-5 are roll, pitch, yaw, collective and
-- throttle, which leaves AUX1-3 (CH6-8) for ARM, the profile switch and
-- Rescue/Trainer. Master gain in flight takes the trim buttons or a knob on a
-- channel of its own.

if package.loaded["rfsuite.lib.setup_wizard_adjust"] then
  return package.loaded["rfsuite.lib.setup_wizard_adjust"]
end

local M = {}

-- Enable channel meaning "always on".
M.ALWAYS_ON_CH = 255
-- Roll, pitch, yaw, collective and throttle come before AUX1.
M.CONTROL_CHANNELS = 5
-- AUX channels that fit an 8-channel link.
M.AUX_IN_8_CHANNELS = 3

-- Adjustment functions (fc/rc_adjustments.h).
M.ADJ = {
  RATE_PROFILE = 1,
  PID_PROFILE = 2,
  CYCLIC_MASTER_GAIN = 83,
  YAW_MASTER_GAIN = 84,
}

-- MASTER_GAIN_MIN / MAX (flight/pid.h), in %.
M.GAIN_MIN = 25
M.GAIN_MAX = 200
-- A knob covers 50-150 %, centred on 100 %.
M.KNOB_MIN = 50
M.KNOB_MAX = 150
-- Each trim button press, in %.
M.GAIN_STEP = 5

-- The most positions a profile switch may have: profiles 1-3.
M.MAX_PROFILE_POSITIONS = 3

-- Recorded channel values closer than this (us) are one switch position.
local CLUSTER_US = 150

-- Ranges are stored in 5 us steps between 875 and 2125 us.
local function toStep(us)
  return math.max(875, math.min(2125, math.floor(us / 5 + 0.5) * 5))
end

-- An always-on, mapped range: the position of AUX channel `aux` is the value,
-- from `min` at `low` us to `max` at `high` us.
function M.mappedRange(adjFunction, aux, low, high, min, max)
  return {
    adjFunction = adjFunction,
    enaChannel = M.ALWAYS_ON_CH,
    enaRange = {start = 1500, ["end"] = 1500},
    adjChannel = aux,
    adjRange1 = {start = toStep(low), ["end"] = toStep(high)},
    adjRange2 = {start = 1500, ["end"] = 1500},
    adjMin = min,
    adjMax = max,
    adjStep = 0,
  }
end

-- Distinct switch positions in recorded values (us), sorted by value, as
-- {low, high, centre}.
function M.switchPositions(samples)
  local sorted = {}
  for _, v in ipairs(samples) do
    if v and v > 0 then sorted[#sorted + 1] = v end
  end
  table.sort(sorted)
  local positions = {}
  for _, value in ipairs(sorted) do
    local last = positions[#positions]
    if last and value - last.high < CLUSTER_US then
      last.high = value
    else
      positions[#positions + 1] = {low = value, high = value}
    end
  end
  for _, p in ipairs(positions) do p.centre = (p.low + p.high) / 2 end
  return positions
end

-- A profile range over the switch's real travel: its lowest position is
-- profile 1, its highest `count`.
function M.profileRange(adjFunction, aux, positions)
  local count = math.min(#positions, M.MAX_PROFILE_POSITIONS)
  local low = positions[1].centre
  local high = positions[#positions].centre
  return M.mappedRange(adjFunction, aux, low, high, 1, count)
end

-- The knob: 975..2025 us, so a radio's full travel reaches both ends.
function M.knobRange(adjFunction, aux)
  return M.mappedRange(adjFunction, aux, 975, 2025, M.KNOB_MIN, M.KNOB_MAX)
end

-- Trim buttons on one spare channel (a Free mix, source Maximum, per button a
-- weight). Each button puts its own value on the channel; a stepped range per
-- direction tells them apart. The buttons match the Ethos guide: elevator trim
-- for cyclic, rudder trim for yaw.
M.GAIN_BUTTONS = {
  {key = "cyclicDown", adjFunction = 83, dir = -1, weight = 30},
  {key = "cyclicUp", adjFunction = 83, dir = 1, weight = 40},
  {key = "yawDown", adjFunction = 84, dir = -1, weight = 50},
  {key = "yawUp", adjFunction = 84, dir = 1, weight = 60},
}

-- Channel value for a Maximum source at `weight` %: 100 % is 1500 + 512 us.
function M.buttonValue(weight)
  return 1500 + weight * 5.12
end

-- The channel window of button `index`: half-way to each neighbour, so the
-- windows meet without overlapping. The ends use the same half gap outward.
function M.buttonWindow(index)
  local values = {}
  for i, b in ipairs(M.GAIN_BUTTONS) do values[i] = M.buttonValue(b.weight) end
  local value = values[index]
  local below = index > 1 and values[index - 1] or (2 * value - values[index + 1])
  local above = index < #values and values[index + 1] or (2 * value - values[index - 1])
  return {start = toStep((below + value) / 2), ["end"] = toStep((value + above) / 2)}
end

-- The button the channel is showing at `position` (us), or nil.
function M.buttonAt(position)
  if not position or position <= 0 then return nil end
  for i, b in ipairs(M.GAIN_BUTTONS) do
    local w = M.buttonWindow(i)
    if position >= w.start and position < w["end"] then return b end
  end
  return nil
end

-- The stepped range for master gain `adjFunction` on AUX channel `aux`: the
-- down button's window steps down, the up button's window steps up.
function M.steppedGainRange(adjFunction, aux)
  local down, up
  for i, b in ipairs(M.GAIN_BUTTONS) do
    if b.adjFunction == adjFunction and b.dir == -1 then down = i end
    if b.adjFunction == adjFunction and b.dir == 1 then up = i end
  end
  return {
    adjFunction = adjFunction,
    enaChannel = M.ALWAYS_ON_CH,
    enaRange = {start = 1500, ["end"] = 1500},
    adjChannel = aux,
    adjRange1 = M.buttonWindow(down),
    adjRange2 = M.buttonWindow(up),
    adjMin = M.GAIN_MIN,
    adjMax = M.GAIN_MAX,
    adjStep = M.GAIN_STEP,
  }
end

-- The slot holding `adjFunction`, else the first free one (adjFunction 0), else nil.
function M.slotFor(ranges, adjFunction)
  for i = 1, #ranges do
    if ranges[i] and ranges[i].adjFunction == adjFunction then return i end
  end
  for i = 1, #ranges do
    if not ranges[i] or ranges[i].adjFunction == 0 then return i end
  end
  return nil
end

-- The range for `adjFunction`, or nil.
function M.rangeOf(ranges, adjFunction)
  for i = 1, #ranges do
    if ranges[i] and ranges[i].adjFunction == adjFunction then return ranges[i] end
  end
  return nil
end

-- The AUX channel driving `adjFunction`, or nil.
function M.channelOf(ranges, adjFunction)
  local r = M.rangeOf(ranges, adjFunction)
  return r and r.adjChannel or nil
end

-- The value a mapped range gives at a channel position (us), as the firmware
-- computes it (processRcAdjustments, continuous adjustment).
function M.mappedValue(range, position)
  local width = range.adjRange1["end"] - range.adjRange1.start
  local span = range.adjMax - range.adjMin
  if not (width > 0) or not (span > 0) then return range.adjMin end
  local value = range.adjMin
    + math.floor(((position - range.adjRange1.start) * span + width / 2) / width)
  return math.max(range.adjMin, math.min(range.adjMax, value))
end

-- How the profile switch is set up: "both" (PID and rate on one channel),
-- "pid", or "none".
function M.profileMode(ranges)
  local pid = M.channelOf(ranges, M.ADJ.PID_PROFILE)
  if pid == nil then return "none" end
  if M.channelOf(ranges, M.ADJ.RATE_PROFILE) == pid then return "both" end
  return "pid"
end

-- How master gain is adjusted in flight: "buttons" (stepped), "knob" or "none".
function M.gainMode(ranges)
  local r = M.rangeOf(ranges, M.ADJ.CYCLIC_MASTER_GAIN)
  if not r then return "none" end
  return r.adjStep > 0 and "buttons" or "knob"
end

package.loaded["rfsuite.lib.setup_wizard_adjust"] = M
return M
