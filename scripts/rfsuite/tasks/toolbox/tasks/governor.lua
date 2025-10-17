--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local governor = {}

function governor.wakeup()

    local value = rfsuite.tasks.telemetry and rfsuite.tasks.telemetry.getSensor("governor") or 0
    displayValue = rfsuite.utils.getGovernorState(math.floor(value))
    rfsuite.session.toolbox.governor = displayValue

end

return governor
