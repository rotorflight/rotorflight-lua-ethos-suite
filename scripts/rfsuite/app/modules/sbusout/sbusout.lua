-- create 16 servos in disabled state
local SBUS_FUNCTIONMASK = 262144
local triggerOverRide = false
local triggerOverRideAll = false
local lastServoCountTime = os.clock()
local enableWakeup = false
local wakeupScheduler = os.clock()
local validSerialConfig = false

local function openPage(pidx, title, script)

    rfsuite.bg.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    -- size of buttons
    if rfsuite.config.iconSize == nil or rfsuite.config.iconSize == "" then
        rfsuite.config.iconSize = 1
    else
        rfsuite.config.iconSize = tonumber(rfsuite.config.iconSize)
    end

    local w, h = rfsuite.utils.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel

    buttonW = 100
    local x = windowWidth - buttonW - 10

    rfsuite.app.ui.fieldHeader("SBUS Output")

    local buttonW
    local buttonH
    local padding
    local numPerRow

    -- TEXT ICONS
    -- TEXT ICONS
    if rfsuite.config.iconSize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.config.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end
    -- SMALL ICONS
    if rfsuite.config.iconSize == 1 then

        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end
    -- LARGE ICONS
    if rfsuite.config.iconSize == 2 then

        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    local lc = 0
    local bx = 0

    if rfsuite.app.gfx_buttons["sbuschannel"] == nil then rfsuite.app.gfx_buttons["sbuschannel"] = {} end
    if rfsuite.app.menuLastSelected["sbuschannel"] == nil then rfsuite.app.menuLastSelected["sbuschannel"] = 0 end
    if rfsuite.currentSbusServoIndex == nil then rfsuite.currentSbusServoIndex = 0 end

    for pidx = 0, 15 do

        if lc == 0 then
            if rfsuite.config.iconSize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.config.iconSize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.config.iconSize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.config.iconSize ~= 0 then
            if rfsuite.app.gfx_buttons["sbuschannel"][pidx] == nil then rfsuite.app.gfx_buttons["sbuschannel"][pidx] = lcd.loadMask("app/modules/sbusout/gfx/ch" .. tostring(pidx + 1) .. ".png") end
        else
            rfsuite.app.gfx_buttons["sbuschannel"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = "CHANNEL " .. tostring(pidx + 1),
            icon = rfsuite.app.gfx_buttons["sbuschannel"][pidx],
            options = FONT_S,
            paint = function()
            end,
            press = function()
                rfsuite.app.menuLastSelected["sbuschannel"] = pidx
                rfsuite.currentSbusServoIndex = pidx
                rfsuite.app.ui.progressDisplay()
                rfsuite.app.ui.openPage(pidx, "Sbus out / CH" .. tostring(rfsuite.currentSbusServoIndex + 1), "sbusout/sbusout_tool.lua")
            end
        })

        rfsuite.app.formFields[pidx]:enable(false)

        lc = lc + 1
        if lc == numPerRow then lc = 0 end

    end

    rfsuite.app.triggers.closeProgressLoader = true

    enableWakeup = true

    return
end

local function processSerialConfig(data)

    for i, v in ipairs(data) do if v.functionMask == SBUS_FUNCTIONMASK then validSerialConfig = true end end

end

local function getSerialConfig()
    local message = {
        command = 54,
        processReply = function(self, buf)
            local data = {}

            buf.offset = 1
            for i = 1, 6 do
                data[i] = {}
                data[i].identifier = rfsuite.bg.msp.mspHelper.readU8(buf)
                data[i].functionMask = rfsuite.bg.msp.mspHelper.readU32(buf)
                data[i].msp_baudrateIndex = rfsuite.bg.msp.mspHelper.readU8(buf)
                data[i].gps_baudrateIndex = rfsuite.bg.msp.mspHelper.readU8(buf)
                data[i].telemetry_baudrateIndex = rfsuite.bg.msp.mspHelper.readU8(buf)
                data[i].blackbox_baudrateIndex = rfsuite.bg.msp.mspHelper.readU8(buf)
            end

            processSerialConfig(data)
        end,
        simulatorResponse = {20, 1, 0, 0, 0, 5, 4, 0, 5, 0, 0, 0, 4, 0, 5, 4, 0, 5, 1, 0, 0, 4, 0, 5, 4, 0, 5, 2, 0, 0, 0, 0, 5, 4, 0, 5, 3, 0, 0, 0, 0, 5, 4, 0, 5, 4, 64, 0, 0, 0, 5, 4, 0, 5}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        rfsuite.app.Page.onNavMenu(self)
        return true
    end

    return false
end

local function wakeup()

    if enableWakeup == true and validSerialConfig == false then

        local now = os.clock()
        if (now - wakeupScheduler) >= 0.5 then
            wakeupScheduler = now

            getSerialConfig()

        end
    elseif enableWakeup == true and validSerialConfig == true then
        for pidx = 0, 15 do
            rfsuite.app.formFields[pidx]:enable(true)
            if rfsuite.app.menuLastSelected["sbuschannel"] == rfsuite.currentSbusServoIndex then rfsuite.app.formFields[rfsuite.currentSbusServoIndex]:focus() end
        end
    end

end

return {title = "Sbus Out", event = event, openPage = openPage, wakeup = wakeup, navButtons = {menu = true, save = false, reload = false, tool = false, help = true}}
