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

local API_NAME = "RX_MAP"
local MSP_API_CMD_READ = 64
local MSP_API_CMD_WRITE = 65

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"aileron", "U8"},
    {"elevator", "U8"},
    {"rudder", "U8"},
    {"collective", "U8"},
    {"throttle", "U8"},
    {"aux1", "U8"},
    {"aux2", "U8"},
    {"aux3", "U8"}
}

local SIM_RESPONSE = core.simResponse({
    0, -- aileron
    1, -- elevator
    2, -- rudder
    3, -- collective
    4, -- throttle
    5, -- aux1
    6, -- aux2
    7  -- aux3
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
