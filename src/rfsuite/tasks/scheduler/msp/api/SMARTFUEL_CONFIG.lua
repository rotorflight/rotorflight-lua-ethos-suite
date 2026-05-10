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

local sourceTable = {
    "OFF (LOCAL)",
    "ON (FBL)"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"smartfuel", "U8", 0, 1, 0, nil, nil, nil, nil, nil, sourceTable, -1},
    {"smartfuel_voltage_fall_rate", "U16", 0, 100, 5, "V/s", 2, 100, 1},
    {"smartfuel_charge_drop_rate", "U16", 0, 500, 10, "%/s", 1, 10, 1},
    {"smartfuel_sag_multiplier", "U16", 0, 200, 70, "x", 2, 100, 1}
}

local SIM_RESPONSE = core.simResponse({
    0,       -- smartfuel (OFF)
    5, 0,    -- smartfuel_voltage_fall_rate
    10, 0,   -- smartfuel_charge_drop_rate
    70, 0    -- smartfuel_sag_multiplier
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
