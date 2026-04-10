--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicorev2) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/core.lua"))()
if msp and not msp.apicorev2 then
    msp.apicorev2 = core
end

local API_NAME = "STATUS"
local MSP_API_CMD_READ = 101

-- Flat field spec:
--   field name, type
local FIELD_SPEC = {
    "task_delta_time_pid", "U16",
    "task_delta_time_gyro", "U16",
    "sensor_status", "U16",
    "flight_mode_flags", "U32",
    "profile_number", "U8",
    "max_real_time_load", "U16",
    "average_cpu_load", "U16",
    "extra_flight_mode_flags_count", "U8",
    "arming_disable_flags_count", "U8",
    "arming_disable_flags", "U32",
    "reboot_required", "U8",
    "configuration_state", "U8",
    "current_pid_profile_index", "U8",
    "pid_profile_count", "U8",
    "current_control_rate_profile_index", "U8",
    "control_rate_profile_count", "U8",
    "motor_count", "U8",
    "servo_count", "U8",
    "gyro_detection_flags", "U8"
}

local SIM_RESPONSE = core.simResponse({
    252, 1,       -- task_delta_time_pid
    127, 0,       -- task_delta_time_gyro
    35, 0,        -- sensor_status
    0, 0, 0, 0,   -- flight_mode_flags
    0,            -- profile_number
    122, 1,       -- max_real_time_load
    182, 0,       -- average_cpu_load
    0,            -- extra_flight_mode_flags_count
    0,            -- arming_disable_flags_count
    0, 0, 0, 0,   -- arming_disable_flags
    2,            -- reboot_required
    0,            -- configuration_state
    5,            -- current_pid_profile_index
    6,            -- pid_profile_count
    1,            -- current_control_rate_profile_index
    4,            -- control_rate_profile_count
    1,            -- motor_count
    4,            -- servo_count
    1             -- gyro_detection_flags
})

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE
})
