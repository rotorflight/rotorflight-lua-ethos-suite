--[[
  Toolbar action: reset flight mode
]] --

local rfsuite = require("rfsuite")
local M = {}

local function applyReset()
    local tasks = rfsuite and rfsuite.tasks
    if tasks and tasks.events and tasks.events.flightmode and type(tasks.events.flightmode.reset) == "function" then
        tasks.events.flightmode.reset()
    end
    if rfsuite and rfsuite.flightmode then
        rfsuite.flightmode.current = "preflight"
    end
    local dashboard = rfsuite and rfsuite.widgets and rfsuite.widgets.dashboard
    if dashboard then
        dashboard.flightmode = "preflight"
    end
    if lcd and lcd.invalidate then
        lcd.invalidate()
    end
end

function M.resetFlightModeAsk()
    local buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()
                applyReset()
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }

    form.openDialog({width = nil, title = "@i18n(widgets.dashboard.reset_flight_ask_title)@", message = "@i18n(widgets.dashboard.reset_flight_ask_text)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
end

function M.wakeup()
    return
end

function M.reset()
    return
end

return M
