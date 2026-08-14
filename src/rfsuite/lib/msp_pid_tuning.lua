-- Schema + message-builders for the MSP_PID_TUNING / MSP_SET_PID_TUNING
-- command pair (cmd 112 read / 202 write).
--
-- Stateless: every function takes/returns plain tables, nothing is cached
-- here. Used by app/pages/pids.lua to build request messages for
-- lib/bus.lua's "msp.request" topic (handled by tasks/background.lua's MSP
-- queue) -- this module never talks to tasks/msp/* directly itself.
--
-- Field order matches the flight controller wire format exactly (verified
-- against both rotorflight-lua-ethos-suite's PID_TUNING.lua and
-- rotorflight-lua-ethos's mspPidTuning.lua) -- do not reorder.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/pids.lua reloads fresh via loadfile() on every open, so
-- without caching this stateless codec (and its module-level FIELDS/
-- FIELD_META/SIMULATOR_RESPONSE tables) was rebuilt on every single
-- navigation too. Added after a live memory investigation confirmed the
-- *bulk* of this rebuild's observed RAM growth is an Ethos platform
-- trait (see AGENTS.md's "Memory stats printing" section) that no
-- script-side change can eliminate -- but this redundant reload is a
-- separate, real, avoidable cost.
if package.loaded["rfsuite.lib.msp_pid_tuning"] then
  return package.loaded["rfsuite.lib.msp_pid_tuning"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 112
local WRITE_COMMAND = 202

local FIELDS = {
  "roll_p", "roll_i", "roll_d", "roll_f",
  "pitch_p", "pitch_i", "pitch_d", "pitch_f",
  "yaw_p", "yaw_i", "yaw_d", "yaw_f",
  "roll_b", "pitch_b", "yaw_b",
  "roll_o", "pitch_o",
}

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua) -- one U16 pair per FIELDS entry, in order.
local SIMULATOR_RESPONSE = {
  70, 0, 225, 0, 90, 0, 120, 0,
  100, 0, 200, 0, 70, 0, 120, 0,
  100, 0, 125, 0, 83, 0, 0, 0,
  0, 0, 0, 0, 0, 0,
  25, 0, 25, 0,
}

-- Per-field {min, max, default}, sourced from rotorflight-lua-ethos-suite's
-- own tasks/scheduler/msp/api/PID_TUNING.lua FIELD_SPEC, same convention as
-- lib/msp_pid_profile.lua's own FIELD_META (see its comment) -- min/max
-- really is a flat 0-1000 for every one of these (confirmed against that
-- schema, not assumed: app/pages/pids.lua's previous blanket 0-1000 for
-- every column turned out to already be correct), but `default` differs
-- per axis/column -- e.g. roll_d defaults to 0 while pitch_d defaults to
-- 40 -- so it still needs a per-field entry, not a single shared constant.
local FIELD_META = {
  roll_p = {min = 0, max = 1000, default = 50},
  roll_i = {min = 0, max = 1000, default = 100},
  roll_d = {min = 0, max = 1000, default = 0},
  roll_f = {min = 0, max = 1000, default = 100},
  pitch_p = {min = 0, max = 1000, default = 50},
  pitch_i = {min = 0, max = 1000, default = 100},
  pitch_d = {min = 0, max = 1000, default = 40},
  pitch_f = {min = 0, max = 1000, default = 100},
  yaw_p = {min = 0, max = 1000, default = 80},
  yaw_i = {min = 0, max = 1000, default = 120},
  yaw_d = {min = 0, max = 1000, default = 10},
  yaw_f = {min = 0, max = 1000, default = 0},
  roll_b = {min = 0, max = 1000, default = 0},
  pitch_b = {min = 0, max = 1000, default = 0},
  yaw_b = {min = 0, max = 1000, default = 0},
  roll_o = {min = 0, max = 1000, default = 45},
  pitch_o = {min = 0, max = 1000, default = 45},
}

local msp_pid_tuning = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
}

function msp_pid_tuning.decode(buf)
  -- Always start from byte 1, even if `buf` is a reused/shared table (e.g.
  -- the simulator fixture below) that a previous decode() left an
  -- `.offset` on.
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    data[FIELDS[i]] = mspcodec.readU16(buf)
  end
  return data
end

function msp_pid_tuning.encode(data)
  local payload = {}
  for i = 1, #FIELDS do
    mspcodec.writeU16(payload, data[FIELDS[i]] or 0)
  end
  return payload
end

-- Builds a ready-to-publish message for lib/bus.lua's "msp.request" topic.
-- `onData(data)` is called with the decoded field table once the reply
-- arrives; `onError(reason)` (optional) on failure.
function msp_pid_tuning.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_pid_tuning.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on failure.
function msp_pid_tuning.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_pid_tuning.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_pid_tuning"] = msp_pid_tuning
return msp_pid_tuning
