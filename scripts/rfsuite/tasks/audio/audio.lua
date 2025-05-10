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

-- constants for voltage alert
local voltageSource

-- constants for low fuel
local fuelSource

-- constants for governor alert
local governorSource
local governorMap = {
    [0] = "off.wav",
    [1] = "idle.wav",
    [2] = "spoolup.wav",
    [3] = "recovery.wav",
    [4] = "active.wav",
    [5] = "thr-off.wav",
    [6] = "lost-hs.wav",
    [7] = "autorot.wav",
    [8] = "bailout.wav",
    [100] = "disabled.wav",
    [101] = "disarmed.wav"    
}
local lastGovernorValue = nil

-- constants for arming alert
local armSource
local lastArmValue 
local armMap = {
    [0] = "disarmed.wav",
    [1] = "armed.wav",
    [2] = "disarmed.wav",
    [3] = "armed.wav"
}

-- constants for rates and profiles
local rateSource
local profileSource
local lastRateValue = nil
local lastProfileValue = nil

function audio.wakeup()
    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then
        return
    end

    local session = rfsuite.session

    -- *************************************************************
    -- * Arming alerts
    -- *************************************************************
    if not armSource then
       armSource = rfsuite.tasks.telemetry.getSensorSource("armflags")
    end
    local armValue = armSource:value()
    if armValue ~= nil and armValue ~= lastArmValue then
        rfsuite.utils.log(
            string.format("Arming alert: %s", armMap[math.floor(armValue)]),
            "info"
        )
        rfsuite.utils.playFile("events", "alerts/" .. armMap[math.floor(armValue)])
        lastArmValue = armValue

        return
    end

    -- we do not play alerts for events that cannot have any meaning if not armed
    if armSource and armValue == 1 or armValue == 3 then

        -- *************************************************************
        -- * Governor alerts
        -- *************************************************************
        if session.governorMode then
            if not governorSource then
                governorSource = rfsuite.tasks.telemetry.getSensorSource("governor")
            end
            local governorValue = governorSource:value()
            if governorValue ~= nil and governorValue ~= lastGovernorValue then
                rfsuite.utils.log(
                    string.format("Governor alert: %s", governorMap[math.floor(governorValue)]),
                    "info"
                )
                rfsuite.utils.playFile("events", "gov/" .. governorMap[math.floor(governorValue)])
                lastGovernorValue = governorValue

                return
            end
        else
            -- no governor mode → clear state so we re-create everything later
            lastGovernorValue = nil
            governorSource    = nil    
        end

        -- *************************************************************
        -- * Fuel alert
        -- *************************************************************
        if session.batteryConfig then
            -- lazy-init (or re-create) the fuel source here
            if not fuelSource then
                fuelSource = rfsuite.tasks.telemetry.getSensorSource("fuel")
            end

            local fuelValue = fuelSource:value()
            local now = os.clock()  -- Use os.clock() for elapsed time in seconds

            if fuelValue and fuelValue < session.batteryConfig.consumptionWarningPercentage then
                -- Initialize or check timer
                if not session._lowFuelAlertLastPlayed or (now - session._lowFuelAlertLastPlayed) >= 10 then
                    rfsuite.utils.log(
                        string.format("Low fuel alert: %.2f%%", fuelValue),
                        "info"
                    )
                    rfsuite.utils.playFile("events", "alerts/lowfuel.wav")
                    session._lowFuelAlertLastPlayed = now

                    return
                end
            else
                -- Reset the alert timestamp when fuel level recovers
                session._lowFuelAlertLastPlayed = nil
            end
        end  

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
                        rfsuite.utils.playFile("events", "alerts/lowvoltage.wav")

                        session._lastLowAlertTime = now

                        return
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


    -- *************************************************************
    -- * Profile alerts
    -- *************************************************************
    if not profileSource then
       profileSource = rfsuite.tasks.telemetry.getSensorSource("pid_profile")
    end
    local profileValue = profileSource:value()
    if profileValue ~= nil and profileValue ~= lastprofileValue then
        rfsuite.utils.playFile("events", "alerts/profile.wav")
        system.playNumber(profileValue)
        lastprofileValue = profileValue

        return
    end    

    -- *************************************************************
    -- * Rate alerts
    -- *************************************************************
    if not rateSource then
       rateSource = rfsuite.tasks.telemetry.getSensorSource("rate_profile")
    end
    local rateValue = rateSource:value()
    if rateValue ~= nil and rateValue ~= lastRateValue then
        rfsuite.utils.playFile("events", "alerts/rates.wav")
        system.playNumber(rateValue)
        lastRateValue = rateValue

        return
    end


end

return audio
