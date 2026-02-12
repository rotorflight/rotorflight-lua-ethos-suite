--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local S_PAGES = {
    [1] = { name = "@i18n(app.modules.governor.menu_general)@", script = "general.lua", image = "general.png" },
    [2] = { name = "@i18n(app.modules.governor.menu_flags)@", script = "flags.lua", image = "flags.png" }
}

local enableWakeup = false
local prevConnectedState = nil
local initTime = os.clock()
local app = rfsuite.app

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

    for i in pairs(rfsuite.app.gfx_buttons) do if i ~= "profile_governor" then rfsuite.app.gfx_buttons[i] = nil end end

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel

    local buttonW = 100
    local x = windowWidth - buttonW - 10

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.governor.name)@")

    local buttonW
    local buttonH
    local padding
    local numPerRow

    if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    if rfsuite.preferences.general.iconsize == 1 then

        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end

    if rfsuite.preferences.general.iconsize == 2 then

        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    if rfsuite.app.gfx_buttons["profile_governor"] == nil then rfsuite.app.gfx_buttons["profile_governor"] = {} end
    local lastSelected = tonumber(rfsuite.preferences.menulastselected["profile_governor"]) or 1
    if lastSelected < 1 then lastSelected = 1 end
    if lastSelected > #S_PAGES then lastSelected = #S_PAGES end
    rfsuite.preferences.menulastselected["profile_governor"] = lastSelected
    rfsuite.app._profile_governor_focused = false

    local Menu = assert(loadfile("app/modules/" .. script))()
    local pages = S_PAGES
    local lc = 0
    local bx = 0
    local y = 0

    for pidx, pvalue in ipairs(S_PAGES) do

        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.preferences.general.iconsize ~= 0 then
            if rfsuite.app.gfx_buttons["profile_governor"][pidx] == nil then rfsuite.app.gfx_buttons["profile_governor"][pidx] = lcd.loadMask("app/modules/governor/gfx/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["profile_governor"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = rfsuite.app.gfx_buttons["profile_governor"][pidx],
            options = FONT_S,
            paint = function() end,
            press = function()
                rfsuite.preferences.menulastselected["profile_governor"] = pidx
                rfsuite.app.ui.progressDisplay()
                local name = "@i18n(app.modules.governor.name)@" .. " / " .. pvalue.name
                rfsuite.app.ui.openPage({idx = pidx, title = name, script = "profile_governor/tools/" .. pvalue.script})
            end
        })

        -- keep disabled until we know governor session vars exist
        rfsuite.app.formFields[pidx]:enable(false)

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    enableWakeup = true
    return
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openMainMenu()
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openMainMenu()
    return true
end

local function wakeup()
    if not enableWakeup then return end

    if os.clock() - initTime < 0.25 then return end

    if rfsuite.session.governorMode == nil then
        if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then
            rfsuite.tasks.msp.helpers.governorMode(function(governorMode)
                rfsuite.utils.log("Received governor mode: " .. tostring(governorMode), "info")
            end)
        end
    end


    -- update button enabled state once governor mode is known
    if rfsuite.session.governorMode ~= nil then
        local buttonsEnabled = rfsuite.session.governorMode ~= 0
        for i, v in pairs(rfsuite.app.formFields) do
            if v.enable then
                v:enable(buttonsEnabled)
            end    
        end

        if buttonsEnabled and not rfsuite.app._profile_governor_focused then
            rfsuite.app._profile_governor_focused = true
            local idx = tonumber(rfsuite.preferences.menulastselected["profile_governor"]) or 1
            local btn = rfsuite.app.formFields and rfsuite.app.formFields[idx] or nil
            if btn and btn.focus then btn:focus() end
        end

        -- close progress loader
        rfsuite.app.triggers.closeProgressLoader = true
    end

    

    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

    if currState ~= prevConnectedState then

        if not currState then rfsuite.app.formNavigationFields['menu']:focus() end

        prevConnectedState = currState
    end
end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {pages = pages, openPage = openPage, onNavMenu = onNavMenu, event = event, wakeup = wakeup, API = {}, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}}
