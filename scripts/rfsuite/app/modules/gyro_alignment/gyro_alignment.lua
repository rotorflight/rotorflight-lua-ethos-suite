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
            { t = i18n("app.modules.gyro_alignment.swashplate_config"), label = 2, inline_size = 13.6 },
        },
        fields = {
            -- Board alignment fields
            {t = i18n("app.modules.gyro_alignment.roll"), inline = 3, label = 1, mspapi=1, apikey="roll"},
            {t = i18n("app.modules.gyro_alignment.pitch"), inline = 2, label = 1, mspapi=1, apikey="pitch"},
            {t = i18n("app.modules.gyro_alignment.yaw"), inline = 1, label = 1, mspapi=1, apikey="yaw"},
            
            -- Swashplate configuration (read-only display from MIXER_CONFIG)
            {t = i18n("app.modules.gyro_alignment.swash_type"), label = 2, readonly = true, value = function() return rfsuite.session.swashMode and swashMixerType() or "Unknown" end},
        }
    }                 
}

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

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        -- Update swashplate type display
        if rfsuite.session.swashMode ~= nil then
            local swashField = rfsuite.app.formFields['swash_type']
            if swashField then
                swashField:value(swashMixerType())
            end
        end
    end
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
