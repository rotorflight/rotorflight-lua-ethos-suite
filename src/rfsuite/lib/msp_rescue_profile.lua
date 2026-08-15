-- Schema + message-builders for the MSP_RESCUE_PROFILE /
-- MSP_SET_RESCUE_PROFILE command pair (cmd 146 read / 147 write).
--
-- Stateless: every function takes/returns plain tables, nothing is cached
-- here. Used by app/pages/rescue.lua to build request messages for
-- lib/bus.lua's "msp.request" topic -- this module never talks to
-- tasks/msp/* directly itself.
--
-- Field order/types verified against rotorflight-firmware's actual wire
-- serializer (src/main/msp/msp.c, MSP_RESCUE_PROFILE/MSP_SET_RESCUE_PROFILE
-- cases), not just the Lua-side rotorflight-lua-ethos-suite schema --
-- same caveat as lib/msp_pid_profile.lua/lib/msp_governor_profile.lua:
-- the firmware's own in-memory struct grouping isn't necessarily wire
-- order, only msp.c's explicit sbufWrite/sbufRead sequence is
-- authoritative. Not uniform width: the first 8 fields are U8, the
-- remaining 10 are U16 -- do not reorder, and do not assume a single
-- readU8/writeU8 loop like lib/msp_pid_tuning.lua's.
--
-- The trailing 5 wire fields (hover_altitude, alt_p_gain, alt_i_gain,
-- alt_d_gain, max_collective) are decoded/encoded here like every other
-- field, but app/pages/rescue.lua doesn't build a widget for them --
-- matching rotorflight-lua-ethos-suite's own app/modules/profile_rescue/
-- rescue.lua, whose formdata never references them either (an altitude-
-- hold rescue mode this firmware's Lua UI has never exposed).

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/rescue.lua reloads fresh via loadfile() on every open, so
-- without caching this was rebuilt on every navigation too. See
-- lib/msp_pid_tuning.lua's own comment for the full reasoning (added
-- after a live memory investigation, see AGENTS.md's "Memory stats
-- printing" section).
if package.loaded["rfsuite.lib.msp_rescue_profile"] then
  return package.loaded["rfsuite.lib.msp_rescue_profile"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 146
local WRITE_COMMAND = 147

-- {name, wireType}, in exact wire order.
local FIELDS = {
  {"rescue_mode", "U8"},
  {"rescue_flip_mode", "U8"},
  {"rescue_flip_gain", "U8"},
  {"rescue_level_gain", "U8"},
  {"rescue_pull_up_time", "U8"},
  {"rescue_climb_time", "U8"},
  {"rescue_flip_time", "U8"},
  {"rescue_exit_time", "U8"},
  {"rescue_pull_up_collective", "U16"},
  {"rescue_climb_collective", "U16"},
  {"rescue_hover_collective", "U16"},
  {"rescue_hover_altitude", "U16"}, -- wire-present, no widget -- see header comment
  {"rescue_alt_p_gain", "U16"},     -- wire-present, no widget
  {"rescue_alt_i_gain", "U16"},     -- wire-present, no widget
  {"rescue_alt_d_gain", "U16"},     -- wire-present, no widget
  {"rescue_max_collective", "U16"}, -- wire-present, no widget
  {"rescue_max_setpoint_rate", "U16"},
  {"rescue_max_setpoint_accel", "U16"},
}

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua) -- firmware defaults, in wire order.
local SIMULATOR_RESPONSE = {
  0,      -- rescue_mode (Off)
  0,      -- rescue_flip_mode (No Flip)
  200,    -- rescue_flip_gain
  100,    -- rescue_level_gain
  3,      -- rescue_pull_up_time (0.3s)
  10,     -- rescue_climb_time (1.0s)
  20,     -- rescue_flip_time (2.0s)
  5,      -- rescue_exit_time (0.5s)
  650, 0, -- rescue_pull_up_collective (65.0%, U16)
  450, 0, -- rescue_climb_collective (45.0%, U16)
  350, 0, -- rescue_hover_collective (35.0%, U16)
  0, 0,   -- rescue_hover_altitude (U16, no widget)
  0, 0,   -- rescue_alt_p_gain (U16, no widget)
  0, 0,   -- rescue_alt_i_gain (U16, no widget)
  0, 0,   -- rescue_alt_d_gain (U16, no widget)
  0, 0,   -- rescue_max_collective (U16, no widget)
  44, 1,  -- rescue_max_setpoint_rate = 300 (U16)
  184, 11,-- rescue_max_setpoint_accel = 3000 (U16)
}

-- Per-field {min, max, default, decimals, suffix}, same convention as
-- lib/msp_pid_profile.lua's own FIELD_META (see its comment). `default`
-- is in the same raw wire domain as min/max -- e.g. rescue_pull_up_time
-- displays as "0.3s" but its actual field range/value is 0-250 with
-- decimals=1, so its raw default is 3, not 0.3. Sourced from
-- rotorflight-firmware's src/main/cli/settings.c (authoritative raw wire
-- ranges) cross-checked against rotorflight-lua-ethos-suite's own
-- tasks/scheduler/msp/api/RESCUE_PROFILE.lua for defaults/units --
-- that project's own FIELD_SPEC mixes pre- and post-scale min/max
-- inconsistently between fields (confirmed by reading its
-- app/lib/utils.lua:scaleValue()), so firmware CLI's raw ranges were
-- used here instead of trying to reproduce that ambiguity.
-- rescue_mode/rescue_flip_mode are choice fields (Off/On, No Flip/Flip)
-- built with explicit `choices` in app/pages/rescue.lua, so (matching
-- every other choice field in this rebuild) they have no FIELD_META
-- entry and never take a `:default()` call.
local FIELD_META = {
  rescue_flip_gain = {min = 5, max = 250, default = 200},
  rescue_level_gain = {min = 5, max = 250, default = 100},
  rescue_pull_up_time = {min = 0, max = 250, default = 3, decimals = 1, suffix = "s"},
  rescue_climb_time = {min = 0, max = 250, default = 10, decimals = 1, suffix = "s"},
  rescue_flip_time = {min = 0, max = 250, default = 20, decimals = 1, suffix = "s"},
  rescue_exit_time = {min = 0, max = 250, default = 5, decimals = 1, suffix = "s"},
  rescue_pull_up_collective = {min = 0, max = 1000, default = 650, decimals = 1, suffix = "%"},
  rescue_climb_collective = {min = 0, max = 1000, default = 450, decimals = 1, suffix = "%"},
  rescue_hover_collective = {min = 0, max = 1000, default = 350, decimals = 1, suffix = "%"},
  rescue_max_setpoint_rate = {min = 5, max = 1000, default = 300, suffix = "°/s"},
  rescue_max_setpoint_accel = {min = 0, max = 10000, default = 3000, suffix = "°/s²"},
}

local msp_rescue_profile = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
}

function msp_rescue_profile.decode(buf)
  -- Always start from byte 1, even if `buf` is a reused/shared table (e.g.
  -- the simulator fixture above) that a previous decode() left an
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

function msp_rescue_profile.encode(data)
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
function msp_rescue_profile.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_rescue_profile.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on failure.
-- `data` should be a full field table (everything in FIELDS, not just the
-- ones app/pages/rescue.lua exposes as editable widgets) -- see that
-- file's use of app/page_runtime.lua's load/save for how the fields it
-- doesn't display are still round-tripped unchanged.
function msp_rescue_profile.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_rescue_profile.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_rescue_profile"] = msp_rescue_profile
return msp_rescue_profile
