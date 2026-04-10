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

local API_NAME = "RC_CONFIG"
local MSP_API_CMD_READ = 66
local MSP_API_CMD_WRITE = 67

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"rc_center", "U16", 1400, 1600, 1500, "us"},
    {"rc_deflection", "U16", 200, 700, 510, "us"},
    {"rc_arm_throttle", "U16", 850, 1500, 1050, "us"},
    {"rc_min_throttle", "U16", 860, 1500, 1100, "us"},
    {"rc_max_throttle", "U16", 1510, 2150, 1900, "us"},
    {"rc_deadband", "U8", 0, 100, 2, "us"},
    {"rc_yaw_deadband", "U8", 0, 100, 2, "us"}
}

local SIM_RESPONSE = core.simResponse({
    220, 5, -- rc_center
    254, 1, -- rc_deflection
    232, 3, -- rc_arm_throttle
    242, 3, -- rc_min_throttle
    208, 7, -- rc_max_throttle
    4,      -- rc_deadband
    4       -- rc_yaw_deadband
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
