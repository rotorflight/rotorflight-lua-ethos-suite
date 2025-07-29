local labels = {}
local fields = {}

local inFocus = false
local triggerOverRide = false
local triggerOverRideAll = false
local triggerCenterChange = false
local currentServoCenter
local lastSetServoCenter
local lastServoChangeTime = os.clock()
local servoIndex = rfsuite.currentServoIndex - 1
local isSaving = false
local enableWakeup = false
local i18n = rfsuite.i18n.get
local servoTable
local servoCount
local configs = {}

local function servoCenterFocusAllOn(self)

    rfsuite.app.audio.playServoOverideEnable = true

    for i = 0, #configs do
        local message = {
            command = 193, -- MSP_SET_SERVO_OVERRIDE
            payload = {i}
        }
        rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 0)
        rfsuite.tasks.msp.mspQueue:add(message)
    end
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function servoCenterFocusAllOff(self)

    for i = 0, #configs do
        local message = {
            command = 193, -- MSP_SET_SERVO_OVERRIDE
            payload = {i}
        }
        rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 2001)
        rfsuite.tasks.msp.mspQueue:add(message)
    end
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function servoCenterFocusOff(self)
    local message = {
        command = 193, -- MSP_SET_SERVO_OVERRIDE
        payload = {servoIndex}
    }
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 2001)
    rfsuite.tasks.msp.mspQueue:add(message)
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function servoCenterFocusOn(self)
    local message = {
        command = 193, -- MSP_SET_SERVO_OVERRIDE
        payload = {servoIndex}
    }
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, 0)
    rfsuite.tasks.msp.mspQueue:add(message)
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function saveServoSettings(self)

    local servoCenter = math.floor(configs[servoIndex]['mid'])
    local servoMin = math.floor(configs[servoIndex]['min'])
    local servoMax = math.floor(configs[servoIndex]['max'])
    local servoScaleNeg = math.floor(configs[servoIndex]['scaleNeg'])
    local servoScalePos = math.floor(configs[servoIndex]['scalePos'])
    local servoRate = math.floor(configs[servoIndex]['rate'])
    local servoSpeed = math.floor(configs[servoIndex]['speed'])
    local servoFlags = math.floor(configs[servoIndex]['flags'])
    local servoReverse = math.floor(configs[servoIndex]['reverse'])
    local servoGeometry = math.floor(configs[servoIndex]['geometry'])

    if servoReverse == 0 and servoGeometry == 0 then
        servoFlags = 0
    elseif servoReverse == 1 and servoGeometry == 0 then
        servoFlags = 1
    elseif servoReverse == 0 and servoGeometry == 1 then
        servoFlags = 2
    elseif servoReverse == 1 and servoGeometry == 1 then
        servoFlags = 3
    end

    local message = {
        command = 212, -- MSP_SET_SERVO_CONFIGURATION
        payload = {}
    }
    rfsuite.tasks.msp.mspHelper.writeU8(message.payload, servoIndex)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, servoCenter)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, servoMin)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, servoMax)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, servoScaleNeg)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, servoScalePos)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, servoRate)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, servoSpeed)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, servoFlags)

    rfsuite.tasks.msp.mspQueue:add(message)

    -- write change to epprom
    local mspEepromWrite = {command = 250, simulatorResponse = {}}
    rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)

end

