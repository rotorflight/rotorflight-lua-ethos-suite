--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local prevConnectedState = nil
local initTime = os.clock()
local focused = false
local mixerCompatibilityStatus = false

local MIXER_PITCH_RATE
local MIXER_PITCH_MIN
local MIXER_PITCH_MAX
local MIXER_ROLL_RATE
local MIXER_ROLL_MIN
local MIXER_ROLL_MAX
local MIXER_COLLECTIVE_RATE
local MIXER_COLLECTIVE_MIN
local MIXER_COLLECTIVE_MAX

local function u16_to_s16(u)
    if u == nil then return nil end
    if u >= 0x8000 then return u - 0x10000 end
    return u
end

local function getMixerCompatibilityStatus()
    local PAPI = rfsuite.tasks.msp.api.load("GET_MIXER_INPUT_PITCH")
    PAPI.setCompleteHandler(function()
        MIXER_PITCH_RATE = u16_to_s16(PAPI.readValue("rate_stabilized_pitch"))
        MIXER_PITCH_MIN = u16_to_s16(PAPI.readValue("min_stabilized_pitch"))
        MIXER_PITCH_MAX = u16_to_s16(PAPI.readValue("max_stabilized_pitch"))
    end)
    PAPI.setUUID("d8163617-1496-4886-8b81-GET_MIXER_INPUT_PITCH")
    PAPI.read()

    local RAPI = rfsuite.tasks.msp.api.load("GET_MIXER_INPUT_ROLL")
    RAPI.setCompleteHandler(function()
        MIXER_ROLL_RATE = u16_to_s16(RAPI.readValue("rate_stabilized_roll"))
        MIXER_ROLL_MIN = u16_to_s16(RAPI.readValue("min_stabilized_roll"))
        MIXER_ROLL_MAX = u16_to_s16(RAPI.readValue("max_stabilized_roll"))
    end)
    RAPI.setUUID("d8163617-1496-4886-8b81-GET_MIXER_INPUT_ROLL")
    RAPI.read()

    local CAPI = rfsuite.tasks.msp.api.load("GET_MIXER_INPUT_COLLECTIVE")
    CAPI.setCompleteHandler(function()
        MIXER_COLLECTIVE_RATE = u16_to_s16(CAPI.readValue("rate_stabilized_collective"))
        MIXER_COLLECTIVE_MIN = u16_to_s16(CAPI.readValue("min_stabilized_collective"))
        MIXER_COLLECTIVE_MAX = u16_to_s16(CAPI.readValue("max_stabilized_collective"))
    end)
    CAPI.setUUID("d8163617-1496-4886-8b81-GET_MIXER_INPUT_COLLECTIVE")
    CAPI.read()
end

local function mixerInputsAreCompatible()
    if MIXER_ROLL_RATE == nil or MIXER_ROLL_MIN == nil or MIXER_ROLL_MAX == nil or
        MIXER_PITCH_RATE == nil or MIXER_PITCH_MIN == nil or MIXER_PITCH_MAX == nil or
        MIXER_COLLECTIVE_RATE == nil or MIXER_COLLECTIVE_MIN == nil or MIXER_COLLECTIVE_MAX == nil then
        return false
    end

    local customConfig = false
    if (MIXER_ROLL_RATE ~= MIXER_PITCH_RATE) and (MIXER_ROLL_RATE ~= -MIXER_PITCH_RATE) then customConfig = true end
    if MIXER_ROLL_MAX ~= MIXER_PITCH_MAX then customConfig = true end
    if MIXER_ROLL_MIN ~= MIXER_PITCH_MIN then customConfig = true end
    if MIXER_ROLL_MAX ~= -MIXER_ROLL_MIN then customConfig = true end
    if MIXER_PITCH_MAX ~= -MIXER_PITCH_MIN then customConfig = true end
    if MIXER_COLLECTIVE_MAX ~= -MIXER_COLLECTIVE_MIN then customConfig = true end
    return not customConfig
end

return {
    onOpenPost = function()
        focused = false
        mixerCompatibilityStatus = false
        MIXER_PITCH_RATE = nil
        MIXER_PITCH_MIN = nil
        MIXER_PITCH_MAX = nil
        MIXER_ROLL_RATE = nil
        MIXER_ROLL_MIN = nil
        MIXER_ROLL_MAX = nil
        MIXER_COLLECTIVE_RATE = nil
        MIXER_COLLECTIVE_MIN = nil
        MIXER_COLLECTIVE_MAX = nil

        if rfsuite.app.formFields then
            for i, v in pairs(rfsuite.app.formFields) do
                if v and v.enable then v:enable(false) end
            end
        end

        if rfsuite.utils.apiVersionCompare(">=", "12.09") then getMixerCompatibilityStatus() end
    end,
    onWakeup = function()
        if os.clock() - initTime < 0.25 then return end

        if rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil then
            if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then
                rfsuite.tasks.msp.helpers.mixerConfig(function(tailMode, swashMode)
                    rfsuite.utils.log("Received tail mode: " .. tostring(tailMode), "info")
                    rfsuite.utils.log("Received swash mode: " .. tostring(swashMode), "info")
                end)
            end
            return
        end

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
        local enable = currState

        if rfsuite.app.formFields then
            if rfsuite.utils.apiVersionCompare(">=", "12.09") then
                if MIXER_PITCH_RATE ~= nil and MIXER_PITCH_MIN ~= nil and MIXER_PITCH_MAX ~= nil and
                    MIXER_ROLL_RATE ~= nil and MIXER_ROLL_MIN ~= nil and MIXER_ROLL_MAX ~= nil and
                    MIXER_COLLECTIVE_RATE ~= nil and MIXER_COLLECTIVE_MIN ~= nil and MIXER_COLLECTIVE_MAX ~= nil then
                    local ok = mixerInputsAreCompatible()
                    if ok ~= mixerCompatibilityStatus then mixerCompatibilityStatus = ok end
                    enable = ok and currState
                else
                    enable = false
                end
            end

            for i, v in pairs(rfsuite.app.formFields) do
                if v and v.enable then v:enable(enable) end
            end

            if enable and not focused then
                focused = true
                local idx = tonumber(rfsuite.preferences.menulastselected["mixer"]) or 1
                local btn = rfsuite.app.formFields and rfsuite.app.formFields[idx] or nil
                if btn and btn.focus then btn:focus() end
            end
        end

        rfsuite.app.triggers.closeProgressLoader = true

        if currState ~= prevConnectedState then
            if not currState and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["menu"] then
                rfsuite.app.formNavigationFields["menu"]:focus()
            end
            prevConnectedState = currState
        end
    end
}
