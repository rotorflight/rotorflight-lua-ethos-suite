local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

local foundEsc = false
local foundEscDone = false

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR",
    },
    formdata = {
        labels = {
        },
        fields = {
            { t = "Governor",        mspapi = 1, apikey = "governor",        type = 1 },
            { t = "Gov-P",           mspapi = 1, apikey = "gov_p"                     },
            { t = "Gov-I",           mspapi = 1, apikey = "gov_i"                     },
            { t = "Gov-D",           mspapi = 1, apikey = "gov_d"                     },
            { t = "Motor ERPM max",  mspapi = 1, apikey = "motor_erpm_max"            }
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

return {
    mspapi=mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Governor",
    escinfo = escinfo,
    postLoad = postLoad,
    simulatorResponse =  simulatorResponse,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Governor",
    headerLine = rfsuite.escHeaderLineText

}
