-- Schema + message-builders for the MSP_ADVANCED_CONFIG /
-- MSP_SET_ADVANCED_CONFIG command pair (cmd 90 read / 91 write) --
-- app/pages/configuration.lua's PID loop speed (`pid_process_denom`).
--
-- **Read and write are genuinely asymmetric widths** -- confirmed
-- directly against rotorflight-firmware's own wire handlers
-- (src/main/msp/msp.c): the read reply is 6 bytes/5 fields
-- (gyro_sync_denom_compat, pid_process_denom, use_unsynced_pwm,
-- motor_pwm_protocol, motor_pwm_rate), but the write handler only ever
-- reads the first 2 bytes (`sbufReadU8(src)` twice, for
-- gyro_sync_denom_compat/pid_process_denom) and completely ignores
-- anything after that -- use_unsynced_pwm/motor_pwm_protocol/
-- motor_pwm_rate live on this same read command but are configured via
-- MSP_MOTOR_CONFIG instead, not writable here at all. Every other codec
-- in this rebuild round-trips one identical field list both ways; this
-- is the first one that doesn't, so `WRITE_FIELDS` is a separate,
-- shorter list `encode()` uses instead of `FIELDS`. No page_runtime.lua
-- change was needed for this -- performSave() already just hands the
-- full read `data` table to buildWriteMessage(), and encode() picking a
-- subset of it to actually serialize is entirely this module's own
-- concern.
--
-- `gyro_sync_denom_compat` is a legacy compatibility placeholder --
-- firmware's own read handler hardcodes it to the literal `1` on every
-- read (`sbufWriteU8(dst, 1); // compat: gyro denom`), never a real
-- config value -- but the write side still expects *some* byte there
-- (immediately discarded: `sbufReadU8(src); // compat: gyro denom`), so
-- this page must still send back whatever it last read for that field
-- rather than a hardcoded literal, matching
-- rotorflight-lua-ethos-suite's own configuration.lua exactly (it
-- re-reads the field and writes back that same value, not a constant).
--
-- rotorflight-configurator's own MSPHelper.js only parses the first 2
-- bytes of this same read reply (its own FC.ADVANCED_CONFIG.gyro_sync_denom/
-- pid_process_denom) -- not a discrepancy, just confirms configurator
-- gets use_unsynced_pwm/motor_pwm_protocol/motor_pwm_rate from
-- MSP_MOTOR_CONFIG's own reply instead, the same place firmware's write
-- handler expects them to be changed from.
--
-- Cross-checked against rotorflight-lua-ethos-suite's own
-- tasks/scheduler/msp/api/ADVANCED_CONFIG.lua, whose own FIELD_SPEC/
-- WRITE_FIELD_SPEC split matches this file's FIELDS/WRITE_FIELDS
-- exactly, field-for-field.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/configuration.lua reloads fresh via loadfile() on every
-- open, so without caching this was rebuilt on every navigation too. See
-- lib/msp_pid_tuning.lua's own comment for the full reasoning (added
-- after a live memory investigation, see AGENTS.md's "Memory stats
-- printing" section).
if package.loaded["rfsuite.lib.msp_advanced_config"] then
  return package.loaded["rfsuite.lib.msp_advanced_config"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 90
local WRITE_COMMAND = 91

-- {name, wireType}, in exact wire order -- the full 6-byte read reply.
local FIELDS = {
  {"gyro_sync_denom_compat", "U8"},
  {"pid_process_denom", "U8"},
  {"use_unsynced_pwm", "U8"},
  {"motor_pwm_protocol", "U8"},
  {"motor_pwm_rate", "U16"},
}

-- {name, wireType}, in exact wire order -- the 2-byte write payload
-- (see this file's own header comment for why it's shorter than FIELDS).
local WRITE_FIELDS = {
  {"gyro_sync_denom_compat", "U8"},
  {"pid_process_denom", "U8"},
}

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua) -- lifted directly from ADVANCED_CONFIG.lua's
-- own SIM_RESPONSE, in wire order.
local SIMULATOR_RESPONSE = {
  1,      -- gyro_sync_denom_compat
  1,      -- pid_process_denom
  0,      -- use_unsynced_pwm
  0,      -- motor_pwm_protocol
  232, 3, -- motor_pwm_rate (U16)
}

-- `pid_process_denom`'s real range/default per rotorflight-lua-ethos-
-- suite's own FIELD_SPEC (1-16, no stated default -- falls back to 0
-- like every other codec's undeclared default, see app/field_layout.lua's
-- comment). app/pages/configuration.lua doesn't use this directly (its
-- own choice-field options are computed dynamically from the live gyro
-- rate, see getPidLoopChoices() there) -- kept for consistency with
-- every other codec's own FIELD_META, and in case a future page ever
-- needs a plain numeric field for it instead.
local FIELD_META = {
  pid_process_denom = {min = 1, max = 16, default = 0},
}

local msp_advanced_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELDS = FIELDS,
  WRITE_FIELDS = WRITE_FIELDS,
  FIELD_META = FIELD_META,
}

function msp_advanced_config.decode(buf)
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

function msp_advanced_config.encode(data)
  local payload = {}
  for i = 1, #WRITE_FIELDS do
    local name, wireType = WRITE_FIELDS[i][1], WRITE_FIELDS[i][2]
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
function msp_advanced_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_advanced_config.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- Builds a ready-to-publish write message. `onWritten()` (optional) is
-- called once the FC acknowledges the write; `onError(reason)` on
-- failure. `data` may carry all 5 read fields (it's whatever loadData()
-- last read) -- only the 2 in WRITE_FIELDS actually get serialized.
function msp_advanced_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_advanced_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["rfsuite.lib.msp_advanced_config"] = msp_advanced_config
return msp_advanced_config
