--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local servoTable = {}
servoTable = {}
servoTable['sections'] = {}

local triggerOverRide = false
local triggerOverRideAll = false
local lastServoCountTime = os.clock()
local onNavMenu

local busServoCount = 16    -- how many bus servos we display
-- Index translation for BUS read/write MSP commands is handled in `bus_tool.lua`.
-- This page only controls BUS servo list UI and navigation.

local function writeEeprom()

    local mspEepromWrite = {command = 250, simulatorResponse = {}}
    rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)

end

local function buildServoTable()


    for i = 1, busServoCount do
        servoTable[i] = {}
        servoTable[i] = {}
        servoTable[i]['title'] = "@i18n(app.modules.servos.servo_prefix)@" .. i
        servoTable[i]['image'] = "servo" .. i .. ".png"
        servoTable[i]['disabled'] = true
    end

    for i = 1, busServoCount do

        servoTable[i]['disabled'] = false

        if rfsuite.session.swashMode == 0 then

        elseif rfsuite.session.swashMode == 1 then

            if rfsuite.session.tailMode == 0 then
                servoTable[4]['title'] = "@i18n(app.modules.servos.tail)@"
                servoTable[4]['image'] = "tail.png"
                servoTable[4]['section'] = 1
            end
        elseif rfsuite.session.swashMode == 2 or rfsuite.session.swashMode == 3 or rfsuite.session.swashMode == 4 then

            servoTable[1]['title'] = "@i18n(app.modules.servos.cyc_pitch)@"
            servoTable[1]['image'] = "cpitch.png"

            servoTable[2]['title'] = "@i18n(app.modules.servos.cyc_left)@"
            servoTable[2]['image'] = "cleft.png"

            servoTable[3]['title'] = "@i18n(app.modules.servos.cyc_right)@"
            servoTable[3]['image'] = "cright.png"

            if rfsuite.session.tailMode == 0 then

                if servoTable[4] == nil then servoTable[4] = {} end
                servoTable[4]['title'] = "@i18n(app.modules.servos.tail)@"
                servoTable[4]['image'] = "tail.png"
            else

            end
        elseif rfsuite.session.swashMode == 5 or rfsuite.session.swashMode == 6 then

            if rfsuite.session.tailMode == 0 then
                servoTable[4]['title'] = "@i18n(app.modules.servos.tail)@"
                servoTable[4]['image'] = "tail.png"
            else

            end
        end
    end
end

local function swashMixerType()
    local txt
    if rfsuite.session.swashMode == 0 then
        txt = "NONE"
    elseif rfsuite.session.swashMode == 1 then
        txt = "DIRECT"
    elseif rfsuite.session.swashMode == 2 then
        txt = "CPPM 120°"
    elseif rfsuite.session.swashMode == 3 then
        txt = "CPPM 135°"
    elseif rfsuite.session.swashMode == 4 then
        txt = "CPPM 140°"
    elseif rfsuite.session.swashMode == 5 then
        txt = "FPPM 90° L"
    elseif rfsuite.session.swashMode == 6 then
        txt = "FPPM 90° R"
    else
        txt = "UNKNOWN"
    end

    return txt
end

local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script

    buildServoTable()

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

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

    rfsuite.app.ui.fieldHeader(title or "@i18n(app.modules.servos.name)@ / @i18n(app.modules.servos.bus)@")

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

    local lc = 0
    local bx = 0
    local y = 0

    if rfsuite.app.gfx_buttons["bus"] == nil then rfsuite.app.gfx_buttons["bus"] = {} end
    if rfsuite.preferences.menulastselected["bus"] == nil then rfsuite.preferences.menulastselected["bus"] = 1 end

    if rfsuite.app.gfx_buttons["bus"] == nil then rfsuite.app.gfx_buttons["bus"] = {} end
    if rfsuite.preferences.menulastselected["bus"] == nil then rfsuite.preferences.menulastselected["bus"] = 1 end

    for pidx, pvalue in ipairs(servoTable) do

        if pvalue.disabled ~= true then

            if pvalue.section == "swash" and lc == 0 then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, headerLineText())
            end

            if pvalue.section == "tail" then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, "@i18n(app.modules.servos.tail)@")
            end

            if pvalue.section == "other" then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, "@i18n(app.modules.servos.tail)@")
            end

            if lc == 0 then
                if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
            end

            if lc >= 0 then bx = (buttonW + padding) * lc end

            if rfsuite.preferences.general.iconsize ~= 0 then
                if rfsuite.app.gfx_buttons["bus"][pidx] == nil then rfsuite.app.gfx_buttons["bus"][pidx] = lcd.loadMask("app/modules/servos/gfx/" .. pvalue.image) end
            else
                rfsuite.app.gfx_buttons["bus"][pidx] = nil
            end

            rfsuite.app.formFields[pidx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = pvalue.title,
                icon = rfsuite.app.gfx_buttons["bus"][pidx],
                options = FONT_S,
                paint = function() end,
                press = function()
                    rfsuite.preferences.menulastselected["bus"] = pidx
                    rfsuite.currentServoIndex = pidx
                    rfsuite.app.ui.progressDisplay()

                    rfsuite.app.ui.openPage({
                        idx = pidx,
                        title = pvalue.title,
                        script = "servos/tools/bus_tool.lua",
                        servoTable = servoTable,
                        returnContext = {idx = pidx, title = title, script = script}
                    })
                end
            })

            if rfsuite.preferences.menulastselected["bus"] == pidx then rfsuite.app.formFields[pidx]:focus() end

            lc = lc + 1

            if lc == numPerRow then lc = 0 end
        end
    end

    -- for a write if we are in over-ride and returning to main page
    if rfsuite.session.servoOverride == false then
        writeEeprom()
    end


    rfsuite.app.triggers.closeProgressLoader = true

    return
