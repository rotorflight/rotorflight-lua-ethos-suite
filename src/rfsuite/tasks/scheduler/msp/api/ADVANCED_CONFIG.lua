--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local API_NAME = "ADVANCED_CONFIG"
local MSP_API_CMD_READ = 90
local MSP_API_CMD_WRITE = 91

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"gyro_sync_denom_compat", "U8", nil, nil, 1},
    {"pid_process_denom", "U8", 1, 16},
    {"use_unsynced_pwm", "U8"},
    {"motor_pwm_protocol", "U8"},
    {"motor_pwm_rate", "U16"}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"gyro_sync_denom_compat", "U8"},
    {"pid_process_denom", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    1,      -- gyro_sync_denom_compat
    1,      -- pid_process_denom
    0,      -- use_unsynced_pwm
    0,      -- motor_pwm_protocol
    232, 3  -- motor_pwm_rate
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
