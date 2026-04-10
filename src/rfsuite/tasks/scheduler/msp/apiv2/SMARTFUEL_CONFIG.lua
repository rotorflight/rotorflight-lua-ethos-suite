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

local API_NAME = "SMARTFUEL_CONFIG"
local MSP_API_CMD_READ = 0x3006
local MSP_API_CMD_WRITE = 0x3007

local sourceTable = {
    "@i18n(api.BATTERY_INI.tbl_off)@",
    "@i18n(api.BATTERY_INI.tbl_on)@"
}

-- Tuple layout:
--   field, type, api major, api minor, api revision, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"smartfuel_source", "U8", nil, nil, nil, 0, 1, 0, nil, nil, nil, nil, nil, sourceTable, -1},
    {"stabilize_delay", "U16", nil, nil, nil, 0, 10000, 1500, "s", 1, 1000, 1},
    {"stable_window", "U16", nil, nil, nil, 0, 100, 15, "V", 2, 100, 1},
    {"voltage_fall_limit", "U16", nil, nil, nil, 0, 100, 5, "V/s", 2, 100, 1},
    {"fuel_drop_rate", "U16", nil, nil, nil, 0, 500, 10, "%/s", 1, 10, 1},
    {"fuel_rise_rate", "U16", nil, nil, nil, 0, 500, 2, "%/s", 1, 10, 1},
    {"sag_multiplier_percent", "U16", nil, nil, nil, 0, 200, 70, "x", 2, 100, 1}
}

local SIM_RESPONSE = core.simResponse({
    0,       -- smartfuel_source
    220, 5,  -- stabilize_delay
    15, 0,   -- stable_window
    5, 0,    -- voltage_fall_limit
    10, 0,   -- fuel_drop_rate
    2, 0,    -- fuel_rise_rate
    70, 0    -- sag_multiplier_percent
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    minApiVersion = {12, 0, 10},
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
