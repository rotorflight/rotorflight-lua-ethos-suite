--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local switches = {}

local switchTable = {switches = {}, units = {}}

local lastPlayTime = {}
local lastSwitchState = {}
local switchStartTime = nil

local validCache = {}
local lastValidityCheck = {}
local VALIDITY_RECHECK_SEC = 5
local initialized = false

local os_clock = os.clock
local system_playNumber = system.playNumber

local function initializeSwitches()
    local prefs = rfsuite.preferences.switches
    if not prefs then return end

    for key, v in pairs(prefs) do
        if v then
            local scategory, smember = v:match("([^,]+),([^,]+)")
            scategory = tonumber(scategory)
            smember = tonumber(smember)
            if scategory and smember then switchTable.switches[key] = system.getSource({category = scategory, member = smember}) end
        end
    end

    switchTable.units = rfsuite.tasks.telemetry.listSensorAudioUnits()
    initialized = true
end

function switches.wakeup()
    local now = os_clock()

    if not initialized then initializeSwitches() end
    if next(switchTable.switches) == nil then return end

    if not switchStartTime then switchStartTime = now end

    if (now - switchStartTime) <= 5 then return end

    local flightmode = rfsuite.flightmode
    local mode = (flightmode and flightmode.current) or nil
    local allowRecheck = (mode == "preflight")
    local telemetry = rfsuite.tasks.telemetry

    for key, sensor in pairs(switchTable.switches) do

        local isValid = validCache[key]
        local lastChk = lastValidityCheck[key] or 0

        if isValid == nil or (allowRecheck and (now - lastChk) >= VALIDITY_RECHECK_SEC) then
            -- sensor:state() returns boolean for validity/active state on some sources
            -- optimization: call only when needed
            local s = sensor:state() 
            validCache[key] = (s == true)
            lastValidityCheck[key] = now
        end

        local currentState = validCache[key] == true
        if not currentState then goto continue end

        local prevState = lastSwitchState[key] or false
        local lastTime = lastPlayTime[key] or 0
        local playNow = false

        if not prevState or (now - lastTime) >= 10 then playNow = true end

        if playNow then
            local sensorSrc = telemetry.getSensorSource(key)
            if sensorSrc then
                local value = sensorSrc:value()
                if value and type(value) == "number" then
                    local unit = switchTable.units[key]
                    local decimals = tonumber(sensorSrc:decimals())
                    system_playNumber(value, unit, decimals)
                    lastPlayTime[key] = now
                end
            end
        end

        lastSwitchState[key] = currentState
        ::continue::
    end
end

function switches.reset()
    switchTable.switches = {}
    lastPlayTime = {}
    lastSwitchState = {}
    switchStartTime = nil
    validCache = {}
    lastValidityCheck = {}
    initialized = false
end

switches.switchTable = switchTable

return switches
