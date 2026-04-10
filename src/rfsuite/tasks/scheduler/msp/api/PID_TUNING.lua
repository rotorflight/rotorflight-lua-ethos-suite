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

local API_NAME = "PID_TUNING"
local MSP_API_CMD_READ = 112
local MSP_API_CMD_WRITE = 202

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"pid_0_P", "U16", 0, 1000, 50},
    {"pid_0_I", "U16", 0, 1000, 100},
    {"pid_0_D", "U16", 0, 1000, 0},
    {"pid_0_F", "U16", 0, 1000, 100},

    {"pid_1_P", "U16", 0, 1000, 50},
    {"pid_1_I", "U16", 0, 1000, 100},
    {"pid_1_D", "U16", 0, 1000, 40},
    {"pid_1_F", "U16", 0, 1000, 100},

    {"pid_2_P", "U16", 0, 1000, 80},
    {"pid_2_I", "U16", 0, 1000, 120},
    {"pid_2_D", "U16", 0, 1000, 10},
    {"pid_2_F", "U16", 0, 1000, 0},

    {"pid_0_B", "U16", 0, 1000, 0},
    {"pid_1_B", "U16", 0, 1000, 0},
    {"pid_2_B", "U16", 0, 1000, 0},

    {"pid_0_O", "U16", 0, 1000, 45},
    {"pid_1_O", "U16", 0, 1000, 45}
}

local SIM_RESPONSE = core.simResponse({
    50, 0,   -- pid_0_P
    100, 0,  -- pid_0_I
    20, 0,   -- pid_0_D
    100, 0,  -- pid_0_F

    50, 0,   -- pid_1_P
    100, 0,  -- pid_1_I
    50, 0,   -- pid_1_D
    100, 0,  -- pid_1_F

    80, 0,   -- pid_2_P
    120, 0,  -- pid_2_I
    40, 0,   -- pid_2_D
    0, 0,    -- pid_2_F

    0, 0,    -- pid_0_B
    0, 0,    -- pid_1_B
    0, 0,    -- pid_2_B

    45, 0,   -- pid_0_O
    45, 0    -- pid_1_O
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true
})
