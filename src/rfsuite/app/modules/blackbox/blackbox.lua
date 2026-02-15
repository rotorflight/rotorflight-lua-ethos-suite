--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local S_PAGES = {
    [1] = { name = "@i18n(app.modules.blackbox.menu_configuration)@", script = "configuration.lua", image = "configuration.png" },
    [2] = { name = "@i18n(app.modules.blackbox.menu_logging)@", script = "logging.lua", image = "logging.png" },
    [3] = { name = "@i18n(app.modules.blackbox.menu_status)@", script = "status.lua", image = "status.png" }
}

local enableWakeup = false
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
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = copyTable(v)
        else
            dst[k] = v
        end
    end
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
            feature = {
                enabledFeatures = featureBitmap
            },
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

local function openPage(opts)
    local pidx = opts.idx
    local title = opts.title
    local script = opts.script

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu

    form.clear()

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    for i in pairs(rfsuite.app.gfx_buttons) do if i ~= "blackbox" then rfsuite.app.gfx_buttons[i] = nil end end

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.blackbox.name)@")

    local buttonW
    local buttonH
    local padding
    local numPerRow

    if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    elseif rfsuite.preferences.general.iconsize == 1 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    else
        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    if rfsuite.app.gfx_buttons["blackbox"] == nil then rfsuite.app.gfx_buttons["blackbox"] = {} end
    local lastSelected = tonumber(rfsuite.preferences.menulastselected["blackbox"]) or 1
    if lastSelected < 1 then lastSelected = 1 end
    if lastSelected > #S_PAGES then lastSelected = #S_PAGES end
    rfsuite.preferences.menulastselected["blackbox"] = lastSelected

    local lc = 0
    local bx = 0
    local y = 0

    for idx, page in ipairs(S_PAGES) do
        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        bx = (buttonW + padding) * lc

        if rfsuite.preferences.general.iconsize ~= 0 then
            if rfsuite.app.gfx_buttons["blackbox"][idx] == nil then
                rfsuite.app.gfx_buttons["blackbox"][idx] = lcd.loadMask("app/modules/blackbox/gfx/" .. page.image)
            end
        else
            rfsuite.app.gfx_buttons["blackbox"][idx] = nil
        end

        rfsuite.app.formFields[idx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = page.name,
            icon = rfsuite.app.gfx_buttons["blackbox"][idx],
            options = FONT_S,
            paint = function() end,
            press = function()
                rfsuite.preferences.menulastselected["blackbox"] = idx
                rfsuite.app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.DEFAULT)
                local name = "@i18n(app.modules.blackbox.name)@" .. " / " .. page.name
                rfsuite.app.ui.openPage({idx = idx, title = name, script = "blackbox/tools/" .. page.script})
            end
        })

        rfsuite.app.formFields[idx]:enable(false)

        lc = lc + 1
        if lc == numPerRow then lc = 0 end
    end

    prereqRequested = false
    requestBlackboxPrereqs()

    enableWakeup = true
end

local function event(widget, category, value)
    if category == EVT_CLOSE and (value == 0 or value == 35) then
        rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)
end

local function wakeup()
    if not enableWakeup then return end
    if os.clock() - initTime < 0.25 then return end

    if not prereqRequested then requestBlackboxPrereqs() end
    updateMenuAvailability()

    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
    if currState ~= prevConnectedState then
        if not currState then rfsuite.app.formNavigationFields["menu"]:focus() end
        prevConnectedState = currState
    end
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {pages = S_PAGES, openPage = openPage, onNavMenu = onNavMenu, event = event, wakeup = wakeup, API = {}, navButtons = {menu = true, save = false, reload = false, tool = false, help = true}}
