--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local S_PAGES = {
    {name = "@i18n(app.modules.beepers.menu_configuration)@", script = "configuration.lua", image = "configuration.png"},
    {name = "@i18n(app.modules.beepers.menu_dshot)@", script = "dshot.lua", image = "dshot.png"}
}

local prevConnectedState = nil
local initTime = os.clock()
local prereqRequested = false
local prereqReady = false
local beepersConfigReady = false
local beepersFocused = false
local beepersConfigParsed = {}

local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = type(v) == "table" and copyTable(v) or v end
    return dst
end

local function setButtonsEnabled(enabled)
    for i = 1, #S_PAGES do
        local f = rfsuite.app.formFields and rfsuite.app.formFields[i]
        if f and f.enable then f:enable(enabled) end
    end
end

local function updateMenuAvailability()
    local connected = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
    local canOpen = prereqReady and connected

    setButtonsEnabled(canOpen)

    if canOpen and not beepersFocused then
        beepersFocused = true
        local idx = tonumber(rfsuite.preferences.menulastselected["beepers"]) or 1
        local btn = rfsuite.app.formFields and rfsuite.app.formFields[idx] or nil
        if btn and btn.focus then btn:focus() end
    end
end

local function onPrereqDone()
    prereqReady = beepersConfigReady
    if prereqReady then
        rfsuite.session.beepers = {
            config = copyTable(beepersConfigParsed or {}),
            ready = true
        }
        updateMenuAvailability()
        rfsuite.app.triggers.closeProgressLoader = true
    end
end

local function requestPrereqs()
    if prereqRequested then return end
    prereqRequested = true
    prereqReady = false
    beepersConfigReady = false
    beepersFocused = false
    beepersConfigParsed = {}

    local API = rfsuite.tasks.msp.api.load("BEEPER_CONFIG")
    API.setUUID("beepers-menu-config")
    API.setCompleteHandler(function()
        local d = API.data()
        beepersConfigParsed = copyTable((d and d.parsed) or {})
        beepersConfigReady = true
        onPrereqDone()
    end)
    API.setErrorHandler(function()
        beepersConfigParsed = {}
        beepersConfigReady = true
        onPrereqDone()
    end)
    API.read()
end

return {
    title = "@i18n(app.modules.beepers.name)@",
    pages = S_PAGES,
    scriptPrefix = "beepers/tools/",
    iconPrefix = "app/modules/beepers/gfx/",
    loaderSpeed = rfsuite.app.loaderSpeed.DEFAULT,
    navOptions = {defaultSection = "hardware"},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = true},
    onOpenPost = function()
        prereqRequested = false
        setButtonsEnabled(false)
        requestPrereqs()
    end,
    onWakeup = function()
        if os.clock() - initTime < 0.25 then return end

        if not prereqRequested then requestPrereqs() end
        updateMenuAvailability()

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
        if currState ~= prevConnectedState then
            if not currState and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["menu"] then
                rfsuite.app.formNavigationFields["menu"]:focus()
            end
            prevConnectedState = currState
        end
    end
}
