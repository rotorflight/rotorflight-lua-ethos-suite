
local folder = "hw5"

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_HW5",
    },
    formdata = {
        labels = {
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.governor)@",    label = "gov",    inline_size = 13.4},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.soft_start)@",  label = "start",  inline_size = 40.6},
            {t = "",            label = "start2", inline_size = 40.6},
            {t = "",            label = "start3", inline_size = 40.6}
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.gov_p_gain)@",       inline = 2, label = "gov",    mspapi = 1, apikey = "gov_p_gain"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.gov_i_gain)@",       inline = 1, label = "gov",    mspapi = 1, apikey = "gov_i_gain"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.startup_time)@",     inline = 1, label = "start",  mspapi = 1, apikey = "startup_time"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.restart_time)@",     inline = 1, label = "start2", mspapi = 1, apikey = "restart_time", type   = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.auto_restart)@",     inline = 1, label = "start3", mspapi = 1, apikey = "auto_restart"}
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
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " ..  "@i18n(app.modules.esc_tools.mfg.hw5.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.hw5.advanced)@",
    headerLine = rfsuite.escHeaderLineText
}
