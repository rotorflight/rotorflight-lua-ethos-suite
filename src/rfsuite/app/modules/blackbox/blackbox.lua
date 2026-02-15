--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local S_PAGES = {
    [1] = { name = "Configuration", script = "configuration.lua", image = "configuration.png" },
    [2] = { name = "Logging", script = "logging.lua", image = "logging.png" },
    [3] = { name = "Status", script = "status.lua", image = "status.png" }
}

local enableWakeup = false
local prevConnectedState = nil
local initTime = os.clock()

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

    rfsuite.app.ui.fieldHeader("Blackbox")

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
    if rfsuite.preferences.menulastselected["blackbox"] == nil then rfsuite.preferences.menulastselected["blackbox"] = 1 end

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
                local name = "Blackbox / " .. page.name
                rfsuite.app.ui.openPage({idx = idx, title = name, script = "blackbox/tools/" .. page.script})
            end
        })

        if rfsuite.preferences.menulastselected["blackbox"] == idx then rfsuite.app.formFields[idx]:focus() end

        lc = lc + 1
        if lc == numPerRow then lc = 0 end
    end

    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function event(widget, category, value)
    if category == EVT_CLOSE and value == 0 or value == 35 then
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

    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false
    if currState ~= prevConnectedState then
        if not currState then rfsuite.app.formNavigationFields["menu"]:focus() end
        prevConnectedState = currState
    end
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {pages = S_PAGES, openPage = openPage, onNavMenu = onNavMenu, event = event, wakeup = wakeup, API = {}, navButtons = {menu = true, save = false, reload = false, tool = false, help = true}}
