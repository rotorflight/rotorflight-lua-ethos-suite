--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

return core.createWriteOnlyAPI({
    name = "SELECT_PROFILE",
    writeCmd = 210,
    fields = {
        {"profile", "U8"}
    },
    simulatorResponseWrite = {},
    writeUuidFallback = true
})
