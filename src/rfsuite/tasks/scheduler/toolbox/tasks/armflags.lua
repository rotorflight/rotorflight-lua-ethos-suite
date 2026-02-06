--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local armflags = {}

local math_floor = math.floor

function armflags.wakeup()

    local telemetry = rfsuite.tasks.telemetry
    local value = telemetry and telemetry.getSensor("armflags")
    local disableflags = telemetry and telemetry.getSensor("armdisableflags")

    local showReason = false
    local displayValue

    if disableflags ~= nil then
        disableflags = math_floor(disableflags)
        local reason = rfsuite.utils.armingDisableFlagsToString(disableflags)
        if reason and reason ~= "OK" then
            displayValue = reason
            showReason = true
        end
    end

    if not showReason then
        if value ~= nil then
            if value == 1 or value == 3 then
                displayValue = "@i18n(widgets.governor.ARMED)@"
            else
                displayValue = "@i18n(widgets.governor.DISARMED)@"
            end
        end
    end

    rfsuite.session.toolbox.armflags = displayValue

end

return armflags
