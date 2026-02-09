--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local app = rfsuite.app
local prefs = rfsuite.preferences
local tasks = rfsuite.tasks
local utils = rfsuite.utils
local session = rfsuite.session

local S_PAGES = {
    [1] = { name = "@i18n(app.modules.governor.menu_general)@", script = "general.lua", image = "general.png" },
    [2] = { name = "@i18n(app.modules.governor.menu_time)@", script = "time.lua", image = "time.png" },
    [3] = { name = "@i18n(app.modules.governor.menu_filters)@", script = "filters.lua", image = "filters.png" },
    [4] = { name = "@i18n(app.modules.governor.menu_curves)@", script = "curves.lua", image = "curves.png" },
}

local enableWakeup = false
local prevConnectedState = nil
local initTime = os.clock()

local function openPage(pidx, title, script)

    tasks.msp.protocol.mspIntervalOveride = nil

    app.triggers.isReady = false
    app.uiState = app.uiStatus.mainMenu

    form.clear()

    app.lastIdx = idx
    app.lastTitle = title
    app.lastScript = script

    for i in pairs(app.gfx_buttons) do if i ~= "governor" then app.gfx_buttons[i] = nil end end

    if prefs.general.iconsize == nil or prefs.general.iconsize == "" then
        prefs.general.iconsize = 1
    else
        prefs.general.iconsize = tonumber(prefs.general.iconsize)
    end

    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = app.radio.buttonPadding

    local sc
    local panel

    local buttonW = 100
    local x = windowWidth - buttonW - 10

    app.ui.fieldHeader("@i18n(app.modules.governor.name)@")

    local buttonW
    local buttonH
    local padding
    local numPerRow

    if prefs.general.iconsize == 0 then
        padding = app.radio.buttonPaddingSmall
        buttonW = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    if prefs.general.iconsize == 1 then

        padding = app.radio.buttonPaddingSmall
        buttonW = app.radio.buttonWidthSmall
        buttonH = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    end

    if prefs.general.iconsize == 2 then

        padding = app.radio.buttonPadding
        buttonW = app.radio.buttonWidth
        buttonH = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    if app.gfx_buttons["governor"] == nil then app.gfx_buttons["governor"] = {} end
    local lastSelected = tonumber(prefs.menulastselected["governor"]) or 1
    if lastSelected < 1 then lastSelected = 1 end
    if lastSelected > #S_PAGES then lastSelected = #S_PAGES end
    prefs.menulastselected["governor"] = lastSelected
    app._governor_focused = false

    local Menu = assert(loadfile("app/modules/" .. script))()
    local pages = S_PAGES
    local lc = 0
    local bx = 0
    local y = 0

    for pidx, pvalue in ipairs(S_PAGES) do

        if lc == 0 then
            if prefs.general.iconsize == 0 then y = form.height() + app.radio.buttonPaddingSmall end
            if prefs.general.iconsize == 1 then y = form.height() + app.radio.buttonPaddingSmall end
            if prefs.general.iconsize == 2 then y = form.height() + app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if prefs.general.iconsize ~= 0 then
            if app.gfx_buttons["governor"][pidx] == nil then app.gfx_buttons["governor"][pidx] = lcd.loadMask("app/modules/governor/gfx/" .. pvalue.image) end
        else
            app.gfx_buttons["governor"][pidx] = nil
        end

        app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = app.gfx_buttons["governor"][pidx],
            options = FONT_S,
            paint = function() end,
            press = function()
                prefs.menulastselected["governor"] = pidx
                app.ui.progressDisplay()
                local name = "@i18n(app.modules.governor.name)@" .. " / " .. pvalue.name
                app.ui.openPage(pidx, name, "governor/tools/" .. pvalue.script)
            end
        })

        -- keep disabled until we know governor session vars exist
        app.formFields[pidx]:enable(false)

        local currState = (session.isConnected and session.mcu_id) and true or false


        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    enableWakeup = true
    return
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        app.ui.openMainMenuSub(app.lastMenu)
        return true
    end
end

local function onNavMenu()
    app.ui.progressDisplay()
    app.ui.openMainMenuSub('hardware')
    return true
end

local function wakeup()
    if not enableWakeup then return end

    if os.clock() - initTime < 0.25 then return end

    if session.governorMode == nil then
        if tasks and tasks.msp and tasks.msp.helpers then
            tasks.msp.helpers.governorMode(function(governorMode)
                utils.log("Received governor mode: " .. tostring(governorMode), "info")
            end)
        end
    end


    -- enable the buttons once we have servo info
    if session.governorMode ~= nil then
        for i, v in pairs(app.formFields) do
            if v.enable then
                v:enable(true)
            end    
        end

        if not app._governor_focused then
            app._governor_focused = true
            local idx = tonumber(prefs.menulastselected["governor"]) or 1
            local btn = app.formFields and app.formFields[idx] or nil
            if btn and btn.focus then btn:focus() end
        end
        -- close progress loader
        app.triggers.closeProgressLoader = true
    end

    local currState = (session.isConnected and session.mcu_id) and true or false

    if currState ~= prevConnectedState then

        app.formFields[2]:enable(currState)

        if not currState then app.formNavigationFields['menu']:focus() end

        prevConnectedState = currState
    end
end

app.uiState = app.uiStatus.pages

return {pages = pages, openPage = openPage, onNavMenu = onNavMenu, event = event, wakeup = wakeup, API = {}, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}}
