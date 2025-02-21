local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Low voltage protection", mspapi = 1, apikey = "low_voltage_protection"},
            {t = "Temperature protection",  mspapi = 1, apikey = "temperature_protection"},
            {t = "Timing angle",            mspapi = 1, apikey = "timing_angle"},
            {t = "Starting torque",         mspapi = 1, apikey = "starting_torque"},
            {t = "Response speed",          mspapi = 1, apikey = "response_speed"},
            {t = "Buzzer volume",           mspapi = 1, apikey = "buzzer_volume"},
            {t = "Current gain",            mspapi = 1, apikey = "current_gain"}
        }
    }                 
}



local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
        return true
    end

    return false
end

return {
    mspapi=mspapi,    
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    escinfo = escinfo,
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
