 
local version = rfsuite.version().version
local ethosVersion = rfsuite.config.environment.major .. "." .. rfsuite.config.environment.minor .. "." .. rfsuite.config.environment.revision
local apiVersion = rfsuite.session.apiVersion
local fcVersion = rfsuite.session.fcVersion 
local rfVersion = rfsuite.session.rfVersion
local closeProgressLoader = true

local i18n = rfsuite.i18n.get

local supportedMspVersion = ""
for i, v in ipairs(rfsuite.config.supportedMspApiVersion) do
    if i == 1 then
        supportedMspVersion = v
    else
        supportedMspVersion = supportedMspVersion .. "," .. v
    end
end

if system.getVersion().simulation == true then
    simulation = "ON"
else
    simulation = "OFF"
end

local displayType = 0
local disableType = false
local displayPos
local w, h = lcd.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 300, h = rfsuite.app.radio.navbuttonHeight}


local apidata = {
    api = {
        [1] = nil,
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = i18n("app.modules.about.version"), value = version, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.about.ethos_version"), value = ethosVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.about.rf_version"), value = rfVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.about.fc_version"), value = fcVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.about.msp_version"), value = apiVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.about.msp_transport"), value = string.upper(rfsuite.tasks.msp.protocol.mspProtocol), type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.about.supported_versions"), value = supportedMspVersion, type = displayType, disable = disableType, position = displayPos},
            {t = i18n("app.modules.about.simulation"), value = simulation, type = displayType, disable = disableType, position = displayPos}
        }
    }
}


function onToolMenu()

    local opener = i18n("app.modules.about.opener")
    local credits = i18n("app.modules.about.credits")
    local license = i18n("app.modules.about.license")

    local message = opener .. "\r\n\r\n" .. credits .. "\r\n\r\n" .. license .. "\r\n\r\n"

    local buttons = {{
        label = i18n("app.btn_close"),
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = rfsuite.app.lcdWidth,
        title = i18n("app.modules.about.msgbox_credits"),
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
    if closeProgressLoader == false then
        rfsuite.app.triggers.closeProgressLoader = true
        closeProgressLoader = true
    end    
end

return {
    apidata = apidata,
    reboot = false,
    eepromWrite = false,
    minBytes = 0,
    wakeup = wakeup,
    refreshswitch = false,
    simulatorResponse = {},
    onToolMenu = onToolMenu,
    navButtons = {
        menu = true,
        save = false,
        reload = false,
        tool = true,
        help = true
    },
    API = {},
}
