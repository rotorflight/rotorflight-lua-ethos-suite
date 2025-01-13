-- create 16 servos in disabled state
local servoTable = {}
servoTable = {}
servoTable['sections'] = {}

local triggerOverRide = false
local triggerOverRideAll = false
local lastServoCountTime = os.clock()

local function buildServoTable()

    for i = 1, rfsuite.config.servoCount do
        servoTable[i] = {}
        servoTable[i] = {}
        servoTable[i]['title'] = "SERVO " .. i
        servoTable[i]['image'] = "servo" .. i .. ".png"
        servoTable[i]['disabled'] = true
    end

    for i = 1, rfsuite.config.servoCount do
        -- enable actual number of servos
        servoTable[i]['disabled'] = false

        if rfsuite.config.swashMode == 0 then
            -- we do nothing as we cannot determine any servo names
        elseif rfsuite.config.swashMode == 1 then
            -- servo mode is direct - only servo for sure we know name of is tail
            if rfsuite.config.tailMode == 0 then
                servoTable[4]['title'] = "TAIL"
                servoTable[4]['image'] = "tail.png"
                servoTable[4]['section'] = 1
            end
        elseif rfsuite.config.swashMode == 2 or rfsuite.config.swashMode == 3 or rfsuite.config.swashMode == 4 then
            -- servo mode is cppm - 
            servoTable[1]['title'] = "CYC. PITCH"
            servoTable[1]['image'] = "cpitch.png"

            servoTable[2]['title'] = "CYC. LEFT"
            servoTable[2]['image'] = "cleft.png"

            servoTable[3]['title'] = "CYC. RIGHT"
            servoTable[3]['image'] = "cright.png"

            if rfsuite.config.tailMode == 0 then
                -- this is because when swiching models this may or may not have
                -- been created.
                if servoTable[4] == nil then servoTable[4] = {} end
                servoTable[4]['title'] = "TAIL"
                servoTable[4]['image'] = "tail.png"
            else
                -- servoTable[4]['disabled'] = true
            end
        elseif rfsuite.config.swashMode == 5 or rfsuite.config.swashMode == 6 then
            -- servo mode is fpm 90
            -- servoTable[3]['disabled'] = true 
            if rfsuite.config.tailMode == 0 then
                servoTable[4]['title'] = "TAIL"
                servoTable[4]['image'] = "tail.png"
            else
                -- servoTable[4]['disabled'] = true                
            end
        end
    end
end

local function swashMixerType()
    local txt
    if rfsuite.config.swashMode == 0 then
        txt = "NONE"
    elseif rfsuite.config.swashMode == 1 then
        txt = "DIRECT"
    elseif rfsuite.config.swashMode == 2 then
        txt = "CPPM 120°"
    elseif rfsuite.config.swashMode == 3 then
        txt = "CPPM 135°"
    elseif rfsuite.config.swashMode == 4 then
        txt = "CPPM 140°"
    elseif rfsuite.config.swashMode == 5 then
        txt = "FPPM 90° L"
    elseif rfsuite.config.swashMode == 6 then
        txt = "FPPM 90° R"
    else
        txt = "UNKNOWN"
    end

    return txt
end

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

    rfsuite.app.ui.fieldHeader("Servos")

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

    if rfsuite.app.gfx_buttons["servos"] == nil then rfsuite.app.gfx_buttons["servos"] = {} end
    if rfsuite.app.menuLastSelected["servos"] == nil then rfsuite.app.menuLastSelected["servos"] = 1 end

    if rfsuite.app.gfx_buttons["servos"] == nil then rfsuite.app.gfx_buttons["servos"] = {} end
    if rfsuite.app.menuLastSelected["servos"] == nil then rfsuite.app.menuLastSelected["servos"] = 1 end

    for pidx, pvalue in ipairs(servoTable) do

        if pvalue.disabled ~= true then

            if pvalue.section == "swash" and lc == 0 then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.config.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, headerLineText())
            end

            if pvalue.section == "tail" then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.config.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, "TAIL")
            end

            if pvalue.section == "other" then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.config.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, "TAIL")
            end

            if lc == 0 then
                if rfsuite.config.iconSize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.config.iconSize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.config.iconSize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
            end

            if lc >= 0 then bx = (buttonW + padding) * lc end

            if rfsuite.config.iconSize ~= 0 then
                if rfsuite.app.gfx_buttons["servos"][pidx] == nil then rfsuite.app.gfx_buttons["servos"][pidx] = lcd.loadMask("app/gfx/servos/" .. pvalue.image) end
            else
                rfsuite.app.gfx_buttons["servos"][pidx] = nil
            end

            rfsuite.app.formFields[pidx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = pvalue.title,
                icon = rfsuite.app.gfx_buttons["servos"][pidx],
                options = FONT_S,
                paint = function()
                end,
                press = function()
                    rfsuite.app.menuLastSelected["servos"] = pidx
                    rfsuite.currentServoIndex = pidx
                    rfsuite.app.ui.progressDisplay()
                    rfsuite.app.ui.openPage(pidx, pvalue.title, "servos_tool.lua", servoTable)
                end
            })

            if pvalue.disabled == true then rfsuite.app.formFields[pidx]:enable(false) end

            if rfsuite.app.menuLastSelected["servos"] == pidx then rfsuite.app.formFields[pidx]:focus() end

            lc = lc + 1

            if lc == numPerRow then lc = 0 end
        end
    end

    rfsuite.app.triggers.closeProgressLoader = true

    return
end

