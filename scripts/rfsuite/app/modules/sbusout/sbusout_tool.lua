
local arg = {...}

local currentProfileChecked = false
local firstLoad = true
local minMaxIndex
-- local sbus_out_frame_rate

local ch = rfsuite.currentSbusServoIndex
local ch_str = "CH" .. tostring(ch + 1)
local offset = 6 * ch -- 6 bytes per channel

local servoCount = rfsuite.session.servoCount or 6
local motorCount = 1
if rfsuite.session.tailMode == 0 then motorCount = 2 end

local minmax = {}
minmax[1] = {min = 500, max = 2000, sourceMax = 24, defaultMin = 1000, defaultMax = 2000} -- Receiver
minmax[2] = {min = -1000, max = 1000, sourceMax = 24, defaultMin = -1000, defaultMax = 1000} -- Mixer
minmax[3] = {min = 1000, max = 2000, sourceMax = servoCount, defaultMin = 1000, defaultMax = 2000} -- Servo
minmax[4] = {min = 0, max = 1000, sourceMax = motorCount, defaultMin = 0, defaultMax = 1000} -- Motor

local enableWakeup = false

local mspapi = {
    api = {
        [1] = "SBUS_OUTPUT_CONFIG",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Type", min=0, max = 16, mspapi = 1, apikey="Type_"..ch+1, table = {"Receiver", "Mixer", "Servo", "Motor"}, postEdit = function(self) self.setMinMaxIndex(self, true) end},
            {t = "Source", min=0, max = 15, mspapi = 1, apikey = "Index_"..ch+1, help = "sbusOutSource"},
            {t = "Min", min = -2000, max = 2000, mspapi = 1, apikey="RangeLow_"..ch+1, help = "sbusOutMin"},
            {t = "Max", min = -2000, max = 2000, mspapi = 1, apikey="RangeHigh_"..ch+1 ,help = "sbusOutMax"},
        }
    }                 
}


local function saveServoSettings(self)

    local mixIndex = rfsuite.currentSbusServoIndex
    local mixType = math.floor(rfsuite.app.Page.fields[1].value)
    local mixSource = math.floor(rfsuite.app.Page.fields[2].value)
    local mixMin = math.floor(rfsuite.app.Page.fields[3].value)
    local mixMax = math.floor(rfsuite.app.Page.fields[4].value)
    -- if sbus_out_frame_rate == nil then sbus_out_frame_rate = 250 end
    -- local frameRate = sbus_out_frame_rate

    local message = {
        command = 153, -- MSP_SET_SERVO_CONFIGURATION
        payload = {}
    }
    rfsuite.tasks.msp.mspHelper.writeU8(message.payload, mixIndex)
    rfsuite.tasks.msp.mspHelper.writeU8(message.payload, mixType)
    rfsuite.tasks.msp.mspHelper.writeU8(message.payload, mixSource)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, mixMin)
    rfsuite.tasks.msp.mspHelper.writeU16(message.payload, mixMax)
    -- rfsuite.tasks.msp.mspHelper.writeU8(message.payload, frameRate)

    if rfsuite.config.logMSP then
        local logData = "{" .. rfsuite.utils.joinTableItems(message.payload, ", ") .. "}"
        rfsuite.utils.log(logData,"info")
    end

    rfsuite.tasks.msp.mspQueue:add(message)

    -- write change to epprom
    local mspEepromWrite = {command = 153, simulatorResponse = {}}
    rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)

end

local function onSaveMenuProgress()
    rfsuite.app.ui.progressDisplay("Saving", "Saving data...")
    saveServoSettings()
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

-- function to set min and max value based on index.
local function setMinMaxIndex(self)
    minMaxIndex = math.floor(rfsuite.app.Page.fields[1].value)

    if firstLoad == true then
        firstLoad = false
    else
        -- default all values
        local defaultMin = minmax[minMaxIndex].defaultMin
        local defaultMax = minmax[minMaxIndex].defaultMax
        local currentSourceMax = minmax[minMaxIndex].sourceMax

        rfsuite.app.Page.fields[2].value = 0
        rfsuite.app.Page.fields[3].value = defaultMin
        rfsuite.app.Page.fields[4].value = defaultMax

    end
end

local function postLoad(self)

    setMinMaxIndex(self)

    -- the sbus output rate is last value. we dont use it - but we need it for writes so grab it here
    -- sbus_out_frame_rate = rfsuite.app.Page.values[#rfsuite.app.Page.values]

    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function onNavMenu(self)

    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "sbusout/sbusout.lua")

end

local function onSaveMenu()
    local buttons = {{
        label = "                OK                ",
        action = function()
            rfsuite.app.audio.playSaving = true
            isSaving = true

            return true
        end
    }, {
        label = "CANCEL",
        action = function()
            return true
        end
    }}
    local theTitle = "Save settings"
    local theMsg = "Save current page to flight controller?"

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

local function wakeup()

    if enableWakeup == true then

        if isSaving == true then
            onSaveMenuProgress()
            isSaving = false
        end

        -- to avoid a page reload we contrain the field values using a wakeup call.
        -- we could use postEdit on the fields line - but this does not update until 
        -- you exit the field!
        local currentMin = minmax[minMaxIndex].min
        local currentMax = minmax[minMaxIndex].max
        local currentSourceMax = minmax[minMaxIndex].sourceMax

        -- set min and max values
        if rfsuite.app.Page.fields[2].value >= currentSourceMax then rfsuite.app.Page.fields[2].value = currentSourceMax end

        -- handle min value
        if rfsuite.app.Page.fields[3].value <= currentMin then rfsuite.app.Page.fields[3].value = currentMin end
        if rfsuite.app.Page.fields[3].value >= currentMax then rfsuite.app.Page.fields[3].value = currentMax end

        -- handle max value
        if rfsuite.app.Page.fields[4].value >= currentMax then rfsuite.app.Page.fields[4].value = currentMax end
        if rfsuite.app.Page.fields[4].value <= currentMin then rfsuite.app.Page.fields[4].value = currentMin end

    end
end

-- not changing to api for this module due to the unusual read/write scenario.
-- its not worth the effort
return {
    mspapi = mspapi,
    title = "SBUS Output",
    reboot = false,
    eepromWrite = true,
    postLoad = postLoad,
    onNavMenu = onNavMenu,
    onSaveMenu = onSaveMenu,
    setMinMaxIndex = setMinMaxIndex,
    wakeup = wakeup,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = true},
    API = {},
}
