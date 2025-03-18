
local folder = "hw5"

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_HW5",
    },
    formdata = {
        labels = {
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.esc"),                   label = "esc1",    inline_size = 40.6},
            {t = "",                                                                      label = "esc2",    inline_size = 40.6},
            {t = "",                                                                      label = "esc3",    inline_size = 40.6},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.limits"),                label = "limits1", inline_size = 40.6},
            {t = "",                      label = "limits2", inline_size = 40.6},
            {t = "",                      label = "limits3", inline_size = 40.6}
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.flight_mode"),       inline = 1, label = "esc1",    type = 1, mspapi = 1, apikey = "flight_mode"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.rotation"),          inline = 1, label = "esc2",    type = 1, mspapi = 1, apikey = "rotation"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.bec_voltage"),       inline = 1, label = "esc3",    type = 1, mspapi = 1, apikey = "bec_voltage"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.lipo_cell_count"),   inline = 1, label = "limits1", type = 1, mspapi = 1, apikey = "lipo_cell_count"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.volt_cutoff_type"),  inline = 1, label = "limits2", type = 1, mspapi = 1, apikey = "volt_cutoff_type"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.cutoff_voltage"),    inline = 1, label = "limits3", type = 1, mspapi = 1, apikey = "cutoff_voltage"}
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
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = rfsuite.i18n.get("app.modules.esc_tools.name") .. " / " ..  rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.hw5.basic"),
    headerLine = rfsuite.escHeaderLineText
}
