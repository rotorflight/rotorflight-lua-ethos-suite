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

]]--
--
-- background processing of system tasks
--
local arg = {...}
local config = arg[1]
local currentRssiSensor

-- declare vars
local bg = {}
bg.init = true

bg.heartbeat = nil

bg.init = false
-- tasks
bg.telemetry = assert(loadfile("tasks/telemetry/telemetry.lua"))(config)
bg.msp = assert(loadfile("tasks/msp/msp.lua"))(config)
bg.adjfunctions = assert(loadfile("tasks/adjfunctions/adjfunctions.lua"))(config)
bg.sensors = assert(loadfile("tasks/sensors/sensors.lua"))(config)

bg.log_queue = {}


rfsuite.rssiSensorChanged = true

local rssiCheckScheduler = os.clock()
local lastRssiSensorName = nil

bg.wasOn = false

function bg.flush_logs()
    local max_lines_per_flush = 5

    if #bg.log_queue > 0 and rfsuite.bg.msp.mspQueue:isProcessed() then
    
        local f
            
        for i = 1, math.min(#bg.log_queue, max_lines_per_flush) do
            
            if rfsuite.config.logEnableScreen == true then print(bg.log_queue[1]) end
            
            if rfsuite.utils.ethosVersionToMinor() < 16 then
                f = io.open(config.suiteDir .. "/logs/rfsuite.log", 'a')
            else
                f = io.open("logs/rfsuite.log", 'a')
            end
            io.write(f, table.remove(bg.log_queue, 1) .. "\n")
            io.close(f)
       
        end
            
    end
end

function bg.active()

    if bg.heartbeat == nil then return false end

    if bg.heartbeat ~= nil and (os.clock() - bg.heartbeat) >= 2 then
        bg.wasOn = true
    else
        bg.wasOn = false
    end

    -- if msp is busy.. we are 100% ok
    if rfsuite.app.triggers.mspBusy == true then return true end

    -- if we have not run within 2 seconds.. notify that bg script is down
    if (os.clock() - bg.heartbeat) <= 2 then
        return true
    else
        return false
    end

end

function bg.wakeup()

    bg.heartbeat = os.clock()

    -- this should be before msp.hecks
    -- doing this is heavy - lets run it every few seconds only
    local now = os.clock()
    if rssiCheckScheduler ~= nil and (now - rssiCheckScheduler) >= 2 then
        currentRssiSensor = rfsuite.utils.getRssiSensor()

        if currentRssiSensor ~= nil then

            if lastRssiSensorName ~= currentRssiSensor.name then
                rfsuite.rssiSensorChanged = true
            else
                rfsuite.rssiSensorChanged = false
            end

            lastRssiSensorName = currentRssiSensor.name
            
        else
            rfsuite.rssiSensorChanged = false
        end
        rssiCheckScheduler = now
    end
    if system:getVersion().simulation == true then rfsuite.rssiSensorChanged = false end

    if currentRssiSensor ~= nil then
        rfsuite.rssiSensor = currentRssiSensor.sensor
    end    

    -- high priority and must alway run regardless of tlm state
    bg.msp.wakeup()
    bg.telemetry.wakeup()
    bg.sensors.wakeup()
    bg.adjfunctions.wakeup()
    bg.flush_logs()
end

function bg.event(widget, category, value)

    if bg.msp.event then bg.msp.event(widget, category, value) end
    if bg.adjfunctions.event then bg.adjfunctions.event(widget, category, value) end
end

return bg
