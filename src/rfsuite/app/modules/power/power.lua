--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local S_PAGES = {
        [1] = { name = "@i18n(app.modules.power.battery_name)@", script = "battery.lua", image = "battery.png" },
        [2] = { name = "@i18n(app.modules.power.alert_name)@", script = "alerts.lua", image = "alerts.png" },
        [3] = { name = "@i18n(app.modules.power.source_name)@", script = "source.lua", image = "source.png" }
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

    for i in pairs(rfsuite.app.gfx_buttons) do if i ~= "power" then rfsuite.app.gfx_buttons[i] = nil end end

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

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.power.name)@")

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

    if rfsuite.app.gfx_buttons["power"] == nil then rfsuite.app.gfx_buttons["power"] = {} end
    if rfsuite.preferences.menulastselected["power"] == nil then rfsuite.preferences.menulastselected["power"] = 1 end

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
            if rfsuite.app.gfx_buttons["power"][pidx] == nil then rfsuite.app.gfx_buttons["power"][pidx] = lcd.loadMask("app/modules/power/gfx/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["power"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = rfsuite.app.gfx_buttons["power"][pidx],
            options = FONT_S,
            paint = function() end,
            press = function()
                rfsuite.preferences.menulastselected["power"] = pidx
                rfsuite.app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.DEFAULT)
                local name = "@i18n(app.modules.power.name)@" .. " / " .. pvalue.name
                rfsuite.app.ui.openPage({idx = pidx, title = name, script = "power/tools/" .. pvalue.script})
            end
        })

        if pvalue.disabled == true then rfsuite.app.formFields[pidx]:enable(false) end

        if pvalue.apiversion ~= nil then
            local apiVersionSupported = rfsuite.utils.apiVersionCompare(">=", pvalue.apiversion)
            if not apiVersionSupported then
                rfsuite.app.formFields[pidx]:enable(false)
            end
        end

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

        if rfsuite.preferences.menulastselected["power"] == pidx then rfsuite.app.formFields[pidx]:focus() end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    rfsuite.app.triggers.closeProgressLoader = true

    enableWakeup = true


    return
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)
        return true
    end
end

local function onNavMenu(self)

    rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)

end




local function wakeup()
    if not enableWakeup then return end

    if os.clock() - initTime < 0.25 then return end

    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

    if currState ~= prevConnectedState then

        --rfsuite.app.formFields[2]:enable(currState)

        if not currState then rfsuite.app.formNavigationFields['menu']:focus() end

        prevConnectedState = currState
    end


end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {pages = pages, openPage = openPage, onNavMenu = onNavMenu, event = event, wakeup = wakeup, API = {}, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}}
