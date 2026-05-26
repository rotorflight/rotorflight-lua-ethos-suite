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

local API_NAME = "MOTOR"
local MSP_API_CMD_READ = 104
local MSP_API_CMD_WRITE = 214

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"motor_1", "U16"},
    {"motor_2", "U16"},
    {"motor_3", "U16"},
    {"motor_4", "U16"},
    {"motor_5", "U16"},
    {"motor_6", "U16"},
    {"motor_7", "U16"},
    {"motor_8", "U16"}
}

local SIM_RESPONSE = core.simResponse({
    0, 0, -- motor_1
    0, 0, -- motor_2
    0, 0, -- motor_3
    0, 0, -- motor_4
    0, 0, -- motor_5
    0, 0, -- motor_6
    0, 0, -- motor_7
    0, 0  -- motor_8
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
