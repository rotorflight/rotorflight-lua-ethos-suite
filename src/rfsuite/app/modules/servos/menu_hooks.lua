--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MENU_ID = {PWM = 1, BUS = 2}

local prevConnectedState = nil
local fieldFocusSet = false
local chainInFlight = false

local function requestServoInfoChain()
    if chainInFlight then return end
    if not (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers) then return end

    local msp = rfsuite.tasks.msp
    local session = rfsuite.session

    if session.servoCount == nil then
        chainInFlight = true
        msp.helpers.servoCount(function(servoCount)
            rfsuite.utils.log("Received servo count: " .. tostring(servoCount), "info")
            chainInFlight = false
            requestServoInfoChain()
        end)
        return
    end

    if session.servoOverride == nil then
        chainInFlight = true
        msp.helpers.servoOverride(function(servoOverride)
            rfsuite.utils.log("Received servo override: " .. tostring(servoOverride), "info")
            chainInFlight = false
            requestServoInfoChain()
        end)
        return
    end

    if session.tailMode == nil or session.swashMode == nil then
        chainInFlight = true
        msp.helpers.mixerConfig(function(tailMode, swashMode)
            rfsuite.utils.log("Received tail mode: " .. tostring(tailMode), "info")
            rfsuite.utils.log("Received swash mode: " .. tostring(swashMode), "info")
            chainInFlight = false
            requestServoInfoChain()
        end)
        return
    end

    if session.servoBusEnabled == nil then
        chainInFlight = true
        msp.helpers.servoBusEnabled(function(servoBusEnabled)
            rfsuite.utils.log("Received servo bus enabled: " .. tostring(servoBusEnabled), "info")
            chainInFlight = false
            requestServoInfoChain()
        end)
        return
    end
end

return {
    onOpenPost = function()
        fieldFocusSet = false
        chainInFlight = false
        if rfsuite.app.formFields then
            for i, v in pairs(rfsuite.app.formFields) do
                if v and v.enable then v:enable(false) end
            end
        end
    end,
    onWakeup = function()
        requestServoInfoChain()

        if not fieldFocusSet and
            rfsuite.session.servoCount ~= nil and
            rfsuite.session.servoOverride ~= nil and
            rfsuite.session.tailMode ~= nil and
            rfsuite.session.swashMode ~= nil and
            rfsuite.session.servoBusEnabled ~= nil then

            if rfsuite.app.formFields[MENU_ID.PWM] then
                rfsuite.app.formFields[MENU_ID.PWM]:enable(true)
                if rfsuite.preferences.menulastselected["servos_type"] == MENU_ID.PWM then
                    rfsuite.app.formFields[MENU_ID.PWM]:focus()
                end
            end

            if rfsuite.utils.apiVersionCompare(">", "12.08") and
                rfsuite.app.formFields[MENU_ID.BUS] and
                rfsuite.session.servoBusEnabled == true then
                rfsuite.app.formFields[MENU_ID.BUS]:enable(true)
                if rfsuite.preferences.menulastselected["servos_type"] == MENU_ID.BUS then
                    rfsuite.app.formFields[MENU_ID.BUS]:focus()
                end
            end

            rfsuite.app.triggers.closeProgressLoader = true
            fieldFocusSet = true
        end

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
        if currState ~= prevConnectedState then
            if not currState and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["menu"] then
                rfsuite.app.formNavigationFields["menu"]:focus()
            end
            prevConnectedState = currState
        end
    end
}
