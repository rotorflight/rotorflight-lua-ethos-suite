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

local API_NAME = "BATTERY_CONFIG"
local MSP_API_CMD_READ = 32
local MSP_API_CMD_WRITE = 33

local TBL_BATTERY_SOURCE = {
    [1] = "@i18n(api.BATTERY_CONFIG.source_none)@",
    [2] = "@i18n(api.BATTERY_CONFIG.source_adc)@",
    [3] = "@i18n(api.BATTERY_CONFIG.source_esc)@",
    [4] = "@i18n(api.BATTERY_CONFIG.source_fbus)@"
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"batteryCapacity", "U16", 0, 20000, 0, "mAh", nil, nil, 50},
    {"batteryCellCount", "U8", 0, 24, 6},
    {"voltageMeterSource", "U8", nil, nil, nil, nil, nil, nil, nil, nil, TBL_BATTERY_SOURCE, -1},
    {"currentMeterSource", "U8", nil, nil, nil, nil, nil, nil, nil, nil, TBL_BATTERY_SOURCE, -1},
    {"vbatmincellvoltage", "U16", 0, 500, 3.3, "V", 2, 100},
    {"vbatmaxcellvoltage", "U16", 0, 500, 4.2, "V", 2, 100},
    {"vbatfullcellvoltage", "U16", 0, 500, 4.1, "V", 2, 100},
    {"vbatwarningcellvoltage", "U16", 0, 500, 3.5, "V", 2, 100},
    {"lvcPercentage", "U8"},
    {"consumptionWarningPercentage", "U8", 0, 50, 35, "%"}
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    FIELD_SPEC[#FIELD_SPEC + 1] = {"batteryCapacity_0", "U16", 0, 40000, 0, "mAh", nil, nil, 10}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"batteryCapacity_1", "U16", 0, 40000, 0, "mAh", nil, nil, 10}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"batteryCapacity_2", "U16", 0, 40000, 0, "mAh", nil, nil, 10}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"batteryCapacity_3", "U16", 0, 40000, 0, "mAh", nil, nil, 10}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"batteryCapacity_4", "U16", 0, 40000, 0, "mAh", nil, nil, 10}
    FIELD_SPEC[#FIELD_SPEC + 1] = {"batteryCapacity_5", "U16", 0, 40000, 0, "mAh", nil, nil, 10}
end

local SIM_RESPONSE = core.simResponse({
    136, 19, -- batteryCapacity
    6,       -- batteryCellCount
    1,       -- voltageMeterSource
    1,       -- currentMeterSource
    74, 1,   -- vbatmincellvoltage
    164, 1,  -- vbatmaxcellvoltage
    154, 1,  -- vbatfullcellvoltage
    94, 1,   -- vbatwarningcellvoltage
    100,     -- lvcPercentage
    30,      -- consumptionWarningPercentage
    232, 3,  -- batteryCapacity_0
    20, 5,   -- batteryCapacity_1
    64, 6,   -- batteryCapacity_2
    108, 7,  -- batteryCapacity_3
    152, 8,  -- batteryCapacity_4
    196, 9   -- batteryCapacity_5
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
