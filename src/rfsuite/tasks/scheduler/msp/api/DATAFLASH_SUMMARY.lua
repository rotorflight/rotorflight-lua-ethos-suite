--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "DATAFLASH_SUMMARY"

local FIELD_SPEC = {
    "flags", "U8",
    "sectors", "U32",
    "total", "U32",
    "used", "U32"
}

local SIM_RESPONSE = core.simResponse({
    3,             -- flags
    235, 3, 0, 0,  -- sectors
    0, 0, 214, 7,  -- total
    0, 112, 13, 0  -- used
})

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 70,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