local function getServoCount(callback, callbackParam)
    local message = {
        command = 120, -- MSP_SERVO_CONFIGURATIONS
        processReply = function(self, buf)
            local servoCount = rfsuite.bg.msp.mspHelper.readU8(buf)

            -- update master one in case changed
            rfsuite.config.servoCountNew = servoCount

            if callback then callback(callbackParam) end
        end,
        -- 2 servos
        -- simulatorResponse = {
        --        2,
        --        220, 5, 68, 253, 188, 2, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0,
        --        221, 5, 68, 253, 188, 2, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0
        -- }
        -- 4 servos
        simulatorResponse = {4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

local function openPageInit(pidx, title, script)

    if rfsuite.config.servoCount ~= nil then
        buildServoTable()
        openPage(pidx, title, script)
    else
        local message = {
            command = 120, -- MSP_SERVO_CONFIGURATIONS
            processReply = function(self, buf)
                if #buf >= 10 then
                    local servoCount = rfsuite.bg.msp.mspHelper.readU8(buf)

                    -- update master one in case changed
                    rfsuite.config.servoCount = servoCount
                end
            end,
            simulatorResponse = {4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0}
        }
        rfsuite.bg.msp.mspQueue:add(message)

        local message = {
            command = 192, -- MSP_SERVO_OVERIDE
            processReply = function(self, buf)
                if #buf >= 10 then

                    for i = 0, rfsuite.config.servoCount do
                        buf.offset = i
                        local servoOverride = rfsuite.bg.msp.mspHelper.readU8(buf)
                        if servoOverride == 0 then
                            rfsuite.utils.log("Servo override: true")
                            rfsuite.config.servoOverride = true
                        end
                    end
                end
                if rfsuite.config.servoOverride == nil then rfsuite.config.servoOverride = false end
            end,
            simulatorResponse = {209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7}
        }
        rfsuite.bg.msp.mspQueue:add(message)

    end
end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        rfsuite.app.Page.onNavMenu(self)
        return true
    end

    return false
end

local function onToolMenu(self)

    local buttons
    if rfsuite.config.servoOverride == false then
        buttons = {{
            label = "                OK                ",
            action = function()

                -- we cant launch the loader here to se rely on the modules
                -- wakeup function to do this
                triggerOverRide = true
                triggerOverRideAll = true
                return true
            end
        }, {
            label = "CANCEL",
            action = function()
                return true
            end
        }}
    else
        buttons = {{
            label = "                OK                ",
            action = function()

                -- we cant launch the loader here to se rely on the modules
                -- wakeup function to do this
                triggerOverRide = true
                return true
            end
        }, {
            label = "CANCEL",
            action = function()
                return true
            end
        }}
    end
    local message
    local title
    if rfsuite.config.servoOverride == false then
        title = "Enable servo override"
        message = "Servo override allows you to 'trim' your servo center point in real time."
    else
        title = "Disable servo override"
        message = "Return control of the servos to the flight controller."
    end

    form.openDialog({
        width = nil,
        title = title,
        message = message,
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

end

local function wakeup()
    if triggerOverRide == true then
        triggerOverRide = false

        if rfsuite.config.servoOverride == false then
            rfsuite.app.audio.playServoOverideEnable = true
            rfsuite.app.ui.progressDisplay("Servo override", "Enabling servo override...")
            rfsuite.app.Page.servoCenterFocusAllOn(self)
            rfsuite.config.servoOverride = true
        else
            rfsuite.app.audio.playServoOverideDisable = true
            rfsuite.app.ui.progressDisplay("Servo override", "Disabling servo override...")
            rfsuite.app.Page.servoCenterFocusAllOff(self)
            rfsuite.config.servoOverride = false
        end
    end

    local now = os.clock()
    if ((now - lastServoCountTime) >= 2) and rfsuite.bg.msp.mspQueue:isProcessed() then
        lastServoCountTime = now

        getServoCount()

        if rfsuite.config.servoCountNew ~= nil then if rfsuite.config.servoCountNew ~= rfsuite.config.servoCount then rfsuite.app.triggers.triggerReloadNoPrompt = true end end

    end

end

local function servoCenterFocusAllOn(self)

    rfsuite.app.audio.playServoOverideEnable = true

    for i = 0, #servoTable do
        local message = {
            command = 193, -- MSP_SET_SERVO_OVERRIDE
            payload = {i}
        }
        rfsuite.bg.msp.mspHelper.writeU16(message.payload, 0)
        rfsuite.bg.msp.mspQueue:add(message)
    end
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function servoCenterFocusAllOff(self)

    for i = 0, #servoTable do
        local message = {
            command = 193, -- MSP_SET_SERVO_OVERRIDE
            payload = {i}
        }
        rfsuite.bg.msp.mspHelper.writeU16(message.payload, 2001)
        rfsuite.bg.msp.mspQueue:add(message)
    end
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function onNavMenu(self)

    if rfsuite.config.servoOverride == true or inFocus == true then
        rfsuite.app.audio.playServoOverideDisable = true
        rfsuite.config.servoOverride = false
        inFocus = false
        rfsuite.app.ui.progressDisplay("Servo override", "Disabling servo override...")
        rfsuite.app.Page.servoCenterFocusAllOff(self)
        rfsuite.app.triggers.closeProgressLoader = true
    end
    -- rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openMainMenu()

end

return {title = "Servos", event = event, openPage = openPageInit, onToolMenu = onToolMenu, onNavMenu = onNavMenu, servoCenterFocusAllOn = servoCenterFocusAllOn, servoCenterFocusAllOff = servoCenterFocusAllOff, wakeup = wakeup, navButtons = {menu = true, save = false, reload = true, tool = true, help = true}}
