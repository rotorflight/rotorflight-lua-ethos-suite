local labels = {}
local fields = {}

local calibrate = false
local calibrateComplete = false
local activateWakeup = false

local i18n = rfsuite.i18n.get

local apidata = {
    api = {
        [1] = 'BOARD_ALIGNMENT',
    },
    formdata = {
        labels = {
            { t = i18n("app.modules.gyro_alignment.board_alignment"), label = 1, inline_size = 13.6 },
        },
        fields = {
            -- Board alignment fields
            {t = i18n("app.modules.gyro_alignment.roll"), inline = 3, label = 1, mspapi=1, apikey="roll"},
            {t = i18n("app.modules.gyro_alignment.pitch"), inline = 2, label = 1, mspapi=1, apikey="pitch"},
            {t = i18n("app.modules.gyro_alignment.yaw"), inline = 1, label = 1, mspapi=1, apikey="yaw"},
        }
    }
}



local function onToolMenu(self)
    local buttons = {{
        label = i18n("app.btn_ok"),
        action = function()
            -- we push this to the background task to do its job
            calibrate = true
            writePayload = nil
            return true
        end
    }, {
        label = i18n("app.btn_cancel"),
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = nil,
        title =  i18n("app.modules.gyro_alignment.name"),
        message = i18n("app.modules.gyro_alignment.msg_calibrate"),
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })
end

local function applySettings()
    local EAPI = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
    EAPI.setUUID("550e8400-e29b-41d4-a716-446655440000")
    EAPI.setCompleteHandler(function(self)
        rfsuite.utils.log("Writing to EEPROM","info")
        calibrateComplete = true
    end)
    EAPI.write()
end

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function wakeup()
    if calibrate == true then
        local message = {
            command = 205, -- MSP_ACC_CALIBRATION
            processReply = function(self, buf)
                rfsuite.utils.log("Accelerometer calibrated.", "info")
                calibrate = false
                applySettings()
            end,
            simulatorResponse = {}
        }
        rfsuite.tasks.msp.mspQueue:add(message)
    end    

    if calibrateComplete == true then
        calibrateComplete = false
        rfsuite.utils.playFileCommon("beep.wav")
    end    

    -- Module is active and ready
end

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    API = {},
    navButtons = {
        menu = true,
        save = true,
        reload = true,
        tool = true,
        help = true
    },
    onToolMenu = onToolMenu,
    postLoad = postLoad,
    wakeup = wakeup
}
