--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local osClock = os.clock
local sin = math.sin
local floor = math.floor

local function simulatorResponse()
    return core.writeS32(floor((100 + sin(osClock() * 1.2) * 40) * 100))
end

return core.createReadOnlyAPI({
    name = "ALTITUDE",
    readCmd = 109,
    fields = {
        "altitude_cm", "S32"
    },
    simulatorResponseRead = simulatorResponse
})
