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

 * This task watches telemetry sensors and general state of the system
 * and triggers audio alerts when certain conditions are met.

]] --


local arg = {...}

local audio = {}

function audio.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then
        return
    end

    local session = rfsuite.session

    -- *************************************************************
    -- * Battery voltage alert
    -- *************************************************************
    if session.batteryConfig then
        -- init our per-call state vars if needed
        session._lowVoltageStart  = session._lowVoltageStart  or nil
        session._lastLowAlertTime = session._lastLowAlertTime or 0

        -- lazy-init (or re-create) the voltage source here
        if not voltageSource then
            voltageSource = rfsuite.tasks.telemetry.getSensorSource("voltage")
        end

        local cellCount       = session.batteryConfig.batteryCellCount
        local warnVoltPerCell = session.batteryConfig.vbatwarningcellvoltage
        local totalVoltage    = voltageSource:value()   -- already in volts

        if totalVoltage and cellCount and warnVoltPerCell then
            local cellVoltage = totalVoltage / cellCount
            local now         = os.time()
            
            if cellVoltage < warnVoltPerCell then
                -- mark when we first dipped below threshold
                if not session._lowVoltageStart then
                    session._lowVoltageStart = now
                end

                -- after 2s low, and only once every 10s
                if now - session._lowVoltageStart >= 2
                   and now - session._lastLowAlertTime >= 10 then

                    rfsuite.utils.log(
                        string.format("Low voltage alert: %.2f V per cell", cellVoltage),
                        "info"
                    )
                    rfsuite.utils.playFile("status", "alerts/lowvoltage.wav")

                    session._lastLowAlertTime = now
                end
            else
                -- recovered: reset timers and force re-init next time
                session._lowVoltageStart  = nil
                session._lastLowAlertTime = 0
                voltageSource = nil
            end
        end

    else
        -- no config → clear state so we re-create everything later
        session._lowVoltageStart  = nil
        session._lastLowAlertTime = 0
        voltageSource             = nil
    end
end


return audio
