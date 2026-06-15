--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "SDCARD_SUMMARY"

local FIELD_SPEC = {
    "flags", "U8",
    "state", "U8",
    "filesystemLastError", "U8",
    "freeSizeKB", "U32",
    "totalSizeKB", "U32"
}

local SIM_RESPONSE = core.simResponse({
    0, -- flags
    0, -- state
    0, -- filesystemLastError
    0, 0, 0, 0, -- freeSizeKB
    0, 0, 0, 0  -- totalSizeKB
})

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 79,
    fields = FIELD_SPEC,
    simulatorResponseRead = SIM_RESPONSE,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