end


local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

local function onToolMenu(self)

    local buttons
    if rfsuite.session.servoOverride == false then
        buttons = {
            {
                label = "@i18n(app.btn_ok_long)@",
                action = function()

                    triggerOverRide = true
                    triggerOverRideAll = true
                    return true
                end
            }, {label = "CANCEL", action = function() return true end}
        }
    else
        buttons = {
            {
                label = "@i18n(app.btn_ok_long)@",
                action = function()

                    triggerOverRide = true
                    return true
                end
            }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
        }
    end
    local message
    local title
    if rfsuite.session.servoOverride == false then
        title = "@i18n(app.modules.servos.enable_servo_override)@"
        message = "@i18n(app.modules.servos.enable_servo_override_msg)@"
    else
        title = "@i18n(app.modules.servos.disable_servo_override)@"
        message = "@i18n(app.modules.servos.disable_servo_override_msg)@"
    end

    form.openDialog({width = nil, title = title, message = message, buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

end

local function wakeup()

    -- go back to main as this tool is compromised 
    if rfsuite.session.servoCount == nil or rfsuite.session.servoOverride == nil then
        pageRuntime.openMenuContext()
        return
    end

    if triggerOverRide == true then
        triggerOverRide = false

        if rfsuite.session.servoOverride == false then
            rfsuite.app.audio.playServoOverideEnable = true
            rfsuite.app.ui.progressDisplay("@i18n(app.modules.servos.servo_override)@", "@i18n(app.modules.servos.enabling_servo_override)@")
            rfsuite.app.Page.servoCenterFocusAllOn(self)
            rfsuite.session.servoOverride = true
        else
            rfsuite.app.audio.playServoOverideDisable = true
            rfsuite.app.ui.progressDisplay("@i18n(app.modules.servos.servo_override)@", "@i18n(app.modules.servos.disabling_servo_override)@")
            rfsuite.app.Page.servoCenterFocusAllOff(self)
            rfsuite.session.servoOverride = false
            writeEeprom()
        end
    end

end

local function servoCenterFocusAllOn(self)

    rfsuite.app.audio.playServoOverideEnable = true

    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
            local message = {command = 196, payload = {}}
            rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 0)
            rfsuite.tasks.msp.mspQueue:add(message)
    else
        for i = 0, #servoTable do
            local message = {command = 193, payload = {i}}
            rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 0)
            rfsuite.tasks.msp.mspQueue:add(message)
        end
    end    


    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function servoCenterFocusAllOff(self)

    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
            local message = {command = 196, payload = {}}
            rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 2001)
            rfsuite.tasks.msp.mspQueue:add(message)
    else
        for i = 0, #servoTable do
            local message = {command = 193, payload = {i}}
            rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 2001)
            rfsuite.tasks.msp.mspQueue:add(message)
        end
    end    
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

onNavMenu = function(self)

    if rfsuite.session.servoOverride == true or inFocus == true then
        rfsuite.app.audio.playServoOverideDisable = true
        rfsuite.session.servoOverride = false
        inFocus = false
        rfsuite.app.ui.progressDisplay("@i18n(app.modules.servos.servo_override)@", "@i18n(app.modules.servos.disabling_servo_override)@")
        rfsuite.app.Page.servoCenterFocusAllOff(self)
        rfsuite.app.triggers.closeProgressLoader = true
    end

    pageRuntime.openMenuContext({defaultSection = "hardware"})
    return true

end


return {event = event, openPage = openPage, onToolMenu = onToolMenu, onNavMenu = onNavMenu, servoCenterFocusAllOn = servoCenterFocusAllOn, servoCenterFocusAllOff = servoCenterFocusAllOff, wakeup = wakeup, navButtons = {menu = true, save = false, reload = false, tool = true, help = true}, onReloadMenu = onReloadMenu, API = {}}
