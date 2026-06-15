--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

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
