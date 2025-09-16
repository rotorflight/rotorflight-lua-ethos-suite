--[[ 
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local arg = { ... }
local config = arg[1]

local armflags = {}

function armflags.wakeup()

    local value = rfsuite.tasks.telemetry and rfsuite.tasks.telemetry.getSensor("armflags")
    local disableflags = rfsuite.tasks.telemetry and rfsuite.tasks.telemetry.getSensor("armdisableflags")

    
    local showReason = false
    
    -- Try to use arm disable reason, if present and not "OK"
    if disableflags ~= nil then
        disableflags = math.floor(disableflags)
        local reason = rfsuite.utils.armingDisableFlagsToString(disableflags)
        if reason and reason ~= "OK" then
            displayValue = reason
            showReason = true
        end
    end

    -- Fallback to ARMED/DISARMED state if no specific disable reason
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
