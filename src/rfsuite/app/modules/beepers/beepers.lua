--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local S_PAGES = {
    [1] = { name = "@i18n(app.modules.beepers.menu_configuration)@", script = "configuration.lua", image = "configuration.png" },
    [2] = { name = "@i18n(app.modules.beepers.menu_dshot)@", script = "dshot.lua", image = "dshot.png" }
}

local enableWakeup = false
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

    for i in pairs(rfsuite.app.gfx_buttons) do if i ~= "beepers" then rfsuite.app.gfx_buttons[i] = nil end end

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.beepers.name)@")

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

    if rfsuite.app.gfx_buttons["beepers"] == nil then rfsuite.app.gfx_buttons["beepers"] = {} end
    local lastSelected = tonumber(rfsuite.preferences.menulastselected["beepers"]) or 1
    if lastSelected < 1 then lastSelected = 1 end
    if lastSelected > #S_PAGES then lastSelected = #S_PAGES end
    rfsuite.preferences.menulastselected["beepers"] = lastSelected

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
            if rfsuite.app.gfx_buttons["beepers"][idx] == nil then
                rfsuite.app.gfx_buttons["beepers"][idx] = lcd.loadMask("app/modules/beepers/gfx/" .. page.image)
            end
        else
            rfsuite.app.gfx_buttons["beepers"][idx] = nil
        end

        rfsuite.app.formFields[idx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = page.name,
            icon = rfsuite.app.gfx_buttons["beepers"][idx],
            options = FONT_S,
            paint = function() end,
            press = function()
                rfsuite.preferences.menulastselected["beepers"] = idx
                rfsuite.app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.DEFAULT)
                local name = "@i18n(app.modules.beepers.name)@" .. " / " .. page.name
                rfsuite.app.ui.openPage({idx = idx, title = name, script = "beepers/tools/" .. page.script})
            end
        })

        rfsuite.app.formFields[idx]:enable(false)

        lc = lc + 1
        if lc == numPerRow then lc = 0 end
    end

    prereqRequested = false
    requestPrereqs()

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

    if not prereqRequested then requestPrereqs() end
    updateMenuAvailability()

    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
    if currState ~= prevConnectedState then
        if not currState then rfsuite.app.formNavigationFields["menu"]:focus() end
        prevConnectedState = currState
    end
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {pages = S_PAGES, openPage = openPage, onNavMenu = onNavMenu, event = event, wakeup = wakeup, API = {}, navButtons = {menu = true, save = false, reload = false, tool = false, help = true}}
