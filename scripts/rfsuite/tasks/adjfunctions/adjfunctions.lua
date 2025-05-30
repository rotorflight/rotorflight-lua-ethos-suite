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

]] --
local arg = {...}

local config = arg[1]

local adjfunc = {}
local firstRun = true

local initTime = os.clock()

--[[
adjFunctionsTable - A table containing adjustable functions for various parameters.

Each entry in the table represents a specific adjustable function with the following structure:
    idXX = {
        name = "Descriptive Name",
        wavs = {"wav1", "wav2", ...}
    }

Categories of adjustable functions:
- Rates:
    id5  - Pitch Rate
    id6  - Roll Rate
    id7  - Yaw Rate
    id8  - Pitch RC Rate
    id9  - Roll RC Rate
    id10 - Yaw RC Rate
    id11 - Pitch RC Expo
    id12 - Roll RC Expo
    id13 - Yaw RC Expo

- PIDs:
    id14 - Pitch P Gain
    id15 - Pitch I Gain
    id16 - Pitch D Gain
    id17 - Pitch F Gain
    id18 - Roll P Gain
    id19 - Roll I Gain
    id20 - Roll D Gain
    id21 - Roll F Gain
    id22 - Yaw P Gain
    id23 - Yaw I Gain
    id24 - Yaw D Gain
    id25 - Yaw F Gain
    id26 - Yaw CW Gain
    id27 - Yaw CCW Gain
    id28 - Yaw Cyclic FF
    id29 - Yaw Coll FF
    id30 - Yaw Coll Dyn
    id31 - Yaw Coll Decay
    id32 - Pitch Coll FF

- Gyro Cutoffs:
    id33 - Pitch Gyro Cutoff
    id34 - Roll Gyro Cutoff
    id35 - Yaw Gyro Cutoff

- D-term Cutoffs:
    id36 - Pitch D-term Cutoff
    id37 - Roll D-term Cutoff
    id38 - Yaw D-term Cutoff

- Rescue:
    id39 - Rescue Climb Coll
    id40 - Rescue Hover Coll
    id41 - Rescue Hover Alt
    id42 - Rescue Alt P Gain
    id43 - Rescue Alt I Gain
    id44 - Rescue Alt D Gain

- Leveling:
    id45 - Angle Level Gain
    id46 - Horizon Level Gain
    id47 - Acro Trainer Gain

- Governor:
    id48 - Governor Gain
    id49 - Governor P Gain
    id50 - Governor I Gain
    id51 - Governor D Gain
    id52 - Governor F Gain
    id53 - Governor TTA Gain
    id54 - Governor Cyclic FF
    id55 - Governor Coll FF

- Boost Gains:
    id56 - Pitch B Gain
    id57 - Roll B Gain
    id58 - Yaw B Gain

- Offset Gains:
    id59 - Pitch O Gain
    id60 - Roll O Gain

- Cross-Coupling:
    id61 - Cross Coup Gain
    id62 - Cross Coup Ratio
    id63 - Cross Coup Cutoff

- Accelerometer:
    id64 - Accelerometer Pitch Trim
    id65 - Accelerometer Roll Trim
]]
local adjFunctionsTable = {
    -- rates
    id5 = {name = "Pitch Rate", wavs = {"pitch", "rate"}},
    id6 = {name = "Roll Rate", wavs = {"roll", "rate"}},
    id7 = {name = "Yaw Rate", wavs = {"yaw", "rate"}},
    id8 = {name = "Pitch RC Rate", wavs = {"pitch", "rc", "rate"}},
    id9 = {name = "Roll RC Rate", wavs = {"roll", "rc", "rate"}},
    id10 = {name = "Yaw RC Rate", wavs = {"yaw", "rc", "rate"}},
    id11 = {name = "Pitch RC Expo", wavs = {"pitch", "rc", "expo"}},
    id12 = {name = "Roll RC Expo", wavs = {"roll", "rc", "expo"}},
    id13 = {name = "Yaw RC Expo", wavs = {"yaw", "rc", "expo"}},

    -- pids
    id14 = {name = "Pitch P Gain", wavs = {"pitch", "p", "gain"}},
    id15 = {name = "Pitch I Gain", wavs = {"pitch", "i", "gain"}},
    id16 = {name = "Pitch D Gain", wavs = {"pitch", "d", "gain"}},
    id17 = {name = "Pitch F Gain", wavs = {"pitch", "f", "gain"}},
    id18 = {name = "Roll P Gain", wavs = {"roll", "p", "gain"}},
    id19 = {name = "Roll I Gain", wavs = {"roll", "i", "gain"}},
    id20 = {name = "Roll D Gain", wavs = {"roll", "d", "gain"}},
    id21 = {name = "Roll F Gain", wavs = {"roll", "f", "gain"}},
    id22 = {name = "Yaw P Gain", wavs = {"yaw", "p", "gain"}},
    id23 = {name = "Yaw I Gain", wavs = {"yaw", "i", "gain"}},
    id24 = {name = "Yaw D Gain", wavs = {"yaw", "d", "gain"}},
    id25 = {name = "Yaw F Gain", wavs = {"yaw", "f", "gain"}},

    id26 = {name = "Yaw CW Gain", wavs = {"yaw", "cw", "gain"}},
    id27 = {name = "Yaw CCW Gain", wavs = {"yaw", "ccw", "gain"}},
    id28 = {name = "Yaw Cyclic FF", wavs = {"yaw", "cyclic", "ff"}},
    id29 = {name = "Yaw Coll FF", wavs = {"yaw", "collective", "ff"}},
    id30 = {name = "Yaw Coll Dyn", wavs = {"yaw", "collective", "dyn"}},
    id31 = {name = "Yaw Coll Decay", wavs = {"yaw", "collective", "decay"}},
    id32 = {name = "Pitch Coll FF", wavs = {"pitch", "collective", "ff"}},

    -- gyro cutoffs
    id33 = {name = "Pitch Gyro Cutoff", wavs = {"pitch", "gyro", "cutoff"}},
    id34 = {name = "Roll Gyro Cutoff", wavs = {"roll", "gyro", "cutoff"}},
    id35 = {name = "Yaw Gyro Cutoff", wavs = {"yaw", "gyro", "cutoff"}},

    -- dterm cutoffs
    id36 = {name = "Pitch D-term Cutoff", wavs = {"pitch", "dterm", "cutoff"}},
    id37 = {name = "Roll D-term Cutoff", wavs = {"roll", "dterm", "cutoff"}},
    id38 = {name = "Yaw D-term Cutoff", wavs = {"yaw", "dterm", "cutoff"}},

    -- rescue
    id39 = {name = "Rescue Climb Coll", wavs = {"rescue", "climb", "collective"}},
    id40 = {name = "Rescue Hover Coll", wavs = {"rescue", "hover", "collective"}},
    id41 = {name = "Rescue Hover Alt", wavs = {"rescue", "hover", "alt"}},
    id42 = {name = "Rescue Alt P Gain", wavs = {"rescue", "alt", "p", "gain"}},
    id43 = {name = "Rescue Alt I Gain", wavs = {"rescue", "alt", "i", "gain"}},
    id44 = {name = "Rescue Alt D Gain", wavs = {"rescue", "alt", "d", "gain"}},

    -- leveling
    id45 = {name = "Angle Level Gain", wavs = {"angle", "level", "gain"}},
    id46 = {name = "Horizon Level Gain", wavs = {"horizon", "level", "gain"}},
    id47 = {name = "Acro Trainer Gain", wavs = {"acro", "gain"}},

    -- governor
    id48 = {name = "Governor Gain", wavs = {"gov", "gain"}},
    id49 = {name = "Governor P Gain", wavs = {"gov", "p", "gain"}},
    id50 = {name = "Governor I Gain", wavs = {"gov", "i", "gain"}},
    id51 = {name = "Governor D Gain", wavs = {"gov", "d", "gain"}},
    id52 = {name = "Governor F Gain", wavs = {"gov", "f", "gain"}},
    id53 = {name = "Governor TTA Gain", wavs = {"gov", "tta", "gain"}},
    id54 = {name = "Governor Cyclic FF", wavs = {"gov", "cyclic", "ff"}},
    id55 = {name = "Governor Coll FF", wavs = {"gov", "collective", "ff"}},

    -- boost gains
    id56 = {name = "Pitch B Gain", wavs = {"pitch", "b", "gain"}},
    id57 = {name = "Roll B Gain", wavs = {"roll", "b", "gain"}},
    id58 = {name = "Yaw B Gain", wavs = {"yaw", "b", "gain"}},

    -- offset gains
    id59 = {name = "Pitch O Gain", wavs = {"pitch", "o", "gain"}},
    id60 = {name = "Roll O Gain", wavs = {"roll", "o", "gain"}},

    -- cross-coupling
    id61 = {name = "Cross Coup Gain", wavs = {"crossc", "gain"}},
    id62 = {name = "Cross Coup Ratio", wavs = {"crossc", "ratio"}},
    id63 = {name = "Cross Coup Cutoff", wavs = {"crossc", "cutoff"}},

    -- accelerometer
    id64 = {name = "Accelerometer Pitch Trim", wavs = {"acc", "pitch", "trim"}},
    id65 = {name = "Accelerometer Roll Trim", wavs = {"acc", "roll", "trim"}},

    -- Yaw Inertia precomp
    id66 = { name = "Yaw Inertia Precomp Gain", wavs = {"yaw","inertia","precomp","gain"}},
    id67 = { name = "Yaw Inertia Precomp Cutoff", wavs = {"yaw","inertia","precomp","cutoff"}},

    -- Setpoint boost
    id68 = { name = "Pitch Setpoint Boost Gain", wavs = { "pitch", "setpoint", "boost", "gain" }},
    id69 = { name = "Roll Setpoint Boost Gain", wavs = {"roll", "setpoint", "boost", "gain"}},
    id70 = { name = "Yaw Setpoint Boost Gain", wavs = {"yaw", "setpoint", "boost", "gain"}},
    id71 = { name = "Collective Setpoint Boost Gain", wavs = {"collective", "setpoint", "boost", "gain"}},

    -- Yaw dynamic deadband
    id72 = { name = "Yaw Dynamic Ceiling Gain", wavs = {"yaw", "dyn", "ceiling", "gain"} },
    id73 = { name = "Yaw Dynamic Deadband Gain", wavs = {"yaw", "dyn", "deadband", "gain"} },
    id74 = { name = "Yaw Dynamic Deadband Filter", wavs = {"yaw", "dyn", "deadband", "filter"} },

    -- Precomp cutoff
    id75 = { name = "Yaw Precomp Cutoff", wavs = {"yaw", "precomp", "cutoff"} },

}

