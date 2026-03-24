--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local adjfunc = {}
local firstRun = true

local initTime = os.clock()
local ADJ_WAVS_PATH = "tasks/scheduler/adjfunctions/wavs.lua"

-- Localize globals
local os_clock = os.clock
local string_format = string.format
local table_concat = table.concat
local math_max = math.max
local math_floor = math.floor
local print = print
local tostring = tostring
local type = type
local loadfile = loadfile
local system_playNumber = system.playNumber

local DEBUG_SPEECH = false
local SPEAK_WAV_MS = 450
local SPEAK_NUM_MS = 600
local speakingUntil = 0
local adjWavsMap = nil
local adjWavsLoadFailed = false
local adjWavBuffer = {}

local function canSpeak(now) return now >= speakingUntil end

local function clearAdjWavBuffer()
    for i = #adjWavBuffer, 1, -1 do
        adjWavBuffer[i] = nil
    end
end

local function releaseAdjWavs()
    clearAdjWavBuffer()
    adjWavsMap = nil
end

local function loadAdjWavs()
    local chunk, err
    local ok, wavs

    if type(adjWavsMap) == "table" then
        return adjWavsMap
    end
    if adjWavsLoadFailed then
        return nil
    end

    chunk, err = loadfile(ADJ_WAVS_PATH)
    if not chunk then
        rfsuite.utils.log("Error loading adjfunctions wav map " .. ADJ_WAVS_PATH .. ": " .. tostring(err or "?"), "info")
        adjWavsLoadFailed = true
        return nil
    end

    ok, wavs = pcall(chunk)
    if not ok or type(wavs) ~= "table" then
        rfsuite.utils.log("Invalid adjfunctions wav map: " .. tostring(wavs or ADJ_WAVS_PATH), "info")
        adjWavsLoadFailed = true
        return nil
    end

    adjWavsMap = wavs
    return adjWavsMap
end

local function getAdjWavs(adjFuncId)
    local wavsMap = loadAdjWavs()
    local spec
    local count = 0
    local token

    clearAdjWavBuffer()

    if type(wavsMap) ~= "table" then
        return nil
    end

    spec = wavsMap[adjFuncId]
    if type(spec) == "string" then
        for token in spec:gmatch("[^%s]+") do
            count = count + 1
            adjWavBuffer[count] = token
        end
        if count > 0 then
            return adjWavBuffer
        end
        return nil
    end

    if type(spec) == "table" then
        for i = 1, #spec do
            count = count + 1
            adjWavBuffer[count] = spec[i]
        end
        if count > 0 then
            return adjWavBuffer
        end
    end

    return nil
end

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

        speakingUntil = math_max(speakingUntil + (SPEAK_NUM_MS / 1000.0), now + (SPEAK_NUM_MS / 1000.0))
    end
end

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
        local wavs = getAdjWavs(adjfuncAdjFunction)
        if wavs then
            if canSpeak(now) then
                speakWavs(adjfuncAdjFunction, wavs, now)
                speakNumber(adjfuncAdjValue, now)
                adjfuncPendingFuncAnnounce = false
                adjfuncAdjfuncIdChanged = false
                releaseAdjWavs()
            else

            end
        else

            adjfuncPendingFuncAnnounce = false
            releaseAdjWavs()
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
                local wavs = getAdjWavs(adjfuncAdjFunction)
                if wavs then
                    if canSpeak(now) then
                        speakWavs(adjfuncAdjFunction, wavs, now)
                        speakNumber(adjfuncAdjValue, now)
                        adjfuncPendingFuncAnnounce = false
                        releaseAdjWavs()
                    else

                    end
                else
                    adjfuncPendingFuncAnnounce = false
                    releaseAdjWavs()
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

function adjfunc.reset()
    firstRun = true
    initTime = os_clock()
    speakingUntil = 0
    adjWavsLoadFailed = false
    releaseAdjWavs()
    adjfuncAdjValue = nil
    adjfuncAdjFunction = nil
    adjfuncAdjValueOld = nil
    adjfuncAdjFunctionOld = nil
    adjfuncAdjfuncIdChanged = false
    adjfuncAdjfuncValueChanged = false
    adjfuncAdjJustUp = false
    adjfuncAdjJustUpCounter = nil
    adjfuncPendingFuncAnnounce = false
end

return adjfunc
