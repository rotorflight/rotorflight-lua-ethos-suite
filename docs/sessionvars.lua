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

local lastPrintTime = 0  -- Store the last time the debug was printed
local printInterval = 2   -- Interval in seconds

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
            -- Useful info
            print("Craft Name: " .. (rfsuite.session.craftName or "-"))
            print("Model Id: " .. (rfsuite.session.modelID or "-"))
			print("API Version: " .. (rfsuite.session.apiVersion or "-"))
			print("Tail Mode: " .. (rfsuite.session.tailMode or "-"))
			print("Swash Mode: " .. (rfsuite.session.swashMode or "-"))
			print("Servo count: " .. (rfsuite.session.servoCount or "-"))
			print("Governor mode: " .. (rfsuite.session.governorMode or "-"))

            -- Get a sensor source regardless of protocol
            -- You can see sensor names in rfsuite/tasks/telemetry/telemetry.lua 
            -- Look at the sensorTable
            local armflags = rfsuite.tasks.telemetry.getSensorSource("armflags")
            print("Arm Flags: " .. (armflags:value() or "-"))

            local rpm = rfsuite.tasks.telemetry.getSensorSource("rpm")
            print("Headspeed: " .. (rpm:value() or "-"))

            local voltage = rfsuite.tasks.telemetry.getSensorSource("voltage")
            print("Voltage: " .. (voltage:value() or "-"))
        else
            print("Init...")
        end

        lastPrintTime = currentTime -- Update the last print time
    end

    return
end


local function init()
	-- this is where we 'setup' the widget
	
	local key = "rfgbss"			        -- unique key - keep it less that 8 chars
	local name = "Rotorflight Sessions"		-- name of widget

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
