--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 
 
 * This script is a simple widget that shows how you can access various
 * session variables from rotorflight.

]] --
 
local environment = system.getVersion()

local lastPrintTime = 0  -- Store the last time the debug was rfsuite.utils.loged
local printInterval = 5   -- Interval in seconds

local apiValue = nil

local function create()
    -- this is where we create the widget
	local widget = {}
    return widget 
end

local function configure(widget)
    -- this is where we configure the widget
end

local function paint(widget)
    -- this is where we paint the widget
end

local function wakeup(widget)
    -- this is where we handle the main loop

    local currentTime = os.clock() -- Get the current time in seconds

    if currentTime - lastPrintTime >= printInterval then
        if rfsuite and rfsuite.tasks.active() then

            -- We have a number of session vars you can access
            -- These are set by the rotorflight system and are available to you
            rfsuite.utils.log("Craft Name: " .. (rfsuite.session.craftName or "-"),"info")
            rfsuite.utils.log("Model Id: " .. (rfsuite.session.modelID or "-"),"info")
			rfsuite.utils.log("API Version: " .. (rfsuite.session.apiVersion or "-"),"info")
			rfsuite.utils.log("Tail Mode: " .. (rfsuite.session.tailMode or "-"),"info")
			rfsuite.utils.log("Swash Mode: " .. (rfsuite.session.swashMode or "-"),"info")
			rfsuite.utils.log("Servo count: " .. (rfsuite.session.servoCount or "-"),"info")
			rfsuite.utils.log("Governor mode: " .. (rfsuite.session.governorMode or "-"),"info")

            -- Get a sensor source regardless of protocol
            -- You can see sensor names in rfsuite/tasks/telemetry/telemetry.lua 
            -- Look at the sensorTable
            local armflags = rfsuite.tasks.telemetry.getSensorSource("armflags")
            rfsuite.utils.log("Arm Flags: " .. (armflags:value() or "-"),"info")

            local rpm = rfsuite.tasks.telemetry.getSensorSource("rpm")
            rfsuite.utils.log("Headspeed: " .. (rpm:value() or "-"),"info")

            local voltage = rfsuite.tasks.telemetry.getSensorSource("voltage")
            rfsuite.utils.log("Voltage: " .. (voltage:value() or "-"),"info")

            -- perform an api request via msp
            if (apiValue == nil) then
                local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG","SCRIPTS:/rfsuite/tasks/msp/api/")
                API.setCompleteHandler(function(self, buf)
                    local governorMode = API.readValue("gov_mode")
                    rfsuite.utils.log("Api value: " .. governorMode, "info")
                    apiValue = governorMode
                end)
                API.setUUID("550e8400-e29b-41d4-a716-446655440000")
                API.read()
            else
                rfsuite.utils.log("Api value: " .. (apiValue or "-"), "info")    
            end   


        else
            rfsuite.utils.log("Init...","info")
        end

        lastPrintTime = currentTime -- Update the last rfsuite.utils.log time
    end

    return
end


local function init()
	-- this is where we 'setup' the widget
	
	local key = "rfgbss"			        -- unique key - keep it less that 8 chars
	local name = "Rotorflight API Demo"		-- name of widget

    system.registerWidget(
        {
            key = key,					-- unique project id
            name = name,				-- name of widget
            create = create,			-- function called when creating widget
            configure = configure,		-- function called when configuring the widget (use ethos forms)
            paint = paint,				-- function called when lcd.invalidate() is called
            wakeup = wakeup,			-- function called as the main loop
            read = read,				-- function called when starting widget and reading configuration params
            write = write,				-- function called when saving values / changing values in the configuration menu
			event = event,				-- function called when buttons or screen clips occur
			menu = menu,				-- function called to add items to the menu
			persistent = false,			-- true or false to make the widget carry values between sessions and models (not safe imho)
        }
    )

end

return {init = init}
