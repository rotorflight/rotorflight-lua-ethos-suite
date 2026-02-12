--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local governor = {}
local math_floor = math.floor

function governor.wakeup()

    local telemetry = rfsuite.tasks.telemetry
    local value = telemetry and telemetry.getSensor("governor") or 0
    local displayValue = rfsuite.utils.getGovernorState(math_floor(value))
    rfsuite.session.toolbox.governor = displayValue

end

return governor
