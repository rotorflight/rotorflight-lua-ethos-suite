--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local app = rfsuite.app
local prefs = rfsuite.preferences
local tasks = rfsuite.tasks
local utils = rfsuite.utils
local session = rfsuite.session

local prevConnectedState = nil
local initTime = os.clock()
local focused = false

return {
    onOpenPost = function()
        focused = false
        if app.formFields then
            for i, v in pairs(app.formFields) do
                if v and v.enable then v:enable(false) end
            end
        end
    end,
    onWakeup = function()
        if os.clock() - initTime < 0.25 then return end

        if session.governorMode == nil then
            if tasks and tasks.msp and tasks.msp.helpers then
                tasks.msp.helpers.governorMode(function(governorMode)
                    utils.log("Received governor mode: " .. tostring(governorMode), "info")
                end)
            end
            return
        end

        if app.formFields then
            for i, v in pairs(app.formFields) do
                if v and v.enable then v:enable(true) end
            end
        end

        if not focused then
            focused = true
            local idx = tonumber(prefs.menulastselected["governor"]) or 1
            local btn = app.formFields and app.formFields[idx] or nil
            if btn and btn.focus then btn:focus() end
        end

        app.triggers.closeProgressLoader = true

        local currState = (session.isConnected and session.mcu_id) and true or false
        if currState ~= prevConnectedState then
            if app.formFields and app.formFields[2] and app.formFields[2].enable then
                app.formFields[2]:enable(currState)
            end
            if not currState and app.formNavigationFields and app.formNavigationFields["menu"] then
                app.formNavigationFields["menu"]:focus()
            end
            prevConnectedState = currState
        end
    end
}
