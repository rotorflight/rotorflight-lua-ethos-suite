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

local API_NAME = "SERVO_OVERRIDE"
local MSP_API_CMD_READ = 192
local MSP_API_CMD_WRITE = 193

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"servo_1", "U16"},
    {"servo_2", "U16"},
    {"servo_3", "U16"},
    {"servo_4", "U16"},
    {"servo_5", "U16"},
    {"servo_6", "U16"},
    {"servo_7", "U16"},
    {"servo_8", "U16"}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"servo_id", "U8"},
    {"action", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    209, 7, -- servo_1
    209, 7, -- servo_2
    209, 7, -- servo_3
    209, 7, -- servo_4
    209, 7, -- servo_5
    209, 7, -- servo_6
    209, 7, -- servo_7
    209, 7  -- servo_8
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    initialRebuildOnWrite = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
