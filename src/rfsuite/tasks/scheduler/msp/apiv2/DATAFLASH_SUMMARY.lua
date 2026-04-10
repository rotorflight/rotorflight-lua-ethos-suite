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

local API_NAME = "DATAFLASH_SUMMARY"
local OPTIONAL = false

-- Tuple layout:
--   field, type, min, max, default, unit,
--   decimals, scale, step, mult, table, tableIdxInc, mandatory, byteorder, tableEthos
local FIELD_SPEC = {
    {"flags", "U8", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"sectors", "U32", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"total", "U32", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL},
    {"used", "U32", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, OPTIONAL}
}

local SIM_RESPONSE = core.simResponse({
    3,             -- flags
    235, 3, 0, 0,  -- sectors
    0, 0, 214, 7,  -- total
    0, 112, 13, 0  -- used
})

return core.createConfigAPI({
    name = API_NAME,
    readCmd = 70,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
