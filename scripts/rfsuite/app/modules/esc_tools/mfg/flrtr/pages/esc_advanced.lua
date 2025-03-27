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
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.low_voltage_protection"),    mspapi = 1, apikey = "low_voltage_protection"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.temperature_protection"),    mspapi = 1, apikey = "temperature_protection"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.timing_angle"),              mspapi = 1, apikey = "timing_angle"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.starting_torque"),           mspapi = 1, apikey = "starting_torque"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.response_speed"),            mspapi = 1, apikey = "response_speed"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.buzzer_volume"),             mspapi = 1, apikey = "buzzer_volume"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.current_gain"),              mspapi = 1, apikey = "current_gain"}
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

    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
        return true
    end


end

return {
    mspapi=mspapi,    
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = rfsuite.i18n.get("app.modules.esc_tools.name") .. " / " ..  rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.advanced"),
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5,
}
