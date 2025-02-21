

local folder = "scorp"

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_SCORPION",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Soft Start Time", mspapi=1, apikey="soft_start_time"},
            {t = "Runup Time", mspapi=1, apikey="runup_time"},
            {t = "Bailout", mspapi=1, apikey="bailout"},
            {t = "Gov Proportional", mspapi=1, apikey="gov_proportional"},
            {t = "Gov Integral", mspapi=1, apikey="gov_integral"},
            {t = "Motor Startup Sound", type = 1, mspapi=1, apikey="motor_startup_sound"},
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
    eepromWrite = false,
    reboot = false,
    title = "Advanced Setup",
    escinfo = escinfo,
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Scorpion / Advanced",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "Please reboot the ESC to apply the changes",   
}
