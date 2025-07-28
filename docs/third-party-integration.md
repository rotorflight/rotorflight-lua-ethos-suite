# 3rd Party widget hooks provided by rfsuite

This document explains the various hooks and APIs provided by **rfsuite** for developing widgets and extensions for Rotorflight. It covers the lifecycle functions you can implement, how to register your widget, and how to leverage the rfsuite session, tasks, telemetry, MSP, and utility APIs.

---

## Table of Contents

1. [rfsuite APIs](#rfsuite-apis)
2. [Example Widget](#example-widget)
3. [License](#license)

## rfsuite APIs

rfsuite exposes several subsystems under the global `rfsuite` table.

### Session Data

* **Access**: `rfsuite.session` contains read-only session info.

  * `craftName`, `modelID`, `apiVersion`, `tailMode`, `swashMode`, `servoCount`, `governorMode`, etc.

```lua
local name = rfsuite.session.craftName or "-"
```

### Tasks API

* **Check active**: `rfsuite.tasks.active()` returns `true` when rfsuite is initialized.

### Telemetry API

* **Get sensor**: `rfsuite.tasks.telemetry.getSensorSource(id)` returns a sensor object.
* **Read value**: `:value()` to fetch the latest reading.

or a faster and more efficient:

* **Get sensor**: `rfsuite.tasks.telemetry.getSensor(id)` returns a value of the sensor


```lua
local rpmSensor = rfsuite.tasks.telemetry.getSensorSource("rpm")
local rpm = rpmSensor:value()
```

### MSP API

Use MSP to query the flight controller:

```lua
local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
API.setCompleteHandler(function(self, buf)
  local mode = API.readValue("gov_mode")
  -- process mode
end)
API.setUUID("550e8400-e29b-41d4-a716-446655440000")
API.read()
```

* **Queue check**: `rfsuite.tasks.msp.mspQueue:isProcessed()` to ensure no backlog.

### Utilities

* **Logging**: `rfsuite.utils.log(message, level)` where `level` is `"info"`, `"warn"`, or `"error"`.

```lua
rfsuite.utils.log("Headspeed: " .. rpm, "info")
```

## Example Widget

Below is a widget that logs session info and telemetry every 5 seconds, using the full example code:

```lua
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

            -- MSP API - synchronous check example
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
```

## License

This widget framework is licensed under GPLv3. See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.en.html) for details.

This widget framework is licensed under GPLv3. See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.en.html) for details.
