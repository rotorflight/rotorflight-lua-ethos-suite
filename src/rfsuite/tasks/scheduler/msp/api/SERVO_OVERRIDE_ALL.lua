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
    name = "SERVO_OVERRIDE_ALL",
    writeCmd = 196,
    fields = {
        {"value", "U16"}
    },
    simulatorResponseWrite = {},
    writeUuidFallback = true
})
