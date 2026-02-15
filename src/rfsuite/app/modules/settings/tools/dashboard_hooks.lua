--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local prevConnectedState = nil
local initTime = os.clock()

return {
    title = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.dashboard)@",
    moduleKey = "settings_dashboard",
    scriptPrefix = "settings/tools/",
    iconPrefix = "app/modules/settings/gfx/",
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    pages = {
        {name = "@i18n(app.modules.settings.dashboard_theme)@", script = "dashboard_theme.lua", image = "dashboard_theme.png"},
        {name = "@i18n(app.modules.settings.dashboard_settings)@", script = "dashboard_settings.lua", image = "dashboard_settings.png"}
    },
    navOptions = {showProgress = true},
    onWakeup = function()
        if os.clock() - initTime < 0.25 then return end

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
        if currState ~= prevConnectedState then
            if rfsuite.app.formFields and rfsuite.app.formFields[2] and rfsuite.app.formFields[2].enable then
                rfsuite.app.formFields[2]:enable(currState)
            end
            if not currState and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["menu"] then
                rfsuite.app.formNavigationFields["menu"]:focus()
            end
            prevConnectedState = currState
        end
    end
}
