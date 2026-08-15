-- Schema + message-builders for the MSP_GOVERNOR_PROFILE /
-- MSP_SET_GOVERNOR_PROFILE command pair (cmd 148 read / 149 write).
--
-- Stateless: every function takes/returns plain tables, nothing is cached
-- here. Used by app/pages/tail_rotor.lua (alongside lib/msp_pid_profile.lua)
-- to build request messages for lib/bus.lua's "msp.request" topic -- this
-- module never talks to tasks/msp/* directly itself.
--
-- Field order/types verified against rotorflight-firmware's actual wire
-- serializer (src/main/msp/msp.c, MSP_GOVERNOR_PROFILE/MSP_SET_GOVERNOR_PROFILE
-- cases) -- the firmware's own in-memory struct is grouped differently for
-- storage and is NOT wire order, same caveat as lib/msp_pid_profile.lua.
-- Unlike that command, this one is NOT uniform width: `governor_headspeed`
-- and `governor_flags` are U16, everything else is U8 -- do not reorder,
-- and do not assume a single readU8/writeU8 loop like msp_pid_profile.lua's.
--
-- `governor_fallback_drop` and `governor_flags` only exist on the wire as
-- of API 12.09 (firmware reads/writes them conditionally, guarded by
-- remaining-byte-count checks, for older-client compatibility). This
-- rebuild's floor is API >= 12.09 (see AGENTS.md), so -- matching this
-- project's existing "no version branching" rule -- this codec always
-- includes them: the full 17-byte struct, unconditionally.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- three pages share this codec and each reloads fresh via loadfile() on
-- every open, so without caching this was rebuilt on every navigation
-- too. See lib/msp_pid_tuning.lua's own comment for the full reasoning
-- (added after a live memory investigation, see AGENTS.md's "Memory
-- stats printing" section).
if package.loaded["rfsuite.lib.msp_governor_profile"] then
  return package.loaded["rfsuite.lib.msp_governor_profile"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 148
local WRITE_COMMAND = 149

-- {name, wireType}, in exact wire order.
local FIELDS = {
  {"governor_headspeed", "U16"},
  {"governor_gain", "U8"},
  {"governor_p_gain", "U8"},
  {"governor_i_gain", "U8"},
  {"governor_d_gain", "U8"},
  {"governor_f_gain", "U8"},
  {"governor_tta_gain", "U8"},
  {"governor_tta_limit", "U8"},
  {"governor_yaw_weight", "U8"},
  {"governor_cyclic_weight", "U8"},
  {"governor_collective_weight", "U8"},
  {"governor_max_throttle", "U8"},
  {"governor_min_throttle", "U8"},
  {"governor_fallback_drop", "U8"},
  {"governor_flags", "U16"}, -- bitmap: bit2=fallback_precomp, bit3=voltage_comp, bit4=pid_spoolup, bit6=dyn_min_throttle
}

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua) -- firmware defaults, in wire order.
local SIMULATOR_RESPONSE = {
  232, 3, -- governor_headspeed = 1000 (U16)
  40,     -- governor_gain
  40,     -- governor_p_gain
  50,     -- governor_i_gain
  0,      -- governor_d_gain
  10,     -- governor_f_gain
  0,      -- governor_tta_gain
  20,     -- governor_tta_limit
  0,      -- governor_yaw_weight
  10,     -- governor_cyclic_weight
  100,    -- governor_collective_weight
  100,    -- governor_max_throttle
  10,     -- governor_min_throttle
  10,     -- governor_fallback_drop
  0, 0,   -- governor_flags = 0 (U16)
}

-- Per-field {min, max, default, suffix}, sourced from
-- rotorflight-lua-ethos-suite's own tasks/scheduler/msp/api/GOVERNOR_PROFILE.lua
-- FIELD_SPEC (field, type, min, max, default, unit, ...), same convention
-- as lib/msp_pid_profile.lua's own FIELD_META (see its comment). None of
-- this codec's numeric fields use decimals/scale, unlike PID_PROFILE's
-- handful of Hz/s fields, so no entry here needs a `decimals` key.
--
-- `governor_flags` (a packed bitmap) is deliberately absent -- it's only
-- ever built via app/field_layout.lua's `bit` spec (see
-- app/pages/governor_flags.lua), and choice/bit fields never take a
-- `:default()` call in the first place (see buildField()'s comment), so a
-- min/max/default entry for the whole packed field would never be read.
local FIELD_META = {
  governor_headspeed = {min = 0, max = 50000, default = 1000, suffix = "rpm"},
  governor_gain = {min = 0, max = 250, default = 40},
  governor_p_gain = {min = 0, max = 250, default = 40},
  governor_i_gain = {min = 0, max = 250, default = 50},
  governor_d_gain = {min = 0, max = 250, default = 0},
  governor_f_gain = {min = 0, max = 250, default = 10},
  governor_tta_gain = {min = 0, max = 250, default = 0},
  governor_tta_limit = {min = 0, max = 250, default = 20, suffix = "%"},
  governor_yaw_weight = {min = 0, max = 250, default = 0},
  governor_cyclic_weight = {min = 0, max = 250, default = 10},
  governor_collective_weight = {min = 0, max = 250, default = 100},
  governor_max_throttle = {min = 0, max = 100, default = 100, suffix = "%"},
  governor_min_throttle = {min = 0, max = 100, default = 10, suffix = "%"},
  governor_fallback_drop = {min = 0, max = 50, default = 10, suffix = "%"},
}

local msp_governor_profile = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
}

function msp_governor_profile.decode(buf)
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

function msp_governor_profile.encode(data)
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
function msp_governor_profile.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_governor_profile.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on failure.
-- `data` should be a full field table (everything in FIELDS, not just the
-- ones app/pages/tail_rotor.lua exposes as editable widgets) -- see that
-- file's use of app/page_runtime.lua's multi-source load/save for how the
-- fields it doesn't display are still round-tripped unchanged.
function msp_governor_profile.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_governor_profile.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_governor_profile"] = msp_governor_profile
return msp_governor_profile
