
local arg = {...}

local currentProfileChecked = false
local firstLoad = true
local minMaxIndex = 1
-- local sbus_out_frame_rate

local ch = rfsuite.currentSbusServoIndex
local ch_str = "@i18n(app.modules.sbusout.ch_prefix)@" .. tostring(ch + 1)
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

local apidata = {
    api = {
        [1] = "SBUS_OUTPUT_CONFIG",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.sbusout.type)@", min=0, max = 16, mspapi = 1, apikey="Type_"..ch+1, table = {[0] = "@i18n(app.modules.sbusout.receiver)@", "@i18n(app.modules.sbusout.mixer)@", "@i18n(app.modules.sbusout.servo)@", "@i18n(app.modules.sbusout.motor)@"}, postEdit = function(self) self.setMinMaxIndex(self, true) end},
            {t = "@i18n(app.modules.sbusout.source)@", min=0, max = 15, mspapi = 1, apikey = "Index_"..ch+1, help = "sbusOutSource"},
            {t = "@i18n(app.modules.sbusout.min)@", min = -2000, max = 2000, mspapi = 1, apikey="RangeLow_"..ch+1, help = "sbusOutMin"},
            {t = "@i18n(app.modules.sbusout.max)@", min = -2000, max = 2000, mspapi = 1, apikey="RangeHigh_"..ch+1 ,help = "sbusOutMax"},
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


    rfsuite.tasks.msp.mspQueue:add(message)

    -- write change to epprom
    local mspEepromWrite = {command = 153, simulatorResponse = {}}
    rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)

end

local function onSaveMenuProgress()
    rfsuite.app.ui.progressDisplay("@i18n(app.modules.sbusout.saving)@", "@i18n(app.modules.sbusout.saving_data)@")
    saveServoSettings()
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

-- function to set min and max value based on index.
local function setMinMaxIndex(self)
    minMaxIndex = math.floor(rfsuite.app.Page.fields[1].value + 1) 


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

local function event(widget, category, value, x, y)

    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.progressDisplay()
        rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "sbusout/sbusout.lua")
        return true
    end


end

local function onSaveMenu()
    local buttons = {{
        label = "@i18n(app.btn_ok_long)@",
        action = function()
            isSaving = true

            return true
        end
    }, {
        label = "@i18n(app.modules.sbusout.cancel)@",
        action = function()
            return true
        end
    }}
    local theTitle = "@i18n(app.modules.sbusout.save_settings)@"
    local theMsg = "@i18n(app.modules.sbusout.save_prompt)@"

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

        if minmax == nil then return end


        local currentMin = minmax[minMaxIndex].min 
        local currentMax = minmax[minMaxIndex].max 
        local currentSourceMax = minmax[minMaxIndex].sourceMax

 

        -- set min and max values
         if rfsuite.app.Page.fields[2].value and rfsuite.app.Page.fields[2].value >= currentSourceMax then rfsuite.app.Page.fields[2].value = currentSourceMax end

        -- handle min value
         if rfsuite.app.Page.fields[3].value and rfsuite.app.Page.fields[3].value <= currentMin then rfsuite.app.Page.fields[3].value = currentMin end
         if rfsuite.app.Page.fields[3].value and rfsuite.app.Page.fields[3].value >= currentMax then rfsuite.app.Page.fields[3].value = currentMax end

        -- handle max value
         if rfsuite.app.Page.fields[4].value and rfsuite.app.Page.fields[4].value >= currentMax then rfsuite.app.Page.fields[4].value = currentMax end
         if rfsuite.app.Page.fields[4].value and rfsuite.app.Page.fields[4].value <= currentMin then rfsuite.app.Page.fields[4].value = currentMin end

    end
end

-- not changing to api for this module due to the unusual read/write scenario.
-- its not worth the effort
return {
    apidata = apidata,
    reboot = false,
    eepromWrite = true,
    postLoad = postLoad,
    onNavMenu = onNavMenu,
    onSaveMenu = onSaveMenu,
    setMinMaxIndex = setMinMaxIndex,
    wakeup = wakeup,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = true},
    event = event,
    API = {},
}
