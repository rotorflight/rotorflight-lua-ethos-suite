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
]] --
local object = {}


local armingDisableFlagsToString = rfsuite.app.utils.armingDisableFlagsToString
local telemetry = rfsuite.tasks.telemetry
local displayValue 


-- This function is called by toolbox.lua
-- it should return a string that will be used as the
-- value for the displayed object.  all rendering is handled
-- by toolbox.lua.  It is called once when lcd.invalidate() is called
function object.render(widget)
    return displayValue or "-"
end

-- This function is called in a loop by toolbox.lua
-- it should process anything that is needed for determining
-- what object.render does.  
function object.wakeup(widget)

    local value = telemetry and telemetry.getSensor("armflags")
    local disableflags = telemetry and telemetry.getSensor("armdisableflags")

    print(v)

    local showReason = false
    
    -- Try to use arm disable reason, if present and not "OK"
    if disableflags ~= nil and armingDisableFlagsToString then
        disableflags = math.floor(disableflags)
        local reason = armingDisableFlagsToString(disableflags)
        if reason and reason ~= "OK" then
            displayValue = reason
            showReason = true
        end
    end

    -- Fallback to ARMED/DISARMED state if no specific disable reason
    if not showReason then
        if value ~= nil then
            if value == 1 or value == 3 then
                displayValue = rfsuite.i18n.get("ARMED")
            else
                displayValue = rfsuite.i18n.get("DISARMED")
            end
        end
    end

    
end



return object
