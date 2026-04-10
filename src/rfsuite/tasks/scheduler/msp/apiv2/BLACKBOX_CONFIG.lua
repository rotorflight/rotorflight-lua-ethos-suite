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

local API_NAME = "BLACKBOX_CONFIG"
local MSP_API_CMD_READ = 80
local MSP_API_CMD_WRITE = 81

local TBL_OFF_ON = {
    "@i18n(api.MOTOR_CONFIG.tbl_off)@",
    "@i18n(api.MOTOR_CONFIG.tbl_on)@"
}

local BLACKBOX_FIELDS_BITMAP = {
    { field = "command", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "setpoint", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "mixer", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "pid", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "attitude", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "gyroraw", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "gyro", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "acc", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "mag", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "alt", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "battery", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rssi", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "gps", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rpm", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "motors", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "servos", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "vbec", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "vbus", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "temps", tableIdxInc = -1, table = TBL_OFF_ON }
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 7}) then
    BLACKBOX_FIELDS_BITMAP[#BLACKBOX_FIELDS_BITMAP + 1] = { field = "esc", tableIdxInc = -1, table = TBL_OFF_ON }
    BLACKBOX_FIELDS_BITMAP[#BLACKBOX_FIELDS_BITMAP + 1] = { field = "bec", tableIdxInc = -1, table = TBL_OFF_ON }
    BLACKBOX_FIELDS_BITMAP[#BLACKBOX_FIELDS_BITMAP + 1] = { field = "esc2", tableIdxInc = -1, table = TBL_OFF_ON }
end

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    BLACKBOX_FIELDS_BITMAP[#BLACKBOX_FIELDS_BITMAP + 1] = { field = "governor", tableIdxInc = -1, table = TBL_OFF_ON }
end

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"blackbox_supported", "U8"},
    {"device", "U8"},
    {"mode", "U8"},
    {"denom", "U16", nil, nil, nil, "1/x"},
    {"fields", "U32"},
    {"initialEraseFreeSpaceKiB", "U16", nil, nil, nil, "KiB", nil, nil, nil, nil, nil, nil, false},
    {"rollingErase", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false},
    {"gracePeriod", "U8", nil, nil, nil, "s", nil, nil, nil, nil, nil, nil, false}
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"device", "U8"},
    {"mode", "U8"},
    {"denom", "U16"},
    {"fields", "U32"},
    {"initialEraseFreeSpaceKiB", "U16", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false},
    {"rollingErase", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false},
    {"gracePeriod", "U8", nil, nil, nil, "s", nil, nil, nil, nil, nil, nil, false}
}

local SIM_RESPONSE = core.simResponse({
    1,          -- blackbox_supported
    1,          -- device
    1,          -- mode
    8, 0,       -- denom
    127, 238, 7, 0, -- fields
    0, 0,       -- initialEraseFreeSpaceKiB
    0,          -- rollingErase
    5           -- gracePeriod
})

local api = core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    initialRebuildOnWrite = true,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})

api.__rfReadStructure[5].bitmap = BLACKBOX_FIELDS_BITMAP

return api
