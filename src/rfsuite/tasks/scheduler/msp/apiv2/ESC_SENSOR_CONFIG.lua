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

local API_NAME = "ESC_SENSOR_CONFIG"
local MSP_API_CMD_READ = 123
local MSP_API_CMD_WRITE = 216

local TBL_ESC_TYPES = {
    "NONE", "BLHELI32", "HOBBYWING V4", "HOBBYWING V5", "SCORPION",
    "KONTRONIK", "OMP", "ZTW", "APD", "OPENYGE", "FLYROTOR",
    "GRAUPNER", "XDFLY", "FrSky F.BUS", "RECORD"
}
local TBL_OFF_ON = {
    "@i18n(api.ESC_SENSOR_CONFIG.tbl_off)@",
    "@i18n(api.ESC_SENSOR_CONFIG.tbl_on)@"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"protocol", "U8", nil, nil, nil, nil, nil, nil, nil, nil, TBL_ESC_TYPES, -1},
    {"half_duplex", "U8", 1, 2, 0, nil, nil, nil, nil, nil, TBL_OFF_ON, -1},
    {"update_hz", "U16", 10, 500, 200, "Hz"},
    {"current_offset", "U16", 0, 1000, 0},
    {"hw4_current_offset", "U16", 0, 1000, 0},
    {"hw4_current_gain", "U8", 0, 250, 0},
    {"hw4_voltage_gain", "U8", 0, 250, 30}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 7}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"pin_swap", "U8", nil, nil, nil, nil, nil, nil, nil, nil, TBL_OFF_ON, -1}
end

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"voltage_correction", "S8", -99, 125, 1, "%", nil, nil, nil, nil, nil, nil, false}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"current_correction", "S8", -99, 125, 1, "%", nil, nil, nil, nil, nil, nil, false}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"consumption_correction", "S8", -99, 125, 1, "%", nil, nil, nil, nil, nil, nil, false}
end

local SIM_RESPONSE = core.simResponse({
    0,       -- protocol
    0,       -- half_duplex
    200, 0,  -- update_hz
    0, 15,   -- current_offset
    0, 0,    -- hw4_current_offset
    0,       -- hw4_current_gain
    30,      -- hw4_voltage_gain
    0,       -- pin_swap
    0,       -- voltage_correction
    0,       -- current_correction
    0        -- consumption_correction
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
