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

  * `craftName`, `modelID`, `apiVersion`, etc.

```lua
local name = rfsuite.session.craftName or "-"
```

### Tasks API

* **Check active**: `rfsuite.tasks.active()` returns `true` when rfsuite is initialized.

### Telemetry API

* **Get source**: `rfsuite.tasks.telemetry.getSensorSource(id)` returns a source object (if available).
* **Read value**: `source:value()` to fetch the latest reading.
* **Get value directly**: `rfsuite.tasks.telemetry.getSensor(id)` returns `(value, unit, minor)` and can optionally accept `min/max/thresholds` overrides.


```lua
local rfsuite = require("rfsuite")
local rpmSensor = rfsuite.tasks.telemetry.getSensorSource("rpm")
local rpm = rpmSensor and rpmSensor:value()
```

### MSP API

Use MSP to query the flight controller:

```lua
local rfsuite = require("rfsuite")
local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
API.setCompleteHandler(function(self, buf)
  local mode = API.readValue("gov_mode")
  -- process mode
end)
API.setUUID("550e8400-e29b-41d4-a716-446655440000")
API.read()
```

* **Queue check**: `rfsuite.tasks.msp.mspQueue:isProcessed()` to ensure no backlog.
* **Enqueue result**: MSP API `read()` / `write()` return queue status from `mspQueue:add(...)`:
  * `true, "queued", qid, pending`
  * `true, "queued_busy", qid, pending` (advisory pressure signal; request still queued)
  * `false, "duplicate", nil, pending`
  * `false, "busy", nil, pending` (only when hard cap is enabled)
* **Backoff guidance**:
  * Always set a stable UUID for periodic/retriggerable requests.
  * Treat `duplicate` / `busy` as explicit "back off and retry later".
  * For direct queue usage (outside API wrappers), check `ok, reason` and avoid advancing state when enqueue fails.

### Utilities

* **Logging**: `rfsuite.utils.log(message, level)` where `level` is `"info"` or `"debug"`.
* **Pause logging**: `rfsuite.utils.logPause()` temporarily suppresses logger writes.
* **Resume logging**: `rfsuite.utils.logResume()` re-enables logging.
* **Nested safety**: pause/resume is depth-counted; each `logPause()` must be matched by a `logResume()`.
* **Implementation detail**: pause state is owned by the scheduler logger task (`tasks/scheduler/logger/logger.lua`), while `utils` provides the public API.

```lua
local rfsuite = require("rfsuite")
rfsuite.utils.log("Headspeed: " .. rpm, "info")
```

```lua
-- Suppress log traffic in a CPU-heavy block
rfsuite.utils.logPause()
-- ...heavy work...
rfsuite.utils.logResume()
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
local rfsuite = require("rfsuite")

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
