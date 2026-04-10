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

-- Flat field spec:
--   field name, type
local FIELD_SPEC = {
    "U_ID_0", "U32",
    "U_ID_1", "U32",
    "U_ID_2", "U32"
}

local SIM_RESPONSE = core.simResponse({
    43, 0, 34, 0, -- U_ID_0
    9, 81, 51, 52, -- U_ID_1
    52, 56, 53, 49 -- U_ID_2
})

return core.createReadOnlyAPI({
    name = "UID",
    readCmd = 160,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE
})