-- adjfuncAdjValueSrc: Source of the adjustment value.
-- adjfuncAdjFunctionSrc: Source of the adjustment function.
-- adjfuncAdjValue: Current adjustment value.
-- adjfuncAdjFunction: Current adjustment function.
-- adjfuncAdjValueOld: Previous adjustment value.
-- adjfuncAdjFunctionOld: Previous adjustment function.
-- adjfuncAdjTimer: Timer to track adjustment function execution time.
-- adjfuncAdjfuncIdChanged: Flag indicating if the adjustment function ID has changed.
-- adjfuncAdjfuncValueChanged: Flag indicating if the adjustment function value has changed.
-- adjfuncAdjJustUp: Flag indicating if the adjustment function was just incremented.
local adjfuncAdjValueSrc = nil
local adjfuncAdjFunctionSrc = nil
local adjfuncAdjValue = nil
local adjfuncAdjFunction = nil
local adjfuncAdjValueOld = nil
local adjfuncAdjFunctionOld = nil
local adjfuncAdjTimer = os.clock()
local adjfuncAdjfuncIdChanged = false
local adjfuncAdjfuncValueChanged = false
local adjfuncAdjJustUp = false

--[[
    Function: adjfunc.wakeup
    Description: This function is responsible for handling the wakeup process of the adjfunc module. It checks various conditions and updates the state of the adjfunc module based on sensor values and preferences.
    
    Conditions:
    - If both adjFunctionAlerts and adjValueAlerts preferences are false, the function returns early.
    - If the rssiSensor is nil, the function returns early.
    - If less than 5 seconds have passed since initTime or telemetry is not active, the function returns early.

    Process:
    - Retrieves sensor sources for "adjF" and "adjV".
    - Updates adjValue and adjFunction based on sensor values.
    - Checks if adjValue and adjFunction have changed and sets corresponding flags.
    - Handles the adjJustUp state and its counter.
    - If adjFunction is not zero, processes adjFunction and adjValue changes, plays alerts if necessary, and updates the adjTimer.

    Variables:
    - adjfuncAdjFunctionSrc: Source for adjFunction sensor.
    - adjfuncAdjValueSrc: Source for adjValue sensor.
    - adjfuncAdjValue: Current value of adjValue sensor.
    - adjfuncAdjFunction: Current value of adjFunction sensor.
    - adjfuncAdjValueOld: Previous value of adjValue sensor.
    - adjfuncAdjFunctionOld: Previous value of adjFunction sensor.
    - adjfuncAdjfuncIdChanged: Flag indicating if adjFunction has changed.
    - adjfuncAdjfuncValueChanged: Flag indicating if adjValue has changed.
    - adjfuncAdjJustUp: Flag indicating if adjFunction was just activated.
    - adjfuncAdjJustUpCounter: Counter for adjJustUp state.
    - adjfuncAdjTimer: Timer for adjFunction processing.
    - firstRun: Flag indicating if this is the first run of the function.
]]
function adjfunc.wakeup()

    if rfsuite.session.onConnect.low then
        return
    end

    -- do not run the remaining code
    if rfsuite.preferences.events.adj_f == false and rfsuite.preferences.events.adj_v == false then return end

    if (os.clock() - initTime) < 5  then return end

    -- getSensor source has a cache built in - win
    adjfuncAdjFunctionSrc = rfsuite.tasks.telemetry.getSensorSource("adj_f")
    adjfuncAdjValueSrc = rfsuite.tasks.telemetry.getSensorSource("adj_v")

    if adjfuncAdjValueSrc ~= nil and adjfuncAdjFunctionSrc ~= nil then

        adjfuncAdjValue = adjfuncAdjValueSrc:value()
        adjfuncAdjFunction = adjfuncAdjFunctionSrc:value()

        if adjfuncAdjValue ~= nil then if type(adjfuncAdjValue) == "number" then adjfuncAdjValue = math.floor(adjfuncAdjValue) end end
        if adjfuncAdjFunction ~= nil then if type(adjfuncAdjFunction) == "number" then adjfuncAdjFunction = math.floor(adjfuncAdjFunction) end end

        if adjfuncAdjFunction ~= adjfuncAdjFunctionOld then adjfuncAdjfuncIdChanged = true end
        if adjfuncAdjValue ~= adjfuncAdjValueOld then adjfuncAdjfuncValueChanged = true end

        if adjfuncAdjJustUp == true then
            adjfuncAdjJustUpCounter = adjfuncAdjJustUpCounter + 1
            adjfuncAdjfuncIdChanged = false
            adjfuncAdjfuncValueChanged = false

            if adjfuncAdjJustUpCounter == 10 then adjfuncAdjJustUp = false end

        else
            if adjfuncAdjFunction ~= 0 then
                adjfuncAdjJustUpCounter = 0
                if (os.clock() - adjfuncAdjTimer >= 2) then

                    if adjfuncAdjfuncIdChanged == true then

                        local tgt = "id" .. tostring(adjfuncAdjFunction)
         
                        local adjfunction = adjFunctionsTable[tgt]
                        if adjfunction ~= nil and firstRun == false then 
                            for wavi, wavv in ipairs(adjfunction.wavs) do 
                                if rfsuite.preferences.events.adj_f == true then 
                                    rfsuite.utils.playFile("adjfunctions", wavv .. ".wav") 
                                end 
                            end 
                        end
                        adjfuncAdjfuncIdChanged = false
                    end
                    if adjfuncAdjfuncValueChanged == true or adjfuncAdjfuncIdChanged == true then

                        if adjfuncAdjValue ~= nil and firstRun == false then if rfsuite.preferences.events.adj_v == true then system.playNumber(adjfuncAdjValue) end end

                        adjfuncAdjfuncValueChanged = false

                        firstRun = false
                    end
                    adjfuncAdjTimer = os.clock()
                end
            end
        end

        adjfuncAdjValueOld = adjfuncAdjValue
        adjfuncAdjFunctionOld = adjfuncAdjFunction

    end
end

return adjfunc