local function onSaveMenuProgress()
    rfsuite.app.ui.progressDisplay()
    saveServoSettings()
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function onSaveMenu()
    local buttons = {{
        label = i18n("app.btn_ok_long"),
        action = function()
            isSaving = true

            return true
        end
    }, {
        label = i18n("app.btn_cancel"),
        action = function()
            return true
        end
    }}
    local theTitle = i18n("app.msg_save_settings")
    local theMsg = i18n("app.msg_save_current_page")

    form.openDialog({
        width = nil,
        title = theTitle,
        message = theMsg,
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

    rfsuite.app.triggers.triggerSave = false
end

local function onNavMenu(self)

    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "servos/servos.lua", rfsuite.session.servoOverride)

end

local function wakeup(self)

    if enableWakeup == true then

        if isSaving == true then
            onSaveMenuProgress()
            isSaving = false
        end

        -- filter changes to servo center - essentially preventing queue getting flooded        
        if rfsuite.session.servoOverride == true then

            currentServoCenter = configs[servoIndex]['mid']

            local now = os.clock()
            local settleTime = 0.85
            if ((now - lastServoChangeTime) >= settleTime) and rfsuite.tasks.msp.mspQueue:isProcessed() then
                if currentServoCenter ~= lastSetServoCenter then
                    lastSetServoCenter = currentServoCenter
                    lastServoChangeTime = now
                    self.saveServoSettings(self)
                end
            end

        end
    end

    if triggerOverRide == true then
        triggerOverRide = false

        if rfsuite.session.servoOverride == false then
            rfsuite.app.audio.playServoOverideEnable = true
            rfsuite.app.ui.progressDisplay(i18n("app.modules.servos.servo_override"), i18n("app.modules.servos.enabling_servo_override"))
            rfsuite.app.Page.servoCenterFocusAllOn(self)
            rfsuite.session.servoOverride = true

            rfsuite.app.formFields[3]:enable(false)
            rfsuite.app.formFields[4]:enable(false)
            rfsuite.app.formFields[5]:enable(false)
            rfsuite.app.formFields[6]:enable(false)
            rfsuite.app.formFields[7]:enable(false)
            rfsuite.app.formFields[8]:enable(false)
            rfsuite.app.formFields[9]:enable(false)
            rfsuite.app.formFields[10]:enable(false)
            rfsuite.app.formNavigationFields['save']:enable(false)

        else

            rfsuite.app.audio.playServoOverideDisable = true
            rfsuite.app.ui.progressDisplay(i18n("app.modules.servos.servo_override"), i18n("app.modules.servos.disabling_servo_override"))
            rfsuite.app.Page.servoCenterFocusAllOff(self)
            rfsuite.session.servoOverride = false

            rfsuite.app.formFields[3]:enable(true)
            rfsuite.app.formFields[4]:enable(true)
            rfsuite.app.formFields[5]:enable(true)
            rfsuite.app.formFields[6]:enable(true)
            rfsuite.app.formFields[7]:enable(true)
            rfsuite.app.formFields[8]:enable(true)
            rfsuite.app.formFields[9]:enable(true)
            rfsuite.app.formFields[10]:enable(true)
            rfsuite.app.formNavigationFields['save']:enable(true)
        end
    end

end

local function getServoConfigurations(callback, callbackParam)
    local message = {
        command = 120, -- MSP_SERVO_CONFIGURATIONS
        processReply = function(self, buf)
            servoCount = rfsuite.tasks.msp.mspHelper.readU8(buf)

            -- update master one in case changed
            rfsuite.session.servoCount = servoCount

            rfsuite.utils.log("Servo count "..tostring(servoCount),"info")
            for i = 0, servoCount - 1 do
                local config = {}

                config.name = servoTable[servoIndex + 1]['title']
                config.mid = rfsuite.tasks.msp.mspHelper.readU16(buf)
                config.min = rfsuite.tasks.msp.mspHelper.readS16(buf)
                config.max = rfsuite.tasks.msp.mspHelper.readS16(buf)
                config.scaleNeg = rfsuite.tasks.msp.mspHelper.readU16(buf)
                config.scalePos = rfsuite.tasks.msp.mspHelper.readU16(buf)
                config.rate = rfsuite.tasks.msp.mspHelper.readU16(buf)
                config.speed = rfsuite.tasks.msp.mspHelper.readU16(buf)
                config.flags = rfsuite.tasks.msp.mspHelper.readU16(buf)

                if config.flags == 1 or config.flags == 3 then
                    config.reverse = 1
                else
                    config.reverse = 0
                end

                if config.flags == 2 or config.flags == 3 then
                    config.geometry = 1
                else
                    config.geometry = 0
                end

                configs[i] = config

            end
            callback(callbackParam)
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
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function getServoConfigurationsEnd(callbackParam)
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function openPage(idx, title, script, extra1)

    if extra1 ~= nil then
        servoTable = extra1
        rfsuite.servoTableLast = servoTable
    else
        if rfsuite.servoTableLast ~= nil then servoTable = rfsuite.servoTableLast end
    end

    configs = {}
    configs[servoIndex] = {}
    configs[servoIndex]['name'] = servoTable[servoIndex + 1]['title']
    configs[servoIndex]['mid'] = 0
    configs[servoIndex]['min'] = 0
    configs[servoIndex]['max'] = 0
    configs[servoIndex]['scaleNeg'] = 0
    configs[servoIndex]['scalePos'] = 0
    configs[servoIndex]['rate'] = 0
    configs[servoIndex]['speed'] = 0
    configs[servoIndex]['flags'] = 0
    configs[servoIndex]['geometry'] = 0
    configs[servoIndex]['reverse'] = 0

    rfsuite.app.formLines = {}

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    form.clear()

    if rfsuite.app.Page.pageTitle ~= nil then
        rfsuite.app.ui.fieldHeader(rfsuite.app.Page.pageTitle .. " / " .. rfsuite.app.utils.titleCase(configs[servoIndex]['name']))
    else
        rfsuite.app.ui.fieldHeader(title .. " / " .. rfsuite.app.utils.titleCase(configs[servoIndex]['name']))
    end

    if rfsuite.app.Page.headerLine ~= nil then
        local headerLine = form.addLine("")
        local headerLineText = form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, rfsuite.app.Page.headerLine)
    end

    if rfsuite.session.servoOverride == true then rfsuite.app.formNavigationFields['save']:enable(false) end

    if configs[servoIndex]['mid'] ~= nil then

        local idx = 2
        local minValue = 50
        local maxValue = 2250
        local defaultValue = 1500
        local suffix = nil
        local helpTxt = rfsuite.app.fieldHelpTxt['servoMid']['t']

        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.center"))
        rfsuite.app.formFields[idx] = form.addNumberField(rfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['mid']
        end, function(value)
            configs[servoIndex]['mid'] = value
        end)
        if suffix ~= nil then rfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then rfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then rfsuite.app.formFields[idx]:help(helpTxt) end
    end

    if configs[servoIndex]['min'] ~= nil then
        local idx = 3
        local minValue = -1000
        local maxValue = 1000
        local defaultValue = -700
        local suffix = nil
        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.minimum"))
        local helpTxt = rfsuite.app.fieldHelpTxt['servoMin']['t']
        rfsuite.app.formFields[idx] = form.addNumberField(rfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['min']
        end, function(value)
            configs[servoIndex]['min'] = value
        end)
        if suffix ~= nil then rfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then rfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then rfsuite.app.formFields[idx]:help(helpTxt) end
        if rfsuite.session.servoOverride == true then rfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['max'] ~= nil then
        local idx = 4
        local minValue = -1000
        local maxValue = 1000
        local defaultValue = 700
        local suffix = nil
        local helpTxt = rfsuite.app.fieldHelpTxt['servoMax']['t']
        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.maximum"))
        rfsuite.app.formFields[idx] = form.addNumberField(rfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['max']
        end, function(value)
            configs[servoIndex]['max'] = value
        end)
        if suffix ~= nil then rfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then rfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then rfsuite.app.formFields[idx]:help(helpTxt) end
        if rfsuite.session.servoOverride == true then rfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['scaleNeg'] ~= nil then
        local idx = 5
        local minValue = 100
        local maxValue = 1000
        local defaultValue = 500
        local suffix = nil
        local helpTxt = rfsuite.app.fieldHelpTxt['servoScaleNeg']['t']
        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.scale_negative"))
        rfsuite.app.formFields[idx] = form.addNumberField(rfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['scaleNeg']
        end, function(value)
            configs[servoIndex]['scaleNeg'] = value
        end)
        if suffix ~= nil then rfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then rfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then rfsuite.app.formFields[idx]:help(helpTxt) end
        if rfsuite.session.servoOverride == true then rfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['scalePos'] ~= nil then
        local idx = 6
        local minValue = 100
        local maxValue = 1000
        local defaultValue = 500
        local suffix = nil
        local helpTxt = rfsuite.app.fieldHelpTxt['servoScalePos']['t']
        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.scale_positive"))
        rfsuite.app.formFields[idx] = form.addNumberField(rfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['scalePos']
        end, function(value)
            configs[servoIndex]['scalePos'] = value
        end)
        if suffix ~= nil then rfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then rfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then rfsuite.app.formFields[idx]:help(helpTxt) end
        if rfsuite.session.servoOverride == true then rfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['rate'] ~= nil then
        local idx = 7
        local minValue = 50
        local maxValue = 5000
        local defaultValue = 333
        local suffix = i18n("app.unit_hertz")
        local helpTxt = rfsuite.app.fieldHelpTxt['servoRate']['t']
        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.rate"))
        rfsuite.app.formFields[idx] = form.addNumberField(rfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['rate']
        end, function(value)
            configs[servoIndex]['rate'] = value
        end)
        if suffix ~= nil then rfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then rfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then rfsuite.app.formFields[idx]:help(helpTxt) end
        if rfsuite.session.servoOverride == true then rfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['speed'] ~= nil then
        local idx = 8
        local minValue = 0
        local maxValue = 60000
        local defaultValue = 0
        local suffix = "ms"
        local helpTxt = rfsuite.app.fieldHelpTxt['servoSpeed']['t']
        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.speed"))
        rfsuite.app.formFields[idx] = form.addNumberField(rfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['speed']
        end, function(value)
            configs[servoIndex]['speed'] = value
        end)
        if suffix ~= nil then rfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then rfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then rfsuite.app.formFields[idx]:help(helpTxt) end
        if rfsuite.session.servoOverride == true then rfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['flags'] ~= nil then
        local idx = 9
        local minValue = 0
        local maxValue = 1000
        local table = {i18n("app.modules.servos.tbl_no"), i18n("app.modules.servos.tbl_yes")}
        local tableIdxInc = -1
        local value
        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.reverse"))
        rfsuite.app.formFields[idx] = form.addChoiceField(rfsuite.app.formLines[idx], nil, rfsuite.app.utils.convertPageValueTable(table, tableIdxInc), function()
            return configs[servoIndex]['reverse']
        end, function(value)
            configs[servoIndex]['reverse'] = value
        end)
        if rfsuite.session.servoOverride == true then rfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['flags'] ~= nil then
        local idx = 10
        local minValue = 0
        local maxValue = 1000
        local table = {i18n("app.modules.servos.tbl_no"), i18n("app.modules.servos.tbl_yes")}
        local tableIdxInc = -1
        local value
        rfsuite.app.formLines[idx] = form.addLine(i18n("app.modules.servos.geometry"))
        rfsuite.app.formFields[idx] = form.addChoiceField(rfsuite.app.formLines[idx], nil, rfsuite.app.utils.convertPageValueTable(table, tableIdxInc), function()
            return configs[servoIndex]['geometry']
        end, function(value)
            configs[servoIndex]['geometry'] = value
        end)
        if rfsuite.session.servoOverride == true then rfsuite.app.formFields[idx]:enable(false) end
    end

    getServoConfigurations(getServoConfigurationsEnd)

end

local function event(widget, category, value, x, y)

    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pidx, i18n("app.modules.servos.name"), "servos/servos.lua", rfsuite.session.servoOverride)
        return true
    end

