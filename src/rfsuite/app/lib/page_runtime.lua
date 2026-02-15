--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local runtime = {}

local function shouldHandleClose(category, value)
    return (category == EVT_CLOSE and value == 0) or value == 35
end

function runtime.openMenuContext(opts)
    local options = opts or {}
    local ui = rfsuite.app.ui
    ui.openMenuContext(options.defaultSection, options.showProgress, options.progressSpeed)
end

function runtime.handleCloseEvent(category, value, opts)
    if shouldHandleClose(category, value) then
        local options = opts or {}
        if type(options.onClose) == "function" then
            options.onClose()
        else
            runtime.openMenuContext(options)
        end
        return true
    end
    return false
end

function runtime.createMenuHandlers(opts)
    local options = opts or {}

    local function onNavMenu()
        if type(options.onNavMenu) == "function" then
            options.onNavMenu()
        else
            runtime.openMenuContext(options)
        end
        return true
    end

    local function event(_, category, value)
        return runtime.handleCloseEvent(category, value, options)
    end

    return {
        onNavMenu = onNavMenu,
        event = event
    }
end

return runtime
