

local folder = "yge"


local foundEsc = false
local foundEscDone = false

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_YGE",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "P-Gain", mspapi = 1, apikey="gov_p"},
            {t = "I-Gain", mspapi = 1, apikey="gov_i"},
            {t = "Motor Pole Pairs", mspapi = 1, apikey="motor_pole_pairs"},
            {t = "Main Teeth", mspapi = 1, apikey="main_teeth"},
            {t = "Pinion Teeth" , mspapi = 1, apikey="pinion_teeth"} ,
            {t = "Stick Zero (us)", mspapi = 1, apikey="stick_zero_us"},
            {t = "Stick Range (us)", mspapi = 1, apikey="stick_range_us"},
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
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Other Settings",
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / YGE / Other",
    headerLine = rfsuite.escHeaderLineText

}
