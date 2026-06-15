--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

return core.createWriteOnlyAPI({
    name = "SET_SERVO_CONFIG",
    writeCmd = 212,
    fields = {
        {"index", "U8"},
        {"mid", "U16"},
        {"min", "U16"},
        {"max", "U16"},
        {"scale_neg", "U16"},
        {"scale_pos", "U16"},
        {"rate", "U16"},
        {"speed", "U16"},
        {"flags", "U16"}
    },
    simulatorResponseWrite = {},
    writeUuidFallback = true
})
