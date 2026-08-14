-- Schema for the MSP_STATUS command (cmd 101, read-only) --
-- app/pages/configuration.lua's only current use is
-- `task_delta_time_gyro` (the live gyro loop period, used to compute the
-- PID loop speed choice-field's kHz labels), but the full struct is
-- decoded field-for-field regardless -- byte offsets are sequential, so
-- every field before the one actually wanted has to be decoded anyway,
-- and a fuller MSP_STATUS decode is a natural building block for
-- whatever Setup/System page needs profile counts, motor/servo counts,
-- or arming-disable flags next (same "decode the whole struct even if
-- only some fields have a widget yet" convention lib/msp_filter_config.lua's
-- own `gyro_hardware_lpf` already established).
--
-- Field order/types confirmed directly against rotorflight-firmware's
-- own wire handler (src/main/msp/msp.c, MSP_STATUS case) and cross-
-- checked against rotorflight-lua-ethos-suite's own
-- tasks/scheduler/msp/api/STATUS.lua FIELD_SPEC -- both agree exactly,
-- field-for-field. `profile_number` and
-- `extra_flight_mode_flags_count` are legacy compatibility placeholders
-- firmware always writes as a literal 0 -- decoded in-place (same reason
-- as always: keeping every field after them correctly aligned) but never
-- exposed as anything.
--
-- Read-only -- MSP_STATUS has no MSP_SET_STATUS counterpart in the
-- firmware at all, matching rotorflight-lua-ethos-suite's own
-- `core.createReadOnlyAPI(...)` for this exact command. No encode()/
-- buildWriteMessage() here, unlike every other codec in lib/.

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- app/pages/configuration.lua reloads fresh via loadfile() on every
-- open, so without caching this was rebuilt on every navigation too. See
-- lib/msp_pid_tuning.lua's own comment for the full reasoning (added
-- after a live memory investigation, see AGENTS.md's "Memory stats
-- printing" section).
if package.loaded["rfsuite.lib.msp_status"] then
  return package.loaded["rfsuite.lib.msp_status"]
end

local requireModule = assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 101

-- {name, wireType}, in exact wire order.
local FIELDS = {
  {"task_delta_time_pid", "U16"},
  {"task_delta_time_gyro", "U16"},
  {"sensor_status", "U16"},
  {"flight_mode_flags", "U32"},
  {"profile_number", "U8"},
  {"max_real_time_load", "U16"},
  {"average_cpu_load", "U16"},
  {"extra_flight_mode_flags_count", "U8"},
  {"arming_disable_flags_count", "U8"},
  {"arming_disable_flags", "U32"},
  {"reboot_required", "U8"},
  {"configuration_state", "U8"},
  {"current_pid_profile_index", "U8"},
  {"pid_profile_count", "U8"},
  {"current_control_rate_profile_index", "U8"},
  {"control_rate_profile_count", "U8"},
  {"motor_count", "U8"},
  {"servo_count", "U8"},
  {"gyro_detection_flags", "U8"},
}

-- Fixture reply used automatically when running in the Ethos simulator
-- (see tasks/msp/queue.lua) -- lifted directly from STATUS.lua's own
-- SIM_RESPONSE, in wire order.
local SIMULATOR_RESPONSE = {
  252, 1,     -- task_delta_time_pid (U16)
  127, 0,     -- task_delta_time_gyro (U16)
  35, 0,      -- sensor_status (U16)
  0, 0, 0, 0, -- flight_mode_flags (U32)
  0,          -- profile_number
  122, 1,     -- max_real_time_load (U16)
  182, 0,     -- average_cpu_load (U16)
  0,          -- extra_flight_mode_flags_count
  0,          -- arming_disable_flags_count
  0, 0, 0, 0, -- arming_disable_flags (U32)
  2,          -- reboot_required
  0,          -- configuration_state
  5,          -- current_pid_profile_index
  6,          -- pid_profile_count
  1,          -- current_control_rate_profile_index
  4,          -- control_rate_profile_count
  1,          -- motor_count
  4,          -- servo_count
  1,          -- gyro_detection_flags
}

local msp_status = {
  READ_COMMAND = READ_COMMAND,
  FIELDS = FIELDS,
}

local function readField(buf, wireType)
  if wireType == "U16" then
    return mspcodec.readU16(buf)
  elseif wireType == "U32" then
    return mspcodec.readU32(buf)
  end
  return mspcodec.readU8(buf)
end

function msp_status.decode(buf)
  buf.offset = 1
  local data = {}
  for i = 1, #FIELDS do
    local name, wireType = FIELDS[i][1], FIELDS[i][2]
    data[name] = readField(buf, wireType)
  end
  return data
end

-- Builds a ready-to-publish message for lib/bus.lua's "msp.request" topic.
-- `onData(data)` is called with the decoded field table once the reply
-- arrives; `onError(reason)` (optional) on failure. No corresponding
-- buildWriteMessage() -- this command is read-only.
function msp_status.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      onData(msp_status.decode(buf))
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

package.loaded["rfsuite.lib.msp_status"] = msp_status
return msp_status
