--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

return core.createWriteOnlyAPI({
    name = "COPY_PROFILE",
    writeCmd = 183,
    fields = {
        {"profile_type", "U8"},
        {"dest_profile", "U8"},
        {"source_profile", "U8"}
    },
    simulatorResponseWrite = {},
    writeUuidFallback = true
})
