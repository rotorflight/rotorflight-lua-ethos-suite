
local folder = "hw5"

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_HW5",
    },
    formdata = {
        labels = {
            {t = "Governor",    label = "gov",    inline_size = 13.4},
            {t = "Soft Start",  label = "start",  inline_size = 40.6},
            {t = "",            label = "start2", inline_size = 40.6},
            {t = "",            label = "start3", inline_size = 40.6}
        },
        fields = {
            {t = "P-Gain",       inline = 2, label = "gov",    mspapi = 1, apikey = "gov_p_gain"},
            {t = "I-Gain",       inline = 1, label = "gov",    mspapi = 1, apikey = "gov_i_gain"},
            {t = "Startup Time", inline = 1, label = "start",  mspapi = 1, apikey = "startup_time"},
            {t = "Restart Time", inline = 1, label = "start2", mspapi = 1, apikey = "restart_time", type   = 1},
            {t = "Auto Restart", inline = 1, label = "start3", mspapi = 1, apikey = "auto_restart"}
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
    mspapi=mspapi, 
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Hobbywing V5 / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
