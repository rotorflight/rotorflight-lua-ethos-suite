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

local API_NAME = "FEATURE_CONFIG"
local MSP_API_CMD_READ = 36
local MSP_API_CMD_WRITE = 37

local TBL_OFF_ON = {
    "@i18n(api.MOTOR_CONFIG.tbl_off)@",
    "@i18n(api.MOTOR_CONFIG.tbl_on)@"
}

local FEATURES_BITMAP = {
    { field = "rx_ppm", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_1", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_2", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rx_serial", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_4", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_5", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "softserial", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "gps", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_8", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rangefinder", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "telemetry", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_11", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_12", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rx_parallel_pwm", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rx_msp", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rssi_adc", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "led_strip", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "dashboard", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "osd", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "cms", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_20", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_21", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_22", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_23", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "unused_24", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rx_spi", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "governor", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "esc_sensor", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "freq_sensor", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "dyn_notch", tableIdxInc = -1, table = TBL_OFF_ON },
    { field = "rpm_filter", tableIdxInc = -1, table = TBL_OFF_ON }
}

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"enabledFeatures", "U32"}
}

local SIM_RESPONSE = core.simResponse({
    0, 0, 0, 0 -- enabledFeatures
})

local api = core.createConfigAPI({
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

api.__rfReadStructure[1].bitmap = FEATURES_BITMAP

return api
