--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local currentProfileChecked = false
local firstLoad = true
local minMaxIndex = 1

local ch = rfsuite.currentFbusServoIndex
local ch_str = "@i18n(app.modules.fbusout.ch_prefix)@" .. tostring(ch + 1)
local offset = 6 * ch

local servoCount = rfsuite.session.servoCount or 6
local motorCount = 1
if rfsuite.session.tailMode == 0 then motorCount = 2 end

local isSaving = false


local minmax = {}
minmax[0] = {min = 500, max = 2000, sourceMax = 24, defaultMin = 1000, defaultMax = 2000}           -- none
minmax[1] = {min = 500, max = 2000, sourceMax = 24, defaultMin = 1000, defaultMax = 2000}           -- rx
minmax[2] = {min = -1000, max = 1000, sourceMax = 24, defaultMin = -1000, defaultMax = 1000}        -- mixer
minmax[3] = {min = 500, max = 2000, sourceMax = servoCount, defaultMin = 1000, defaultMax = 2000}   -- servo
minmax[4] = {min = 0, max = 1000, sourceMax = motorCount, defaultMin = 0, defaultMax = 1000}        -- motor

local enableWakeup = false

local apidata = {
    api = {[1] = "FBUS_MASTER_CHANNEL"},
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.fbusout.type)@", min = 0, max = 16, mspapi = 1, apikey = "source_type", table = {[0] = "NONE", [1] = "@i18n(app.modules.fbusout.receiver)@", [2] = "@i18n(app.modules.fbusout.mixer)@", [3] = "@i18n(app.modules.fbusout.servo)@", [4] = "@i18n(app.modules.fbusout.motor)@"}, postEdit = function(self) self.setMinMaxIndex(self, true) end}, 
            {t = "@i18n(app.modules.fbusout.source)@", min = 0, max = 15, mspapi = 1, apikey = "source_index", help = "fbusOutSource"},
            {t = "@i18n(app.modules.fbusout.min)@", min = -2000, max = 2000, mspapi = 1, apikey = "source_range_low", help = "fbusOutMin"}, {t = "@i18n(app.modules.fbusout.max)@", min = -2000, max = 2000, mspapi = 1, apikey = "source_range_high", help = "fbusOutMax"}
        }
    }
}

local function saveToEeprom()
    local mspEepromWrite = {
        command = 250, 
        simulatorResponse = {}, 
        processReply = function() rfsuite.utils.log("EEPROM write command sent","info") end
    }
    rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
end

local function saveServoSettings(self)

    local mixIndex = rfsuite.currentFbusServoIndex
    local mixType = math.floor(rfsuite.app.Page.apidata.formdata.fields[1].value)
    local mixSource = math.floor(rfsuite.app.Page.apidata.formdata.fields[2].value)
    local mixMin = math.floor(rfsuite.app.Page.apidata.formdata.fields[3].value)
    local mixMax = math.floor(rfsuite.app.Page.apidata.formdata.fields[4].value)

    local message = {command = 162, payload = {}, processReply = function() saveToEeprom() end}
    rfsuite.tasks.msp.mspHelper.writeU8(message.payload, mixIndex)
    rfsuite.tasks.msp.mspHelper.writeU8(message.payload, mixType)
    rfsuite.tasks.msp.mspHelper.writeU8(message.payload, mixSource)
    rfsuite.tasks.msp.mspHelper.writeS16(message.payload, mixMin)
    rfsuite.tasks.msp.mspHelper.writeS16(message.payload, mixMax)

    rfsuite.tasks.msp.mspQueue:add(message)

end

local function onSaveMenuProgress()
    rfsuite.app.ui.progressDisplay("@i18n(app.modules.fbusout.saving)@", "@i18n(app.modules.fbusout.saving_data)@")
    saveServoSettings()
    rfsuite.app.triggers.isReady = true
    rfsuite.app.triggers.closeProgressLoader = true
end

local function setMinMaxIndex(self)
    minMaxIndex = math.floor(rfsuite.app.Page.apidata.formdata.fields[1].value)

    if firstLoad == true then
        firstLoad = false
    else

        local defaultMin = minmax[minMaxIndex].defaultMin
        local defaultMax = minmax[minMaxIndex].defaultMax
        local currentSourceMax = minmax[minMaxIndex].sourceMax

        rfsuite.app.Page.apidata.formdata.fields[2].value = 0
        rfsuite.app.Page.apidata.formdata.fields[3].value = defaultMin
        rfsuite.app.Page.apidata.formdata.fields[4].value = defaultMax

    end
end

local function postLoad(self)

    setMinMaxIndex(self)

    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function onNavMenu(self)

    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "servos/tools/fbus.lua")

end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(rfsuite.app.lastIdx, rfsuite.app.lastTitle, "servos/tools/fbus.lua")
        return true
    end

end

local function onSaveMenu()

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        isSaving = true
        return
    end  

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                isSaving = true

                return true
            end
        }, {label = "@i18n(app.modules.fbusout.cancel)@", action = function() return true end}
    }
    local theTitle = "@i18n(app.modules.fbusout.save_settings)@"
    local theMsg = "@i18n(app.modules.fbusout.save_prompt)@"

    form.openDialog({width = nil, title = theTitle, message = theMsg, buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

    rfsuite.app.triggers.triggerSave = false
end

local function wakeup()

    if enableWakeup == true then

        if isSaving == true then
            onSaveMenuProgress()
            isSaving = false
        end

        if minmax == nil then return end

        local currentMin = minmax[minMaxIndex].min
        local currentMax = minmax[minMaxIndex].max
        local currentSourceMax = minmax[minMaxIndex].sourceMax

        if rfsuite.app.Page.apidata.formdata.fields[2].value and rfsuite.app.Page.apidata.formdata.fields[2].value >= currentSourceMax then rfsuite.app.Page.apidata.formdata.fields[2].value = currentSourceMax end

        if rfsuite.app.Page.apidata.formdata.fields[3].value and rfsuite.app.Page.apidata.formdata.fields[3].value <= currentMin then rfsuite.app.Page.apidata.formdata.fields[3].value = currentMin end
        if rfsuite.app.Page.apidata.formdata.fields[3].value and rfsuite.app.Page.apidata.formdata.fields[3].value >= currentMax then rfsuite.app.Page.apidata.formdata.fields[3].value = currentMax end

        if rfsuite.app.Page.apidata.formdata.fields[4].value and rfsuite.app.Page.apidata.formdata.fields[4].value >= currentMax then rfsuite.app.Page.apidata.formdata.fields[4].value = currentMax end
        if rfsuite.app.Page.apidata.formdata.fields[4].value and rfsuite.app.Page.apidata.formdata.fields[4].value <= currentMin then rfsuite.app.Page.apidata.formdata.fields[4].value = currentMin end

        -- go back to main as this tool is compromised 
        if rfsuite.session.servoCount == nil or rfsuite.session.servoOverride == nil then
            rfsuite.app.ui.openMainMenu()
            return
        end

    end
end

local function onReloadMenu() rfsuite.app.triggers.triggerReloadFull = true end

return {apidata = apidata, reboot = false, eepromWrite = true, postLoad = postLoad, onNavMenu = onNavMenu, onReloadMenu = onReloadMenu, onSaveMenu = onSaveMenu, setMinMaxIndex = setMinMaxIndex, wakeup = wakeup, navButtons = {menu = true, save = true, reload = true, tool = false, help = true}, event = event, API = {}}