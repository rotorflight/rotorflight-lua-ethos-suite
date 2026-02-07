--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local  S_PAGES ={
        [1] = { name = "@i18n(app.modules.servos.pwm)@", script = "pwm.lua", image = "pwm.png" },
        [2] = { name = "@i18n(app.modules.servos.sbus)@", script = "sbus.lua", image = "sbus.png"},    
        [3] = { name = "@i18n(app.modules.servos.fbus)@", script = "fbus.lua", image = "fbus.png"},
    }

local enableWakeup = false
local prevConnectedState = nil
local initTime = os.clock()
local servosCompatibilityStatus = false



local function openPage(pidx, title, script)

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    for i in pairs(rfsuite.app.gfx_buttons) do if i ~= "servos" then rfsuite.app.gfx_buttons[i] = nil end end

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

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.servos.name)@")

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

    if rfsuite.app.gfx_buttons["servos"] == nil then rfsuite.app.gfx_buttons["servos"] = {} end
    if rfsuite.preferences.menulastselected["servos"] == nil then rfsuite.preferences.menulastselected["servos"] = 1 end

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
            if rfsuite.app.gfx_buttons["servos"][pidx] == nil then rfsuite.app.gfx_buttons["servos"][pidx] = lcd.loadMask("app/modules/servos/gfx/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["servos"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = rfsuite.app.gfx_buttons["servos"][pidx],
            options = FONT_S,
            paint = function() end,
            press = function()
                rfsuite.preferences.menulastselected["servos"] = pidx
                rfsuite.app.ui.progressDisplay(nil,nil,false)
                local name = "@i18n(app.modules.servos.name)@" .. " / " .. pvalue.name
                rfsuite.app.ui.openPage(pidx, name, "servos/tools/" .. pvalue.script)
            end
        })

        -- Disable all buttons until msp calls are complete
        rfsuite.app.formFields[pidx]:enable(false)

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

        if rfsuite.preferences.menulastselected["servos"] == pidx then rfsuite.app.formFields[pidx]:focus() end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    enableWakeup = true

    return
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openMainMenuSub('hardware')
    return true
end


local function wakeup()
    if not enableWakeup then return end

    if os.clock() - initTime < 0.25 then return end

    -- Do MSP calls to get servo info
    -- We keep sub menu buttons disabled until this is delivered
    if rfsuite.tasks  and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then

        local msp = rfsuite.tasks.msp

        if rfsuite.session.servoCount == nil then
            msp.helpers.servoCount(function(servoCount)
                rfsuite.utils.log("Received servo count: " .. tostring(servoCount), "info")
            end)
        end

        if rfsuite.session.servoOverride == nil then
            msp.helpers.servoOverride(function(servoOverride)
                rfsuite.utils.log("Received servo override: " .. tostring(servoOverride), "info")
            end)
        end

        if rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil then
            rfsuite.tasks.msp.helpers.mixerConfig(function(tailMode, swashMode)
                rfsuite.utils.log("Received tail mode: " .. tostring(tailMode), "info")
                rfsuite.utils.log("Received swash mode: " .. tostring(swashMode), "info")
            end)
        end    

    end

    -- enable the buttons once we have servo info
    if rfsuite.session.servoCount ~= nil and rfsuite.session.servoOverride ~= nil and rfsuite.session.tailMode ~= nil and rfsuite.session.swashMode ~= nil then
        for i, v in pairs(rfsuite.app.formFields) do
            if v.enable then
                v:enable(true)
            end    
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
