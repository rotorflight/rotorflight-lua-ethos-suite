--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local S_PAGES = {
    {name = "@i18n(app.modules.esc_motors.throttle)@", script = "throttle.lua", image = "throttle.png"},
    {name = "@i18n(app.modules.esc_motors.telemetry)@", script = "telemetry.lua", image = "telemetry.png"},
    {name = "@i18n(app.modules.esc_motors.rpm)@", script = "rpm.lua", image = "rpm.png"},
    {name = "@i18n(app.modules.esc_tools.name)@", script = "esc.lua", image = "esc.png"}
}

local prevConnectedState = nil
local initTime = os.clock()

return {
    title = "@i18n(app.modules.esc_motors.name)@",
    pages = S_PAGES,
    scriptPrefix = "esc_motors/tools/",
    iconPrefix = "app/modules/esc_motors/gfx/",
    loaderSpeed = 0.08,
    navOptions = {defaultSection = "hardware", showProgress = true},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    onOpenPost = function()
        rfsuite.app.triggers.closeProgressLoader = true
    end,
    onWakeup = function()
        if os.clock() - initTime < 0.25 then return end
        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
        if currState ~= prevConnectedState then
            if not currState and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["menu"] then
                rfsuite.app.formNavigationFields["menu"]:focus()
            end
            prevConnectedState = currState
        end
    end
}
