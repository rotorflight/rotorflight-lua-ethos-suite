--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local prevConnectedState = nil
local initTime = os.clock()

return {
    title = "@i18n(app.modules.rates_advanced.name)@",
    pages = {
        {name = "@i18n(app.modules.rates_advanced.advanced)@", script = "advanced.lua", image = "advanced.png"},
        {name = "@i18n(app.modules.rates_advanced.table)@", script = "table.lua", image = "table.png"}
    },
    scriptPrefix = "rates_advanced/tools/",
    iconPrefix = "app/modules/rates_advanced/gfx/",
    loaderSpeed = rfsuite.app.loaderSpeed.DEFAULT,
    navOptions = {defaultSection = "advanced", showProgress = true},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
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
