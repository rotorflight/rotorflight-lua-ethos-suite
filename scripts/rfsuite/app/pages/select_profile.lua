local fields = {}
local labels = {}
local fcStatus = {}
local dataflashSummary = {}
local wakeupScheduler = os.clock()
local status = {}
local summary = {}
local triggerEraseDataFlash = false
local enableWakeup = false
local triggerSave = false
local saveCounter = 0
local triggerSaveCounter = false
local triggerMSPWrite = false

fields[1] = {t = "PID profile", value = "0", vals = {24}, type = 1, table = {"1", "2", "3", "4", "5", "6"}, tableIdxInc = -1}
fields[2] = {t = "Rate Profile", value = "0", vals = {26}, type = 1, table = {"1", "2", "3", "4", "5", "6"}, tableIdxInc = -1}

local function postLoad(self)
    rfsuite.app.triggers.isReady = true
end

local function postRead(self)
end

local function setPidProfile(profileIndex)
    local message = {
        command = 210, -- MSP_SELECT_SETTING
        payload = {profileIndex},
        processReply = function(self, buf)
        end,
        simulatorResponse = {}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

local function setRateProfile(profileIndex)
    profileIndex = profileIndex + 128
    local message = {
        command = 210, -- MSP_SELECT_SETTING
        payload = {profileIndex},
        processReply = function(self, buf)
        end,
        simulatorResponse = {}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

local function onSaveMenu()

    local buttons = {{
        label = "                OK                ",
        action = function()
            triggerSave = true
            return true
        end
    }, {
        label = "CANCEL",
        action = function()
            triggerSave = false
            return true
        end
    }}

    form.openDialog({
        width = nil,
        title = "Save settings",
        message = "Save current page to flight controller?",
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

    triggerSave = false

end

local function wakeup()

    -- display the dialog box
    if triggerSave == true then
        rfsuite.app.ui.progressDisplaySave()
        triggerSaveCounter = true
        triggerMSPWrite = true
        triggerSave = false
    end

    -- step through the values
    if triggerSaveCounter == true then
        saveCounter = saveCounter + 10
        rfsuite.app.ui.progressDisplaySaveValue(saveCounter, message)
        if saveCounter >= 100 then
            saveCounter = 0
            triggerSaveCounter = false
            rfsuite.app.dialogs.saveDisplay = false
            rfsuite.app.ui.progressDisplaySaveClose()
            rfsuite.app.dialogs.progressDisplay = false
            rfsuite.app.triggers.isReady = true
        end
    end

    if triggerMSPWrite == true then
        triggerMSPWrite = false

        local profileIndex = rfsuite.app.Page.fields[1].value
        local rateIndex = rfsuite.app.Page.fields[2].value
        setRateProfile(rateIndex)
        setPidProfile(profileIndex)
    end

end

return {
    read = 101,
    write = nil,
    title = "Select Profile",
    reboot = false,
    eepromWrite = false,
    minBytes = 30,
    labels = labels,
    fields = fields,
    wakeup = wakeup,
    onSaveMenu = onSaveMenu,
    refreshOnProfileChange = true,
    simulatorResponse = {240, 1, 124, 0, 35, 0, 0, 0, 0, 0, 0, 224, 1, 10, 1, 0, 26, 0, 0, 0, 0, 0, 2, 0, 6, 0, 6, 1, 4, 1},
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = false, tool = false, help = true}
}
