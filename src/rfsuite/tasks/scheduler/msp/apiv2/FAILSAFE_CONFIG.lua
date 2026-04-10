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

local API_NAME = "FAILSAFE_CONFIG"
local MSP_API_CMD_READ = 75
local MSP_API_CMD_WRITE = 76

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"failsafe_delay", "U8"},
    {"failsafe_off_delay", "U8"},
    {"failsafe_throttle", "U16"},
    {"failsafe_switch_mode", "U8"},
    {"failsafe_throttle_low_delay", "U16"},
    {"failsafe_procedure", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    10,      -- failsafe_delay
    10,      -- failsafe_off_delay
    232, 3,  -- failsafe_throttle
    0,       -- failsafe_switch_mode
    100, 0,  -- failsafe_throttle_low_delay
    0        -- failsafe_procedure
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
