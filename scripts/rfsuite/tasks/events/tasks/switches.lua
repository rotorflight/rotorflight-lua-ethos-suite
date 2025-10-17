--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local switches = {}

local switchTable = {switches = {}, units = {}}

local lastPlayTime = {}
local lastSwitchState = {}
local switchStartTime = nil

local validCache = {}
local lastValidityCheck = {}
local VALIDITY_RECHECK_SEC = 5

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
end

function switches.wakeup()
    local now = os.clock()

    if next(switchTable.switches) == nil then initializeSwitches() end

    if not switchStartTime then switchStartTime = now end

    if (now - switchStartTime) <= 5 then return end

    local mode = (rfsuite and rfsuite.flightmode and rfsuite.flightmode.current) or nil
    local allowRecheck = (mode == "preflight")

    for key, sensor in pairs(switchTable.switches) do

        local isValid = validCache[key]
        local lastChk = lastValidityCheck[key] or 0
        local needCheck = (isValid == nil) or (allowRecheck and (now - lastChk) >= VALIDITY_RECHECK_SEC)

        if needCheck then

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
            local sensorSrc = rfsuite.tasks.telemetry.getSensorSource(key)
            if sensorSrc then
                local value = sensorSrc:value()
                if value and type(value) == "number" then
                    local unit = switchTable.units[key]
                    local decimals = tonumber(sensorSrc:decimals())
                    system.playNumber(value, unit, decimals)
                    lastPlayTime[key] = now
                end
            end
        end

        lastSwitchState[key] = currentState
        ::continue::
    end
end

function switches.resetSwitchStates()
    switchTable.switches = {}
    lastPlayTime = {}
    lastSwitchState = {}
    switchStartTime = nil
    validCache = {}
    lastValidityCheck = {}
end

switches.switchTable = switchTable

return switches
