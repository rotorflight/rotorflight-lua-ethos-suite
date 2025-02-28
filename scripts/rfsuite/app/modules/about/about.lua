
local version = rfsuite.config.Version
local ethosVersion = rfsuite.config.environment.major .. "." .. rfsuite.config.environment.minor .. "." .. rfsuite.config.environment.revision
local apiVersion = rfsuite.session.apiVersion
local closeProgressLoader = true

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
local w, h = rfsuite.utils.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 300, h = rfsuite.app.radio.navbuttonHeight}


local mspapi = {
    api = {
        [1] = nil,
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Version", value = version, type = displayType, disable = disableType, position = displayPos},
            {t = "Ethos Version", value = ethosVersion, type = displayType, disable = disableType, position = displayPos},
            {t = "MSP Version", value = apiVersion, type = displayType, disable = disableType, position = displayPos},
            {t = "MSP Transport", value = string.upper(rfsuite.tasks.msp.protocol.mspProtocol), type = displayType, disable = disableType, position = displayPos},
            {t = "Supported MSP Versions", value = supportedMspVersion, type = displayType, disable = disableType, position = displayPos},
            {t = "Simulation", value = simulation, type = displayType, disable = disableType, position = displayPos}
        }
    }
}


function onToolMenu()

    local opener = "Rotorflight is an open source project. Contribution from other like minded people, keen to assist in making this software even better, is welcomed and encouraged. You do not have to be a hardcore programmer to help."
    local credits = "Notable contributors to both the Rotorflight firmware and this software are: Petri Mattila, Egon Lubbers, Rob Thomson, Rob Gayle, Phil Kaighin, Robert Burrow, Keith Williams, Bertrand Songis, Venbs Zhou... and many more who have spent hours testing and providing feedback!"
    local license = "You may copy, distribute, and modify the software as long as you track changes/dates in source files. Any modifications to or software including (via compiler) GPL-licensed code must also be made available under the GPL along with build & install instructions."

    local message = opener .. "\r\n\r\n" .. credits .. "\r\n\r\n" .. license .. "\r\n\r\n"

    local buttons = {{
        label = "CLOSE",
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = rfsuite.session.lcdWidth,
        title = "Credits",
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
    mspapi = mspapi,
    title = "Status",
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
