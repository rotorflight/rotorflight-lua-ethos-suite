local folder = "flrtr"
local ESC = assert(rfsuite.compiler.loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

local foundEsc = false
local foundEscDone = false

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR",
    },
    formdata = {
        labels = {
        },
        fields = {
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.gov"),             mspapi = 1, apikey = "governor",        type = 1 },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.gov_p"),           mspapi = 1, apikey = "gov_p"                     },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.gov_i"),           mspapi = 1, apikey = "gov_i"                     },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.gov_d"),           mspapi = 1, apikey = "gov_d"                     },
            { t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.motor_erpm_max"),  mspapi = 1, apikey = "motor_erpm_max"            }
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

    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
        return true
    end


end

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    postLoad = postLoad,
    simulatorResponse =  simulatorResponse,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = rfsuite.i18n.get("app.modules.esc_tools.name") .. " / " ..  rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.governor"),
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5,

}
