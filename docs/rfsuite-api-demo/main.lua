--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3.
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
 *
 * This script is a simple widget that shows how you can access various
 * session variables from Rotorflight.
]]--

local environment = system.getVersion()
local lastPrintTime = 0
local printInterval = 5

local apiValue = nil

local function create()
    -- Create the widget
    local widget = {}
    return widget
end

local function configure(widget)
    -- Configure the widget (called by Ethos forms)
end

local function paint(widget)
    -- Paint the widget (on screen)
end

local function wakeup(widget)
    -- Handle the main loop
    local currentTime = os.clock()

    if currentTime - lastPrintTime >= printInterval then
        if rfsuite and rfsuite.tasks.active() then
            -- Log Rotorflight session information
            rfsuite.utils.log("Craft Name: " .. (rfsuite.session.craftName or "-"), "info")
            rfsuite.utils.log("Model Id: " .. (rfsuite.session.modelID or "-"), "info")
            rfsuite.utils.log("API Version: " .. (rfsuite.session.apiVersion or "-"), "info")
            rfsuite.utils.log("Tail Mode: " .. (rfsuite.session.tailMode or "-"), "info")
            rfsuite.utils.log("Swash Mode: " .. (rfsuite.session.swashMode or "-"), "info")
            rfsuite.utils.log("Servo Count: " .. (rfsuite.session.servoCount or "-"), "info")
            rfsuite.utils.log("Governor Mode: " .. (rfsuite.session.governorMode or "-"), "info")

            -- Read telemetry sensors
            local armflags = rfsuite.tasks.telemetry.getSensorSource("armflags")
            rfsuite.utils.log("Arm Flags: " .. (armflags:value() or "-"), "info")

            local rpm = rfsuite.tasks.telemetry.getSensorSource("rpm")
            rfsuite.utils.log("Headspeed: " .. (rpm:value() or "-"), "info")

            local voltage = rfsuite.tasks.telemetry.getSensorSource("voltage")
            rfsuite.utils.log("Voltage: " .. (voltage:value() or "-"), "info")

            -- MSP API - this is and example how to use the API system to retrieve values from the fbl
            -- note.  It is sometimes usefull to consider using this call: 
            -- rfsuite.tasks.msp.mspQueue:isProcessed()
            -- to check if there is anything in the queue - especially if your code is a bit more syncronous
            if apiValue == nil then
                local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
                API.setCompleteHandler(function(self, buf)
                    local governorMode = API.readValue("gov_mode")
                    rfsuite.utils.log("API Value: " .. governorMode, "info")
                    apiValue = governorMode
                end)
                API.setUUID("550e8400-e29b-41d4-a716-446655440000")
                API.read()
            else
                rfsuite.utils.log("API Value: " .. (apiValue or "-"), "info")
            end
        else
            rfsuite.utils.log("Init...", "info")
        end

        lastPrintTime = currentTime
    end
end

local function init()
    -- Register the widget
    local key = "rfgbss"
    local name = "Rotorflight API Demo"

    system.registerWidget({
        key = key,
        name = name,
        create = create,
        configure = configure,
        paint = paint,
        wakeup = wakeup,
        read = read,
        write = write,
        event = event,
        menu = menu,
        persistent = false,
    })
end

return { init = init }
