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

local API_NAME = "DEBUG_CONFIG"
local MSP_API_CMD_READ = 59
local MSP_API_CMD_WRITE = 60

-- Tuple layout:
--   field, type, api major, api minor, api revision, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"debug_count", "U8", 12, 0, 6},
    {"debug_value_count", "U8", 12, 0, 6},
    {"debug_mode", "U8", 12, 0, 6},
    {"debug_axis", "U8", 12, 0, 6}
}

-- Tuple layout:
--   field, type, api major, api minor, api revision, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local WRITE_FIELD_SPEC = {
    {"debug_mode", "U8", 12, 0, 6},
    {"debug_axis", "U8", 12, 0, 6}
}

local SIM_RESPONSE = core.simResponse({
    8,  -- debug_count
    8,  -- debug_value_count
    0,  -- debug_mode
    0   -- debug_axis
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    writeCmd = MSP_API_CMD_WRITE,
    fields = FIELD_SPEC,
    writeFields = WRITE_FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    initialRebuildOnWrite = true,
    writeUuidFallback = true,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
