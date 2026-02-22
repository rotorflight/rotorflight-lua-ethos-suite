--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local adjfunc = {}
local firstRun = true

local initTime = os.clock()

-- Localize globals
local os_clock = os.clock
local string_format = string.format
local table_concat = table.concat
local math_max = math.max
local math_floor = math.floor
local print = print
local tostring = tostring
local system_playNumber = system.playNumber

local DEBUG_SPEECH = false
local SPEAK_WAV_MS = 450
local SPEAK_NUM_MS = 600
local speakingUntil = 0

local function canSpeak(now) return now >= speakingUntil end

local function speakWavs(adjFuncId, wavs, now)
    if not wavs or #wavs == 0 then return end
    local utils = rfsuite.utils
    local playFile = utils and utils.playFile

    if DEBUG_SPEECH then
        local files = {}
        for i = 1, #wavs do files[i] = wavs[i] .. ".wav" end
        print(string_format("[DEBUG] adjfunc %d will play: %s", adjFuncId, table_concat(files, ", ")))
    end

    if playFile then
        for i = 1, #wavs do playFile("adjfunctions", wavs[i] .. ".wav") end
    end

    speakingUntil = now + ((SPEAK_WAV_MS * #wavs) / 1000.0)
end

local function speakNumber(n, now)
    if system_playNumber then
        if DEBUG_SPEECH then print(string_format("[DEBUG] playNumber: %s", tostring(n))) end
        system_playNumber(n)

        speakingUntil = math_max(speakingUntil, now + (SPEAK_NUM_MS / 1000.0))
    end
end

local adjWavs = {
    [5] = {"pitch", "rate"},
    [6] = {"roll", "rate"},
    [7] = {"yaw", "rate"},
    [8] = {"pitch", "rc", "rate"},
    [9] = {"roll", "rc", "rate"},
    [10] = {"yaw", "rc", "rate"},
    [11] = {"pitch", "rc", "expo"},
    [12] = {"roll", "rc", "expo"},
    [13] = {"yaw", "rc", "expo"},
    [14] = {"pitch", "p", "gain"},
    [15] = {"pitch", "i", "gain"},
    [16] = {"pitch", "d", "gain"},
    [17] = {"pitch", "f", "gain"},
    [18] = {"roll", "p", "gain"},
    [19] = {"roll", "i", "gain"},
    [20] = {"roll", "d", "gain"},
    [21] = {"roll", "f", "gain"},
    [22] = {"yaw", "p", "gain"},
    [23] = {"yaw", "i", "gain"},
    [24] = {"yaw", "d", "gain"},
    [25] = {"yaw", "f", "gain"},
    [26] = {"yaw", "cw", "gain"},
    [27] = {"yaw", "ccw", "gain"},
    [28] = {"yaw", "cyclic", "ff"},
    [29] = {"yaw", "collective", "ff"},
    [30] = {"yaw", "collective", "dyn"},
    [31] = {"yaw", "collective", "decay"},
    [32] = {"pitch", "collective", "ff"},
    [33] = {"pitch", "gyro", "cutoff"},
    [34] = {"roll", "gyro", "cutoff"},
    [35] = {"yaw", "gyro", "cutoff"},
    [36] = {"pitch", "dterm", "cutoff"},
    [37] = {"roll", "dterm", "cutoff"},
    [38] = {"yaw", "dterm", "cutoff"},
    [39] = {"rescue", "climb", "collective"},
    [40] = {"rescue", "hover", "collective"},
    [41] = {"rescue", "hover", "alt"},
    [42] = {"rescue", "alt", "p", "gain"},
    [43] = {"rescue", "alt", "i", "gain"},
    [44] = {"rescue", "alt", "d", "gain"},
    [45] = {"angle", "level", "gain"},
    [46] = {"horizon", "level", "gain"},
    [47] = {"acro", "gain"},
    [48] = {"gov", "gain"},
    [49] = {"gov", "p", "gain"},
    [50] = {"gov", "i", "gain"},
    [51] = {"gov", "d", "gain"},
    [52] = {"gov", "f", "gain"},
    [53] = {"gov", "tta", "gain"},
    [54] = {"gov", "cyclic", "ff"},
    [55] = {"gov", "collective", "ff"},
    [56] = {"pitch", "b", "gain"},
    [57] = {"roll", "b", "gain"},
    [58] = {"yaw", "b", "gain"},
    [59] = {"pitch", "o", "gain"},
    [60] = {"roll", "o", "gain"},
    [61] = {"crossc", "gain"},
    [62] = {"crossc", "ratio"},
    [63] = {"crossc", "cutoff"},
    [64] = {"acc", "pitch", "trim"},
    [65] = {"acc", "roll", "trim"},
    [66] = {"yaw", "inertia", "precomp", "gain"},
    [67] = {"yaw", "inertia", "precomp", "cutoff"},
    [68] = {"pitch", "setpoint", "boost", "gain"},
    [69] = {"roll", "setpoint", "boost", "gain"},
    [70] = {"yaw", "setpoint", "boost", "gain"},
    [71] = {"collective", "setpoint", "boost", "gain"},
    [72] = {"yaw", "dyn", "ceiling", "gain"},
    [73] = {"yaw", "dyn", "deadband", "gain"},
    [74] = {"yaw", "dyn", "deadband", "filter"},
    [75] = {"yaw", "precomp", "cutoff"}
}

local adjfuncAdjValue = nil
local adjfuncAdjFunction = nil
local adjfuncAdjValueOld = nil
local adjfuncAdjFunctionOld = nil

local adjfuncAdjfuncIdChanged = false
local adjfuncAdjfuncValueChanged = false
local adjfuncAdjJustUp = false
local adjfuncAdjJustUpCounter
local adjfuncPendingFuncAnnounce = false

function adjfunc.wakeup()
    local now = os_clock()
    local prefs = rfsuite.preferences
    local events = prefs and prefs.events
    if not (events and (events.adj_f or events.adj_v)) then return end
    if (now - initTime) < 5 then return end

    local telemetry = rfsuite.tasks.telemetry
    if not telemetry then return end

    adjfuncAdjValue = telemetry.getSensor("adj_v")
    adjfuncAdjFunction = telemetry.getSensor("adj_f")
    if adjfuncAdjValue == nil or adjfuncAdjFunction == nil then return end

    if type(adjfuncAdjValue) == "number" then adjfuncAdjValue = math_floor(adjfuncAdjValue) end
    if type(adjfuncAdjFunction) == "number" then adjfuncAdjFunction = math_floor(adjfuncAdjFunction) end

    adjfuncAdjfuncIdChanged = (adjfuncAdjFunction ~= adjfuncAdjFunctionOld)
    adjfuncAdjfuncValueChanged = (adjfuncAdjValue ~= adjfuncAdjValueOld)

    if adjfuncPendingFuncAnnounce and not firstRun and events.adj_f then
        local wavs = adjWavs[adjfuncAdjFunction]
        if wavs then
            if canSpeak(now) then
                speakWavs(adjfuncAdjFunction, wavs, now)
                adjfuncPendingFuncAnnounce = false
                adjfuncAdjfuncIdChanged = false
            else

            end
        else

            adjfuncPendingFuncAnnounce = false
        end
    end

    if adjfuncAdjfuncIdChanged then adjfuncPendingFuncAnnounce = true end

    if adjfuncAdjJustUp == true then
        adjfuncAdjJustUpCounter = (adjfuncAdjJustUpCounter or 0) + 1
        adjfuncAdjfuncIdChanged = false
        adjfuncAdjfuncValueChanged = false
        if adjfuncAdjJustUpCounter == 10 then adjfuncAdjJustUp = false end
    else
        if adjfuncAdjFunction ~= 0 then
            adjfuncAdjJustUpCounter = 0

            if adjfuncPendingFuncAnnounce and not firstRun and events.adj_f then
                local wavs = adjWavs[adjfuncAdjFunction]
                if wavs then
                    if canSpeak(now) then
                        speakWavs(adjfuncAdjFunction, wavs, now)
                        adjfuncPendingFuncAnnounce = false
                    else

                    end
                else
                    adjfuncPendingFuncAnnounce = false
                end
            end

            if (adjfuncAdjfuncValueChanged or adjfuncAdjfuncIdChanged) then
                if (adjfuncAdjValue ~= nil) and (not firstRun) and events.adj_v then
                    if canSpeak(now) then
                        speakNumber(adjfuncAdjValue, now)
                        adjfuncAdjfuncValueChanged = false
                        firstRun = false
                    else

                    end
                else
                    adjfuncAdjfuncValueChanged = false
                    firstRun = false
                end
            end
        end
    end

    adjfuncAdjValueOld = adjfuncAdjValue
    adjfuncAdjFunctionOld = adjfuncAdjFunction
end

return adjfunc
