--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local S_PAGES = {
    {name = "@i18n(app.modules.blackbox.menu_configuration)@", script = "configuration.lua", image = "configuration.png"},
    {name = "@i18n(app.modules.blackbox.menu_logging)@", script = "logging.lua", image = "logging.png"},
    {name = "@i18n(app.modules.blackbox.menu_status)@", script = "status.lua", image = "status.png"}
}

local prevConnectedState = nil
local initTime = os.clock()
local prereqRequested = false
local prereqReady = false
local featureConfigReady = false
local blackboxConfigReady = false
local blackboxSupported = false
local blackboxFocused = false
local featureBitmap = 0
local blackboxConfigParsed = {}

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
    local canOpen = prereqReady and connected and blackboxSupported

    setButtonsEnabled(canOpen)

    if canOpen and not blackboxFocused then
        blackboxFocused = true
        local idx = tonumber(rfsuite.preferences.menulastselected["blackbox"]) or 1
        local btn = rfsuite.app.formFields and rfsuite.app.formFields[idx] or nil
        if btn and btn.focus then btn:focus() end
    end
end

local function onPrereqDone()
    prereqReady = featureConfigReady and blackboxConfigReady
    if prereqReady then
        rfsuite.session.blackbox = {
            feature = {enabledFeatures = featureBitmap},
            config = copyTable(blackboxConfigParsed or {}),
            ready = blackboxSupported
        }
        updateMenuAvailability()
        rfsuite.app.triggers.closeProgressLoader = true
    end
end

local function requestBlackboxPrereqs()
    if prereqRequested then return end
    prereqRequested = true
    prereqReady = false
    featureConfigReady = false
    blackboxConfigReady = false
    blackboxSupported = false
    featureBitmap = 0
    blackboxConfigParsed = {}
    blackboxFocused = false

    local FAPI = rfsuite.tasks.msp.api.load("FEATURE_CONFIG")
    FAPI.setUUID("blackbox-menu-feature")
    FAPI.setCompleteHandler(function()
        local d = FAPI.data()
        local parsed = d and d.parsed or nil
        featureBitmap = tonumber(parsed and parsed.enabledFeatures or 0) or 0
        featureConfigReady = true
        onPrereqDone()
    end)
    FAPI.setErrorHandler(function()
        featureConfigReady = true
        onPrereqDone()
    end)
    FAPI.read()

    local BAPI = rfsuite.tasks.msp.api.load("BLACKBOX_CONFIG")
    BAPI.setUUID("blackbox-menu-config")
    BAPI.setCompleteHandler(function()
        local d = BAPI.data()
        local parsed = d and d.parsed or nil
        blackboxConfigParsed = copyTable(parsed or {})
        blackboxSupported = tonumber(parsed and parsed.blackbox_supported or 0) == 1
        blackboxConfigReady = true
        onPrereqDone()
    end)
    BAPI.setErrorHandler(function()
        blackboxConfigParsed = {}
        blackboxSupported = false
        blackboxConfigReady = true
        onPrereqDone()
    end)
    BAPI.read()
end

return {
    title = "@i18n(app.modules.blackbox.name)@",
    pages = S_PAGES,
    scriptPrefix = "blackbox/tools/",
    iconPrefix = "app/modules/blackbox/gfx/",
    loaderSpeed = rfsuite.app.loaderSpeed.DEFAULT,
    navOptions = {defaultSection = "hardware"},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = true},
    onOpenPost = function()
        prereqRequested = false
        setButtonsEnabled(false)
        requestBlackboxPrereqs()
    end,
    onWakeup = function()
        if os.clock() - initTime < 0.25 then return end

        if not prereqRequested then requestBlackboxPrereqs() end
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
