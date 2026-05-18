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

local API_NAME = "SMARTFUEL_CONFIG"
local MSP_API_CMD_READ = 0x4000
local MSP_API_CMD_WRITE = 0x4001

local modeTable = {
    "OFF (LOCAL)",
    "VOLTAGE",
    "CURRENT",
    "COMBINED"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"smartfuel_mode", "U8", 0, 3, 0, nil, nil, nil, nil, nil, modeTable, -1},
    {"voltage_drop_rate", "U8", 0, 250, 10, "mV/s", nil, nil, 1},
    {"charge_drop_rate", "U8", 0, 250, 50, "%/s", 2, 100, 1},
    {"sag_gain", "U8", 0, 100, 40, "%", nil, nil, 1}
}

local SIM_RESPONSE = core.simResponse({
    0,  -- smartfuel_mode
    10, -- voltage_drop_rate
    50, -- charge_drop_rate
    40  -- sag_gain
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minApiVersion = {12, 0, 9},
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
