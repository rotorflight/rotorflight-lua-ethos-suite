--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local escToolsPage = {}

function escToolsPage.createSubmenuHandlers(folder)
    local function onNavMenu()
        pageRuntime.openMenuContext({defaultSection = "system"})
        return true
    end

    local function event(_, category, value)
        return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
    end

    return {
        onNavMenu = onNavMenu,
        event = event,
        navButtons = {menu = true, save = true, reload = true, tool = false, help = false}
    }
end

return escToolsPage
