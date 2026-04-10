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

local API_NAME = "SENSOR_CONFIG"
local MSP_API_CMD_READ = 96
local MSP_API_CMD_WRITE = 97

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"acc_hardware", "U8"},
    {"baro_hardware", "U8"},
    {"mag_hardware", "U8"},
    {"gyro_to_use", "U8"},
    {"gyro_high_fsr", "U8"},
    {"gyroMovementCalibrationThreshold", "U8"},
    {"gyroCalibrationDuration", "U16"},
    {"gyro_offset_yaw", "U16"},
    {"checkOverflow", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    0,       -- acc_hardware
    0,       -- baro_hardware
    0,       -- mag_hardware
    0,       -- gyro_to_use
    0,       -- gyro_high_fsr
    48,      -- gyroMovementCalibrationThreshold
    244, 1,  -- gyroCalibrationDuration
    0, 0,    -- gyro_offset_yaw
    1        -- checkOverflow
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
