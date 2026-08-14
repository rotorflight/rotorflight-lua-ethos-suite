-- Schema + message-builders for the MSP_RC_TUNING / MSP_SET_RC_TUNING
-- command pair (cmd 111 read / 204 write).
--
-- Field order/types confirmed directly against rotorflight-firmware's
-- actual wire serializer (src/main/msp/msp.c's MSP_RC_TUNING/
-- MSP_SET_RC_TUNING cases): unlike lib/msp_pid_profile.lua/
-- lib/msp_governor_profile.lua, firmware here reads/writes in exactly
-- the same order as the wire, grouped axis-by-axis (all 5 fields of
-- axis 1, then axis 2, etc.) -- no "wire order differs from struct
-- order" caveat needed. Matches rotorflight-lua-ethos-suite's own
-- tasks/scheduler/msp/api/RC_TUNING.lua FIELD_SPEC exactly. NOT uniform
-- width: every field is U8 except accel_limit_1..4, which are U16.
--
-- `setpoint_boost_gain/cutoff_*`, `yaw_dynamic_*` only exist on the wire
-- as of API 12.0.8; `cyclic_ring`/`cyclic_polarity` as of API 12.0.9.
-- This rebuild's floor is API >= 12.09 (see AGENTS.md), above both gates
-- -- matching this project's existing "no version branching" rule, this
-- codec always includes the full 34-field/38-byte struct unconditionally.
--
-- This module is deliberately raw-wire-values-only, same as every other
-- MSP codec in this project -- it does NOT know about rates_type-
-- dependent display scaling for rcRates_N/rcExpo_N/rates_N (the "curve
-- shape" fields, whose *displayed* units/decimals genuinely depend on
-- which of the 7 rate tables is active -- Betaflight/Raceflight/Kiss/
-- Actual/Quick/Rotorflight all reuse the same three wire fields per axis,
-- just interpreted differently). That display-only concern belongs to
-- app/pages/rates.lua, via lib/rate_curve_scale.lua -- kept separate so
-- this codec stays the same simple "raw bytes in, raw bytes out" shape
-- as every other lib/msp_*.lua module.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/rates.lua reloads fresh via loadfile() on every open, so
-- without caching this was rebuilt on every navigation too. See
-- lib/msp_pid_tuning.lua's own comment for the full reasoning (added
-- after a live memory investigation, see AGENTS.md's "Memory stats
-- printing" section).
if package.loaded["rfsuite.lib.msp_rc_tuning"] then
  return package.loaded["rfsuite.lib.msp_rc_tuning"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 111
local WRITE_COMMAND = 204

-- {name, wireType}, in exact wire order.
local FIELDS = {
  {"rates_type", "U8"},

  {"rcRates_1", "U8"}, {"rcExpo_1", "U8"}, {"rates_1", "U8"}, {"response_time_1", "U8"}, {"accel_limit_1", "U16"},
  {"rcRates_2", "U8"}, {"rcExpo_2", "U8"}, {"rates_2", "U8"}, {"response_time_2", "U8"}, {"accel_limit_2", "U16"},
  {"rcRates_3", "U8"}, {"rcExpo_3", "U8"}, {"rates_3", "U8"}, {"response_time_3", "U8"}, {"accel_limit_3", "U16"},
  {"rcRates_4", "U8"}, {"rcExpo_4", "U8"}, {"rates_4", "U8"}, {"response_time_4", "U8"}, {"accel_limit_4", "U16"},

  {"setpoint_boost_gain_1", "U8"}, {"setpoint_boost_cutoff_1", "U8"},
  {"setpoint_boost_gain_2", "U8"}, {"setpoint_boost_cutoff_2", "U8"},
  {"setpoint_boost_gain_3", "U8"}, {"setpoint_boost_cutoff_3", "U8"},
  {"setpoint_boost_gain_4", "U8"}, {"setpoint_boost_cutoff_4", "U8"},

  {"yaw_dynamic_ceiling_gain", "U8"},
  {"yaw_dynamic_deadband_gain", "U8"},
  {"yaw_dynamic_deadband_filter", "U8"},

  {"cyclic_ring", "U8"},
  {"cyclic_polarity", "U8"},
}

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua) -- rates_type=4 (Actual, matching firmware's
-- own default per rotorflight-lua-ethos-suite's RC_TUNING.lua), plausible
-- values for the rest, in wire order.
local SIMULATOR_RESPONSE = {
  4,                  -- rates_type (Actual)

  18, 0, 24, 30, 0, 0,   -- axis 1 (roll): rcRates,rcExpo,rates,response_time,accel_limit(U16)
  18, 0, 24, 30, 0, 0,   -- axis 2 (pitch)
  18, 0, 40, 30, 0, 0,   -- axis 3 (yaw)
  50, 0, 50, 30, 0, 0,   -- axis 4 (collective)

  0, 15,   -- setpoint_boost_gain_1, cutoff_1
  0, 90,   -- setpoint_boost_gain_2, cutoff_2
  0, 15,   -- setpoint_boost_gain_3, cutoff_3
  0, 15,   -- setpoint_boost_gain_4, cutoff_4

  30, 30, 60,   -- yaw_dynamic_ceiling_gain, deadband_gain, deadband_filter

  150, 0,   -- cyclic_ring, cyclic_polarity
}

-- Per-field {min, max, default, suffix}, for the fields whose meaning
-- and scale is FIXED regardless of rates_type (i.e. everything except
-- rcRates_N/rcExpo_N/rates_N -- see lib/rate_curve_scale.lua for those).
-- Bounds/behavior cross-checked against rotorflight-configurator's own
-- src/js/msp/MSPHelper.js (MSP_RC_TUNING/MSP_SET_RC_TUNING cases), which
-- reads/writes every one of these as a plain raw integer -- no division
-- or multiplier at all, confirming these need no decimals/scale here
-- either, unlike the curve fields.
local FIELD_META = {
  response_time_1 = {min = 0, max = 250, default = 30, suffix = "ms"},
  response_time_2 = {min = 0, max = 250, default = 30, suffix = "ms"},
  response_time_3 = {min = 0, max = 250, default = 30, suffix = "ms"},
  response_time_4 = {min = 0, max = 250, default = 30, suffix = "ms"},
  -- accel_limit_N: the original suite's own UI multiplies this raw U16
  -- by 10 for a "nicer" round display number (rotorflight-configurator's
  -- own getIntegerValue(..., 0.1) on save confirms the wire byte is
  -- displayed-value/10) -- Ethos's own field:decimals(n) only divides
  -- for display, it has no equivalent "multiply up" option, so this
  -- rebuild shows the raw firmware value directly rather than
  -- reimplementing that multiply-by-10 by hand. Same raw value, same
  -- real-world meaning, just not rounded to a "nicer" number.
  accel_limit_1 = {min = 0, max = 5000, default = 0, suffix = "°/s"},
  accel_limit_2 = {min = 0, max = 5000, default = 0, suffix = "°/s"},
  accel_limit_3 = {min = 0, max = 5000, default = 0, suffix = "°/s"},
  accel_limit_4 = {min = 0, max = 5000, default = 0, suffix = "°/s"},
  setpoint_boost_gain_1 = {min = 0, max = 250, default = 0},
  setpoint_boost_gain_2 = {min = 0, max = 250, default = 0},
  setpoint_boost_gain_3 = {min = 0, max = 250, default = 0},
  setpoint_boost_gain_4 = {min = 0, max = 250, default = 0},
  setpoint_boost_cutoff_1 = {min = 0, max = 250, default = 15, suffix = "hz"},
  setpoint_boost_cutoff_2 = {min = 0, max = 250, default = 90, suffix = "hz"},
  setpoint_boost_cutoff_3 = {min = 0, max = 250, default = 15, suffix = "hz"},
  setpoint_boost_cutoff_4 = {min = 0, max = 250, default = 15, suffix = "hz"},
  yaw_dynamic_ceiling_gain = {min = 0, max = 250, default = 30},
  yaw_dynamic_deadband_gain = {min = 0, max = 250, default = 30},
  yaw_dynamic_deadband_filter = {min = 0, max = 250, default = 60, decimals = 1, suffix = "hz"},
  cyclic_ring = {min = 0, max = 250, default = 150, suffix = "%"},
  -- rates_type and cyclic_polarity are choice fields (built with their
  -- own {label, value} option lists in app/pages/rates.lua/rates_cyclic.lua)
  -- -- choice fields never call :default(), so no entry is needed here
  -- (see app/field_layout.lua's buildField() comment).
}

local msp_rc_tuning = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
}

function msp_rc_tuning.decode(buf)
  -- Always start from byte 1, even if `buf` is a reused/shared table
  -- (e.g. the simulator fixture above) that a previous decode() left an
  -- `.offset` on.
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    if wireType == "U16" then
      data[name] = mspcodec.readU16(buf)
    else
      data[name] = mspcodec.readU8(buf)
    end
  end
  return data
end

function msp_rc_tuning.encode(data)
  local payload = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    if wireType == "U16" then
      mspcodec.writeU16(payload, data[name] or 0)
    else
      mspcodec.writeU8(payload, data[name] or 0)
    end
  end
  return payload
end

-- Builds a ready-to-publish message for lib/bus.lua's "msp.request" topic.
-- `onData(data)` is called with the decoded field table once the reply
-- arrives; `onError(reason)` (optional) on failure.
function msp_rc_tuning.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_rc_tuning.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on failure.
function msp_rc_tuning.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_rc_tuning.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_rc_tuning"] = msp_rc_tuning
return msp_rc_tuning
