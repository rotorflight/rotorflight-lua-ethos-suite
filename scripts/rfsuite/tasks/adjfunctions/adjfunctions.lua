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
adjfunc.adjFunctionsTable - A table containing adjustable functions for various parameters.

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
adjfunc.adjFunctionsTable = {
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
    id65 = {name = "Accelerometer Roll Trim", wavs = {"acc", "roll", "trim"}}

}


--[[
Initializes various adjustment function variables to nil or default values.
adjValueSrc: Source of the adjustment value.
adjFunctionSrc: Source of the adjustment function.
adjValue: Current adjustment value.
adjFunction: Current adjustment function.
adjValueOld: Previous adjustment value.
adjFunctionOld: Previous adjustment function.
adjTimer: Timer for adjustment functions, initialized with the current clock time.
adjfuncIdChanged: Boolean flag indicating if the adjustment function ID has changed.
adjfuncValueChanged: Boolean flag indicating if the adjustment value has changed.
adjJustUp: Boolean flag indicating if the adjustment was just increased.
]]
adjfunc.adjValueSrc = nil
adjfunc.adjFunctionSrc = nil
adjfunc.adjValue = nil
adjfunc.adjFunction = nil
adjfunc.adjValueOld = nil
adjfunc.adjFunctionOld = nil
adjfunc.adjTimer = os.clock()
adjfunc.adjfuncIdChanged = false
adjfunc.adjfuncValueChanged = false
adjfunc.adjJustUp = false

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
    - adjfunc.adjFunctionSrc: Source for adjFunction sensor.
    - adjfunc.adjValueSrc: Source for adjValue sensor.
    - adjfunc.adjValue: Current value of adjValue sensor.
    - adjfunc.adjFunction: Current value of adjFunction sensor.
    - adjfunc.adjValueOld: Previous value of adjValue sensor.
    - adjfunc.adjFunctionOld: Previous value of adjFunction sensor.
    - adjfunc.adjfuncIdChanged: Flag indicating if adjFunction has changed.
    - adjfunc.adjfuncValueChanged: Flag indicating if adjValue has changed.
    - adjfunc.adjJustUp: Flag indicating if adjFunction was just activated.
    - adjfunc.adjJustUpCounter: Counter for adjJustUp state.
    - adjfunc.adjTimer: Timer for adjFunction processing.
    - firstRun: Flag indicating if this is the first run of the function.
]]
function adjfunc.wakeup()

    -- do not run the remaining code
    if rfsuite.preferences.adjFunctionAlerts == false and rfsuite.preferences.adjValueAlerts == false then return end

    if rfsuite.session.rssiSensor == nil then return end

    if (os.clock() - initTime) < 5 or rfsuite.tasks.telemetry.active() == false then return end


    adjfunc.adjFunctionSrc = rfsuite.tasks.telemetry.getSensorSource("adjF")
    adjfunc.adjValueSrc = rfsuite.tasks.telemetry.getSensorSource("adjV")

    if adjfunc.adjValueSrc ~= nil and adjfunc.adjFunctionSrc ~= nil then

        adjfunc.adjValue = adjfunc.adjValueSrc:value()
        adjfunc.adjFunction = adjfunc.adjFunctionSrc:value()

        if adjfunc.adjValue ~= nil then if type(adjfunc.adjValue) == "number" then adjfunc.adjValue = math.floor(adjfunc.adjValue) end end
        if adjfunc.adjFunction ~= nil then if type(adjfunc.adjFunction) == "number" then adjfunc.adjFunction = math.floor(adjfunc.adjFunction) end end

        if adjfunc.adjFunction ~= adjfunc.adjFunctionOld then adjfunc.adjfuncIdChanged = true end
        if adjfunc.adjValue ~= adjfunc.adjValueOld then adjfunc.adjfuncValueChanged = true end

        if adjfunc.adjJustUp == true then
            adjfunc.adjJustUpCounter = adjfunc.adjJustUpCounter + 1
            adjfunc.adjfuncIdChanged = false
            adjfunc.adjfuncValueChanged = false

            if adjfunc.adjJustUpCounter == 10 then adjfunc.adjJustUp = false end

        else
            if adjfunc.adjFunction ~= 0 then
                adjfunc.adjJustUpCounter = 0
                if (os.clock() - adjfunc.adjTimer >= 2) then
                    if adjfunc.adjfuncIdChanged == true then

                        local tgt = "id" .. tostring(adjfunc.adjFunction)
                        local adjfunction = adjfunc.adjFunctionsTable[tgt]
                        if adjfunction ~= nil and firstRun == false then for wavi, wavv in ipairs(adjfunction.wavs) do if rfsuite.preferences.adjFunctionAlerts == true then rfsuite.utils.playFile("adjfunctions", wavv .. ".wav") end end end
                        adjfunc.adjfuncIdChanged = false
                    end
                    if adjfunc.adjfuncValueChanged == true or adjfunc.adjfuncIdChanged == true then

                        if adjfunc.adjValue ~= nil and firstRun == false then if rfsuite.preferences.adjValueAlerts == true then system.playNumber(adjfunc.adjValue) end end

                        adjfunc.adjfuncValueChanged = false

                        firstRun = false
                    end
                    adjfunc.adjTimer = os.clock()
                end
            end
        end

        adjfunc.adjValueOld = adjfunc.adjValue
        adjfunc.adjFunctionOld = adjfunc.adjFunction

    end
end

return adjfunc
