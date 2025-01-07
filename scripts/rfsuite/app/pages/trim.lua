local labels = {}
local fields = {}

local triggerOverRide = false
local inOverRide = false
local lastChangeTime = os.clock()
local currentRollTrim
local currentRollTrimLast
local currentPitchTrim
local currentPitchTrimLast
local currentCollectiveTrim
local currentCollectiveTrimLast
local currentYawTrim
local currentYawTrimLast
local currentIdleThrottleTrim
local currentIdleThrottleTrimLast

fields[#fields + 1] = {t = "Roll trim %", help = "mixerSwashTrim", xlabel = "line5", xinline = 1, min = -1000, max = 1000, vals = {12, 13}, decimals = 1, scale = 10}

fields[#fields + 1] = {t = "Pitch trim %", help = "mixerSwashTrim", xlabel = "line6", xinline = 1, min = -1000, max = 1000, vals = {14, 15}, decimals = 1, scale = 10}

fields[#fields + 1] = {t = "Col. trim %", help = "mixerSwashTrim", xlabel = "line7", xinline = 1, min = -1000, max = 1000, vals = {16, 17}, decimals = 1, scale = 10}

-- note.  the same vals are used for center trim motor and yaw trim - but they are multiplied and saved in different ways
if rfsuite.config.tailMode == 1 or rfsuite.config.tailMode == 2 then fields[#fields + 1] = {t = "Center trim for tail motor %", help = "mixerTailMotorCenterTrim", inline = 1, min = -500, max = 500, vals = {4, 5}, decimals = 1, scale = 10} end

if rfsuite.config.tailMode == 0 then fields[#fields + 1] = {t = "Yaw. trim %", help = "mixerTailMotorCenterTrim", inline = 1, min = -1043, max = 1043, vals = {4, 5}, mult = 0.0239923224568138, decimals = 1} end

local function saveData()

    local payload = rfsuite.app.Page.values
    local message = {command = 43, payload = payload}
    rfsuite.bg.msp.mspQueue:add(message)

    local message = {command = 250, payload = {}}
    rfsuite.bg.msp.mspQueue:add(message)

end

local function mixerOn(self)

    rfsuite.app.audio.playMixerOverideEnable = true

    for i = 1, 4 do

        local message = {
            command = 191, -- MSP_SET_SERVO_OVERRIDE
            payload = {i}
        }
        rfsuite.bg.msp.mspHelper.writeU16(message.payload, 0)
        rfsuite.bg.msp.mspQueue:add(message)

    end

    rfsuite.app.triggers.isReady = true
end

local function mixerOff(self)

    rfsuite.app.audio.playMixerOverideDisable = true

    for i = 1, 4 do
        local message = {
            command = 191, -- MSP_SET_SERVO_OVERRIDE
            payload = {i}
        }
        rfsuite.bg.msp.mspHelper.writeU16(message.payload, 2501)
        rfsuite.bg.msp.mspQueue:add(message)
    end

    rfsuite.app.triggers.isReady = true
end

local function postLoad(self)

    if rfsuite.config.tailMode == nil then
        local v = rfsuite.app.Page.values[2]
        rfsuite.config.tailMode = math.floor(v)
        rfsuite.app.triggers.reload = true
        return
    end

    -- existing
    currentRollTrim = rfsuite.app.Page.fields[1].value
    currentPitchTrim = rfsuite.app.Page.fields[2].value
    currentCollectiveTrim = rfsuite.app.Page.fields[3].value

    if rfsuite.config.tailModeActive == 1 or rfsuite.config.tailModeActive == 2 then currentIdleThrottleTrim = rfsuite.app.Page.fields[4].value end

    if rfsuite.config.tailModeActive == 0 then currentYawTrim = rfsuite.app.Page.fields[4].value end
    rfsuite.app.triggers.isReady = true
end

local function wakeup(self)

    -- filter changes to mixer - essentially preventing queue getting flooded	
    if inOverRide == true then

        currentRollTrim = rfsuite.app.Page.fields[1].value
        local now = os.clock()
        local settleTime = 0.85
        if ((now - lastChangeTime) >= settleTime) and rfsuite.bg.msp.mspQueue:isProcessed() then
            if currentRollTrim ~= currentRollTrimLast then
                currentRollTrimLast = currentRollTrim
                lastChangeTime = now
                self.saveData(self)
            end
        end

        currentPitchTrim = rfsuite.app.Page.fields[2].value
        local now = os.clock()
        local settleTime = 0.85
        if ((now - lastChangeTime) >= settleTime) and rfsuite.bg.msp.mspQueue:isProcessed() then
            if currentPitchTrim ~= currentPitchTrimLast then
                currentPitchTrimLast = currentPitchTrim
                lastChangeTime = now
                self.saveData(self)
            end
        end

        currentCollectiveTrim = rfsuite.app.Page.fields[3].value
        local now = os.clock()
        local settleTime = 0.85
        if ((now - lastChangeTime) >= settleTime) and rfsuite.bg.msp.mspQueue:isProcessed() then
            if currentCollectiveTrim ~= currentCollectiveTrimLast then
                currentCollectiveTrimLast = currentCollectiveTrim
                lastChangeTime = now
                self.saveData(self)
            end
        end

        if rfsuite.config.tailMode == 1 or rfsuite.config.tailMode == 2 then
            currentIdleThrottleTrim = rfsuite.app.Page.fields[4].value
            local now = os.clock()
            local settleTime = 0.85
            if ((now - lastChangeTime) >= settleTime) and rfsuite.bg.msp.mspQueue:isProcessed() then
                if currentIdleThrottleTrim ~= currentIdleThrottleTrimLast then
                    currentIdleThrottleTrimLast = currentIdleThrottleTrim
                    lastChangeTime = now
                    self.saveData(self)
                end
            end
        end

        if rfsuite.config.tailMode == 0 then
            currentYawTrim = rfsuite.app.Page.fields[4].value
            local now = os.clock()
            local settleTime = 0.85
            if ((now - lastChangeTime) >= settleTime) and rfsuite.bg.msp.mspQueue:isProcessed() then
                if currentYawTrim ~= currentYawTrimLast then
                    currentYawTrimLast = currentYawTrim
                    lastChangeTime = now
                    self.saveData(self)
                end
            end
        end

    end

    if triggerOverRide == true then
        triggerOverRide = false

        if inOverRide == false then

            rfsuite.app.audio.playMixerOverideEnable = true

            rfsuite.app.ui.progressDisplay("Mixer override", "Enabling mixer override...")

            rfsuite.app.Page.mixerOn(self)
            inOverRide = true
        else

            rfsuite.app.audio.playMixerOverideDisable = true

            rfsuite.app.ui.progressDisplay("Mixer override", "Disabling mixer override...")

            rfsuite.app.Page.mixerOff(self)
            inOverRide = false
        end
    end

end

local function onToolMenu(self)

    local buttons = {{
        label = "                OK                ",
        action = function()

            -- we cant launch the loader here to se rely on the modules
            -- wakup function to do this
            triggerOverRide = true
            return true
        end
    }, {
        label = "CANCEL",
        action = function()
            return true
        end
    }}
    local message
    local title
    if inOverRide == false then
        title = "Enable mixer override"
        message = "Set all servos to their configured center position. \r\n\r\nThis will result in all values on this page being saved when adjusting the servo trim."
    else
        title = "Disable mixer override"
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

local function onNavMenu(self)

    if inOverRide == true or inFocus == true then
        rfsuite.app.audio.playMixerOverideDisable = true

        inOverRide = false
        inFocus = false

        rfsuite.app.ui.progressDisplay("Mixer override", "Disabling mixer override...")

        mixerOff(self)
        rfsuite.app.triggers.closeProgressLoader = true
    end

    rfsuite.app.ui.openMainMenu()

end

return {
    read = 42, -- msp_MIXER_CONFIG
    write = 43, -- msp_SET_MIXER_CONFIG
    eepromWrite = true,
    reboot = false,
    title = "Mixer",
    simulatorResponse = {0, 1, 0, 0, 0, 2, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    minBytes = 19,
    labels = labels,
    fields = fields,
    mixerOff = mixerOff,
    mixerOn = mixerOn,
    postLoad = postLoad,
    onToolMenu = onToolMenu,
    onNavMenu = onNavMenu,
    wakeup = wakeup,
    saveData = saveData,
    navButtons = {menu = true, save = true, reload = true, tool = true, help = true}
}