end

local function onToolMenu(self)

    local buttons
    if rfsuite.session.servoOverride == false then
        buttons = {{
            label = i18n("app.btn_ok_long"),
            action = function()

                -- we cant launch the loader here to se rely on the modules
                -- wakeup function to do this
                triggerOverRide = true
                triggerOverRideAll = true
                return true
            end
        }, {
            label = i18n("app.btn_cancel"),
            action = function()
                return true
            end
        }}
    else
        buttons = {{
            label = i18n("app.btn_ok_long"),
            action = function()

                -- we cant launch the loader here to se rely on the modules
                -- wakeup function to do this
                triggerOverRide = true
                return true
            end
        }, {
            label = i18n("app.btn_cancel"),
            action = function()
                return true
            end
        }}
    end
    local message
    local title
    if rfsuite.session.servoOverride == false then
        title = i18n("app.modules.servos.enable_servo_override")
        message = i18n("app.modules.servos.enable_servo_override_msg")
    else
        title = i18n("app.modules.servos.disable_servo_override")
        message = i18n("app.modules.servos.disable_servo_override_msg")
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

local function onReloadMenu()
    rfsuite.app.triggers.triggerReloadFull = true
end

return {
    -- not changing to custom api at present due to complexity of read/write scenario in these modules
    reboot = false,
    event = event,
    setValues = setValues,
    servoChanged = servoChanged,
    servoCenterFocusOn = servoCenterFocusOn,
    servoCenterFocusOff = servoCenterFocusOff,
    servoCenterFocusAllOn = servoCenterFocusAllOn,
    servoCenterFocusAllOff = servoCenterFocusAllOff,
    saveServoSettings = saveServoSettings,
    onToolMenu = onToolMenu,
    wakeup = wakeup,
    openPage = openPage,
    onNavMenu = onNavMenu,
    onSaveMenu = onSaveMenu,
    onReloadMenu = onReloadMenu,
    navButtons = {menu = true, save = true, reload = true, tool = true, help = true},
    API = {},

}
