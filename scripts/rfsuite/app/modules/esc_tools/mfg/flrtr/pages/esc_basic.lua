
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
            {t = "Cell count",       mspapi = 1, apikey = "cell_count"},
            {t = "BEC voltage",      mspapi = 1, apikey = "bec_voltage",    type = 1},
            {t = "Motor direction",  mspapi = 1, apikey = "motor_direction", type = 1},
            {t = "Soft start",       mspapi = 1, apikey = "soft_start"},
            {t = "Fan control",      mspapi = 1, apikey = "fan_control"}
        }
    }                 
}


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

local foundEsc = false
local foundEscDone = false

return {
    mspapi=mspapi,
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    escinfo = escinfo,
    svFlags = 0,
    simulatorResponse =  simulatorResponse,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Basic",
    headerLine = rfsuite.escHeaderLineText
}

