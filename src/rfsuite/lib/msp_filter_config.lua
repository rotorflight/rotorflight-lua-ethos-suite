-- Schema + message-builders for the MSP_FILTER_CONFIG /
-- MSP_SET_FILTER_CONFIG command pair (cmd 92 read / 93 write).
--
-- Field order/types verified against rotorflight-firmware's actual wire
-- serializer (src/main/msp/msp.c, MSP_FILTER_CONFIG case) -- matches
-- rotorflight-lua-ethos-suite's own tasks/scheduler/msp/api/FILTER_CONFIG.lua
-- FIELD_SPEC exactly, field-for-field, so no separate "wire order differs
-- from the Lua schema" caveat here (unlike lib/msp_pid_profile.lua/
-- lib/msp_governor_profile.lua, whose firmware in-memory structs are
-- grouped differently for storage). NOT uniform width: gyro_hardware_lpf,
-- gyro_lpf1_type, gyro_lpf2_type, dyn_notch_count, dyn_notch_q, rpm_preset,
-- rpm_min_hz are U8; every other field is U16.
--
-- `rpm_preset`/`rpm_min_hz` only exist on the wire as of API 12.0.8
-- (firmware guards them with USE_RPM_FILTER, and the Lua schema itself
-- version-gates them below {12, 0, 8}). This rebuild's floor is API >=
-- 12.09 (see AGENTS.md), above that gate -- matching this project's
-- existing "no version branching" rule -- so this codec always includes
-- them: the full 17-field struct, unconditionally.
--
-- `gyro_hardware_lpf` is wire-present but never exposed as a widget --
-- the original's own filters.lua apidata never references it either
-- (it's legacy/unused in current firmware) -- still decoded/encoded
-- in-place so every field after it stays correctly aligned.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/filters.lua reloads fresh via loadfile() on every open, so
-- without caching this was rebuilt on every navigation too. See
-- lib/msp_pid_tuning.lua's own comment for the full reasoning (added
-- after a live memory investigation, see AGENTS.md's "Memory stats
-- printing" section).
if package.loaded["rfsuite.lib.msp_filter_config"] then
  return package.loaded["rfsuite.lib.msp_filter_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 92
local WRITE_COMMAND = 93

-- {name, wireType}, in exact wire order.
local FIELDS = {
  {"gyro_hardware_lpf", "U8"},
  {"gyro_lpf1_type", "U8"},
  {"gyro_lpf1_static_hz", "U16"},
  {"gyro_lpf2_type", "U8"},
  {"gyro_lpf2_static_hz", "U16"},
  {"gyro_soft_notch_hz_1", "U16"},
  {"gyro_soft_notch_cutoff_1", "U16"},
  {"gyro_soft_notch_hz_2", "U16"},
  {"gyro_soft_notch_cutoff_2", "U16"},
  {"gyro_lpf1_dyn_min_hz", "U16"},
  {"gyro_lpf1_dyn_max_hz", "U16"},
  {"dyn_notch_count", "U8"},
  {"dyn_notch_q", "U8"},
  {"dyn_notch_min_hz", "U16"},
  {"dyn_notch_max_hz", "U16"},
  {"rpm_preset", "U8"},
  {"rpm_min_hz", "U8"},
}

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua) -- lifted directly from FILTER_CONFIG.lua's
-- own SIM_RESPONSE, in wire order.
local SIMULATOR_RESPONSE = {
  0,       -- gyro_hardware_lpf
  1,       -- gyro_lpf1_type
  100, 0,  -- gyro_lpf1_static_hz (U16)
  0,       -- gyro_lpf2_type
  0, 0,    -- gyro_lpf2_static_hz (U16)
  0, 0,    -- gyro_soft_notch_hz_1 (U16)
  0, 0,    -- gyro_soft_notch_cutoff_1 (U16)
  0, 0,    -- gyro_soft_notch_hz_2 (U16)
  0, 0,    -- gyro_soft_notch_cutoff_2 (U16)
  0, 0,    -- gyro_lpf1_dyn_min_hz (U16)
  25, 0,   -- gyro_lpf1_dyn_max_hz (U16)
  0,       -- dyn_notch_count
  100,     -- dyn_notch_q
  0, 0,    -- dyn_notch_min_hz (U16)
  0, 0,    -- dyn_notch_max_hz (U16)
  1,       -- rpm_preset
  20,      -- rpm_min_hz
}

-- Per-field {min, max, default, decimals, suffix}, sourced from
-- rotorflight-lua-ethos-suite's own FILTER_CONFIG.lua FIELD_SPEC, same
-- convention as lib/msp_governor_profile.lua's own FIELD_META. That
-- schema leaves `default` nil for most fields (only gyro_lpf1_static_hz
-- has a real one, 100); matching the original's own unconditional
-- `field:default(...)` behavior (see app/field_layout.lua's comment),
-- those fall back to 0 here too, same as every other codec in this
-- project. `dyn_notch_q`'s `decimals = 1` mirrors the schema's own
-- `decimals=1` column (raw wire range 0-100, displayed 0.0-10.0) -- the
-- same raw-value-plus-decimals convention this project already uses
-- elsewhere (e.g. lib/msp_pid_profile.lua's error_decay_time_ground).
-- `gyro_lpf1_type`/`gyro_lpf2_type` (choice, 0=None/1=1st/2nd) and
-- `rpm_preset` (choice, 0=Custom/1=Low/2=Medium/3=High) have no entry
-- here -- choice fields never call `:default()` (see
-- app/field_layout.lua's buildField()), so a min/max/default for them
-- would never be read; their option lists live in app/pages/filters.lua
-- itself, next to the fields that use them.
local FIELD_META = {
  gyro_lpf1_static_hz = {min = 0, max = 4000, default = 100, suffix = "hz"},
  gyro_lpf2_static_hz = {min = 0, max = 4000, default = 0, suffix = "hz"},
  gyro_soft_notch_hz_1 = {min = 0, max = 4000, default = 0, suffix = "hz"},
  gyro_soft_notch_cutoff_1 = {min = 0, max = 4000, default = 0, suffix = "hz"},
  gyro_soft_notch_hz_2 = {min = 0, max = 4000, default = 0, suffix = "hz"},
  gyro_soft_notch_cutoff_2 = {min = 0, max = 4000, default = 0, suffix = "hz"},
  gyro_lpf1_dyn_min_hz = {min = 0, max = 1000, default = 0, suffix = "hz"},
  gyro_lpf1_dyn_max_hz = {min = 0, max = 1000, default = 0, suffix = "hz"},
  dyn_notch_count = {min = 0, max = 8, default = 0},
  dyn_notch_q = {min = 0, max = 100, default = 0, decimals = 1},
  dyn_notch_min_hz = {min = 10, max = 200, default = 0, suffix = "hz"},
  dyn_notch_max_hz = {min = 100, max = 500, default = 0, suffix = "hz"},
  rpm_min_hz = {min = 1, max = 100, default = 0, suffix = "hz"},
}

local msp_filter_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
}

function msp_filter_config.decode(buf)
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

function msp_filter_config.encode(data)
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
function msp_filter_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_filter_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on failure.
function msp_filter_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_filter_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_filter_config"] = msp_filter_config
return msp_filter_config
