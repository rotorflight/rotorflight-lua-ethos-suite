--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local app = rfsuite.app
local lcd = lcd

local TITLE = "Developer"

local S_PAGES = {
    {name = "@i18n(app.modules.msp_speed.name)@", script = "developer/tools/msp_speed.lua", image = "app/modules/developer/gfx/msp_speed.png", bgtask = true, offline = true},
    {name = "@i18n(app.modules.api_tester.name)@", script = "developer/tools/api_tester.lua", image = "app/modules/developer/gfx/api_tester.png", bgtask = true, offline = true},
    {name = "@i18n(app.modules.msp_exp.name)@", script = "developer/tools/msp_exp.lua", image = "app/modules/developer/gfx/msp_exp.png", bgtask = true, offline = true},
    {name = "@i18n(app.modules.settings.name)@", script = "settings/tools/development.lua", image = "app/modules/developer/gfx/settings.png", bgtask = true, offline = true}
}

local function openPage(opts)
    local pidx = opts.idx
    local title = opts.title
    local script = opts.script

    app.triggers.isReady = false
    app.uiState = app.uiStatus.mainMenu

    form.clear()
    app.lastIdx = pidx
    app.lastTitle = title
    app.lastScript = script

    for i in pairs(app.gfx_buttons) do
        if i ~= "developer" then app.gfx_buttons[i] = nil end
    end

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    app.ui.fieldHeader(TITLE)

    local padding
    local buttonW
    local buttonH
    local numPerRow

    if rfsuite.preferences.general.iconsize == 0 then
        padding = app.radio.buttonPaddingSmall
        buttonW = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    elseif rfsuite.preferences.general.iconsize == 1 then
        padding = app.radio.buttonPaddingSmall
        buttonW = app.radio.buttonWidthSmall
        buttonH = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    else
        padding = app.radio.buttonPadding
        buttonW = app.radio.buttonWidth
        buttonH = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    app.gfx_buttons["developer"] = app.gfx_buttons["developer"] or {}
    rfsuite.preferences.menulastselected["developer"] = rfsuite.preferences.menulastselected["developer"] or 1
    app.formFieldsOffline = {}
    app.formFieldsBGTask = {}

    local lc = 0
    local bx = 0
    local y = 0

    for i = 1, #S_PAGES do
        local pvalue = S_PAGES[i]
        app.formFieldsOffline[i] = pvalue.offline or false
        app.formFieldsBGTask[i] = pvalue.bgtask or false

        if lc == 0 then
            y = form.height() + ((rfsuite.preferences.general.iconsize == 2) and app.radio.buttonPadding or app.radio.buttonPaddingSmall)
        end

        bx = (buttonW + padding) * lc

        if rfsuite.preferences.general.iconsize ~= 0 then
            if app.gfx_buttons["developer"][i] == nil then
                app.gfx_buttons["developer"][i] = lcd.loadMask(pvalue.image)
            end
        else
            app.gfx_buttons["developer"][i] = nil
        end

        app.formFields[i] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = app.gfx_buttons["developer"][i],
            options = FONT_S,
            paint = function() end,
            press = function()
                rfsuite.preferences.menulastselected["developer"] = i
                app.ui.progressDisplay(nil, nil, app.loaderSpeed.FAST)
                app.ui.openPage({idx = i, title = TITLE .. " / " .. pvalue.name, script = pvalue.script})
            end
        })

        if rfsuite.preferences.menulastselected["developer"] == i then app.formFields[i]:focus() end
        lc = lc + 1
        if lc == numPerRow then lc = 0 end
    end

    app.triggers.closeProgressLoader = true
end

local function wakeup()
    if not rfsuite.tasks.active() then
        for i, v in pairs(app.formFieldsBGTask) do
            if v == true and app.formFields[i] and app.formFields[i].enable then
                app.formFields[i]:enable(false)
            end
        end
    elseif not rfsuite.session.isConnected then
        for i, v in pairs(app.formFieldsOffline) do
            if v == true and app.formFields[i] and app.formFields[i].enable then
                app.formFields[i]:enable(false)
            end
        end
    else
        for i in pairs(app.formFields) do
            if app.formFields[i] and app.formFields[i].enable then app.formFields[i]:enable(true) end
        end
    end
end

local function onNavMenu()
    app.ui.openMainMenu()
    return true
end

app.uiState = app.uiStatus.pages

return {openPage = openPage, wakeup = wakeup, onNavMenu = onNavMenu, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}, API = {}}
