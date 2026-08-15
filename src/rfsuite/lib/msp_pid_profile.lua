-- Schema + message-builders for the MSP_PID_PROFILE / MSP_SET_PID_PROFILE
-- command pair (cmd 94 read / 95 write).
--
-- Stateless: every function takes/returns plain tables, nothing is cached
-- here. Used by app/pages/pid_controller.lua to build request messages for
-- lib/bus.lua's "msp.request" topic (handled by tasks/background.lua's MSP
-- queue) -- this module never talks to tasks/msp/* directly itself.
--
-- Field order/types verified against rotorflight-firmware's actual wire
-- serializer (src/main/msp/msp.c, MSP_PID_PROFILE/MSP_SET_PID_PROFILE
-- cases), not just the Lua-side rotorflight-lua-ethos-suite schema --
-- the firmware's own *in-memory* pidProfile_s struct (pid.h) is grouped
-- differently for storage and is NOT wire order; only msp.c's explicit
-- sbufWrite/sbufRead sequence is authoritative. Every field here is a
-- plain U8 (unlike lib/msp_pid_tuning.lua's MSP_PID_TUNING, which is all
-- U16) -- do not reorder.
--
-- This rebuild's floor is API >= 12.09 (see AGENTS.md), which is above
-- the {12, 0, 8} version gate rotorflight-lua-ethos-suite uses to decide
-- whether the trailing yaw_inertia_precomp_* fields exist on the wire --
-- so unlike that project, this codec never version-branches: those two
-- fields are always present, always read/written, matching this
-- project's existing "no version branching" rule.
--
-- Three fields (error_rotation, yaw_collective_dynamic_gain,
-- yaw_collective_dynamic_decay) are wire-present but functionally dead in
-- supported firmware -- the FC always returns a fixed constant on read
-- (1, 0, 0 respectively) and silently discards whatever is written. They
-- are still decoded/encoded in-place (never skipped) so every field after
-- them stays correctly aligned; app/pages/pid_controller.lua simply never
-- builds an editable widget for them.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- five pages share this codec and each reloads fresh via loadfile() on
-- every open, so without caching this was rebuilt on every navigation
-- too. See lib/msp_pid_tuning.lua's own comment for the full reasoning
-- (added after a live memory investigation, see AGENTS.md's "Memory
-- stats printing" section).
if package.loaded["rfsuite.lib.msp_pid_profile"] then
  return package.loaded["rfsuite.lib.msp_pid_profile"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 94
local WRITE_COMMAND = 95

local FIELDS = {
  "pid_mode",
  "error_decay_time_ground",
  "error_decay_time_cyclic",
  "error_decay_time_yaw",
  "error_decay_limit_cyclic",
  "error_decay_limit_yaw",
  "error_rotation", -- dead: FC always reads back 1, write discarded
  "error_limit_0", "error_limit_1", "error_limit_2", -- roll, pitch, yaw
  "gyro_cutoff_0", "gyro_cutoff_1", "gyro_cutoff_2",
  "dterm_cutoff_0", "dterm_cutoff_1", "dterm_cutoff_2",
  "iterm_relax_type",
  "iterm_relax_cutoff_0", "iterm_relax_cutoff_1", "iterm_relax_cutoff_2",
  "yaw_cw_stop_gain",
  "yaw_ccw_stop_gain",
  "yaw_precomp_cutoff",
  "yaw_cyclic_ff_gain",
  "yaw_collective_ff_gain",
  "yaw_collective_dynamic_gain", -- dead: FC always reads back 0, write discarded
  "yaw_collective_dynamic_decay", -- dead: FC always reads back 0, write discarded
  "pitch_collective_ff_gain",
  "angle_level_strength",
  "angle_level_limit",
  "horizon_level_strength",
  "trainer_gain",
  "trainer_angle_limit",
  "cyclic_cross_coupling_gain",
  "cyclic_cross_coupling_ratio",
  "cyclic_cross_coupling_cutoff",
  "offset_limit_0", "offset_limit_1", -- roll, pitch
  "bterm_cutoff_0", "bterm_cutoff_1", "bterm_cutoff_2",
  "yaw_inertia_precomp_gain",
  "yaw_inertia_precomp_cutoff",
}

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua) -- one U8 per FIELDS entry, in order, using
-- each field's firmware default (rotorflight-firmware's pid.h defaults,
-- cross-checked against rotorflight-lua-ethos-suite's PID_PROFILE.lua).
local SIMULATOR_RESPONSE = {
  0,    -- pid_mode
  25,   -- error_decay_time_ground (2.5s, scale/10)
  250,  -- error_decay_time_cyclic (25s, scale/10)
  0,    -- error_decay_time_yaw
  12,   -- error_decay_limit_cyclic
  0,    -- error_decay_limit_yaw
  1,    -- error_rotation (dead, FC always reads back 1)
  45, 45, 60,   -- error_limit_0/1/2 (roll, pitch, yaw)
  50, 50, 100,  -- gyro_cutoff_0/1/2
  15, 15, 20,   -- dterm_cutoff_0/1/2
  0,    -- iterm_relax_type
  10, 10, 10,   -- iterm_relax_cutoff_0/1/2
  120,  -- yaw_cw_stop_gain
  80,   -- yaw_ccw_stop_gain
  5,    -- yaw_precomp_cutoff
  0,    -- yaw_cyclic_ff_gain
  30,   -- yaw_collective_ff_gain
  0,    -- yaw_collective_dynamic_gain (dead, FC always reads back 0)
  0,    -- yaw_collective_dynamic_decay (dead, FC always reads back 0)
  0,    -- pitch_collective_ff_gain
  40,   -- angle_level_strength
  55,   -- angle_level_limit
  40,   -- horizon_level_strength
  75,   -- trainer_gain
  20,   -- trainer_angle_limit
  50,   -- cyclic_cross_coupling_gain
  0,    -- cyclic_cross_coupling_ratio
  25,   -- cyclic_cross_coupling_cutoff (2.5Hz, scale/10)
  90, 90,       -- offset_limit_0/1 (roll, pitch)
  15, 15, 20,   -- bterm_cutoff_0/1/2
  0,    -- yaw_inertia_precomp_gain
  25,   -- yaw_inertia_precomp_cutoff (2.5Hz, scale/10)
}

-- Per-field {min, max, default, decimals, suffix}, sourced from
-- rotorflight-lua-ethos-suite's own tasks/scheduler/msp/api/PID_PROFILE.lua
-- FIELD_SPEC (field, type, min, max, default, unit, decimals, scale, ...)
-- -- the authoritative UI-facing schema this rebuild has no equivalent of
-- yet (see AGENTS.md's "Shared page machinery" note on why this rebuild
-- doesn't have that project's full declarative engine). `default` here is
-- in the same *raw wire* domain as `min`/`max` (matching how this
-- rebuild's own app/field_layout.lua already treats decimals -- e.g.
-- error_decay_time_ground displays as "2.5s" but its actual field range/
-- value is 0-250 with decimals=1), not the display-scaled value the
-- original schema's own `default` column shows -- so a field with
-- decimals=1 there has its default multiplied by 10 here.
--
-- Only fields an app/pages/*.lua page actually builds a widget for need an
-- entry to matter, but every field with a real (non-bare, non-choice) min/
-- max/default in the original schema is included, so a future page can
-- reuse this without a second research pass. `pid_mode`, `error_decay_-
-- time_yaw`, `error_decay_limit_yaw` (bare, no schema range), and
-- `error_rotation`/`iterm_relax_type` (choice/table fields, never take a
-- `:default()` -- see app/field_layout.lua's buildField()) are
-- deliberately absent.
local FIELD_META = {
  error_decay_time_ground = {min = 0, max = 250, default = 25, decimals = 1, suffix = "s"},
  error_decay_time_cyclic = {min = 0, max = 250, default = 250, decimals = 1, suffix = "s"},
  error_decay_limit_cyclic = {min = 0, max = 25, default = 12, suffix = "°"},
  error_limit_0 = {min = 0, max = 180, default = 45, suffix = "°"},
  error_limit_1 = {min = 0, max = 180, default = 45, suffix = "°"},
  error_limit_2 = {min = 0, max = 180, default = 60, suffix = "°"},
  gyro_cutoff_0 = {min = 0, max = 250, default = 50},
  gyro_cutoff_1 = {min = 0, max = 250, default = 50},
  gyro_cutoff_2 = {min = 0, max = 250, default = 100},
  dterm_cutoff_0 = {min = 0, max = 250, default = 15},
  dterm_cutoff_1 = {min = 0, max = 250, default = 15},
  dterm_cutoff_2 = {min = 0, max = 250, default = 20},
  iterm_relax_cutoff_0 = {min = 1, max = 100, default = 10},
  iterm_relax_cutoff_1 = {min = 1, max = 100, default = 10},
  iterm_relax_cutoff_2 = {min = 1, max = 100, default = 10},
  yaw_cw_stop_gain = {min = 25, max = 250, default = 120},
  yaw_ccw_stop_gain = {min = 25, max = 250, default = 80},
  yaw_precomp_cutoff = {min = 0, max = 250, default = 5, suffix = "Hz"},
  yaw_cyclic_ff_gain = {min = 0, max = 250, default = 0},
  yaw_collective_ff_gain = {min = 0, max = 250, default = 30},
  yaw_collective_dynamic_gain = {min = 0, max = 125, default = 0},
  yaw_collective_dynamic_decay = {min = 0, max = 250, default = 25, suffix = "s"},
  pitch_collective_ff_gain = {min = 0, max = 250, default = 0},
  angle_level_strength = {min = 0, max = 200, default = 40},
  angle_level_limit = {min = 10, max = 90, default = 55, suffix = "°"},
  horizon_level_strength = {min = 0, max = 200, default = 40},
  trainer_gain = {min = 25, max = 255, default = 75},
  trainer_angle_limit = {min = 10, max = 80, default = 20, suffix = "°"},
  cyclic_cross_coupling_gain = {min = 0, max = 250, default = 50},
  cyclic_cross_coupling_ratio = {min = 0, max = 200, default = 0, suffix = "%"},
  cyclic_cross_coupling_cutoff = {min = 1, max = 250, default = 25, decimals = 1, suffix = "Hz"},
  offset_limit_0 = {min = 0, max = 180, default = 90, suffix = "°"},
  offset_limit_1 = {min = 0, max = 180, default = 90, suffix = "°"},
  bterm_cutoff_0 = {min = 0, max = 250, default = 15},
  bterm_cutoff_1 = {min = 0, max = 250, default = 15},
  bterm_cutoff_2 = {min = 0, max = 250, default = 20},
  yaw_inertia_precomp_gain = {min = 0, max = 250, default = 0},
  yaw_inertia_precomp_cutoff = {min = 0, max = 250, default = 25, decimals = 1, suffix = "Hz"},
}

local msp_pid_profile = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
}

function msp_pid_profile.decode(buf)
  -- Always start from byte 1, even if `buf` is a reused/shared table (e.g.
  -- the simulator fixture above) that a previous decode() left an
  -- `.offset` on.
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    data[FIELDS[i]] = mspcodec.readU8(buf)
  end
  return data
end

function msp_pid_profile.encode(data)
  local payload = {}
  for i = 1, #FIELDS do
    mspcodec.writeU8(payload, data[FIELDS[i]] or 0)
  end
  return payload
end

-- Builds a ready-to-publish message for lib/bus.lua's "msp.request" topic.
-- `onData(data)` is called with the decoded field table once the reply
-- arrives; `onError(reason)` (optional) on failure.
function msp_pid_profile.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_pid_profile.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on failure.
-- `data` should be a full field table (everything in FIELDS, not just the
-- ones app/pages/pid_controller.lua exposes as editable widgets) -- see
-- that file's loadData()/performSave() for how the fields it doesn't
-- display are still round-tripped unchanged.
function msp_pid_profile.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_pid_profile.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_pid_profile"] = msp_pid_profile
return msp_pid_profile
