
local folder = "hw5"

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_HW5",
    },
    formdata = {
        labels = {
            {t = "ESC",                   label = "esc1",    inline_size = 40.6},
            {t = "",                      label = "esc2",    inline_size = 40.6},
            {t = "",                      label = "esc3",    inline_size = 40.6},
            {t = "Protection and Limits", label = "limits1", inline_size = 40.6},
            {t = "",                      label = "limits2", inline_size = 40.6},
            {t = "",                      label = "limits3", inline_size = 40.6}
        },
        fields = {
            {t = "Flight Mode",       inline = 1, label = "esc1",    type = 1, mspapi = 1, apikey = "flight_mode"},
            {t = "Rotation",          inline = 1, label = "esc2",    type = 1, mspapi = 1, apikey = "rotation"},
            {t = "BEC Voltage",       inline = 1, label = "esc3",    type = 1, mspapi = 1, apikey = "bec_voltage"},
            {t = "LiPo Cell Count",   inline = 1, label = "limits1", type = 1, mspapi = 1, apikey = "lipo_cell_count"},
            {t = "Volt Cutoff Type",  inline = 1, label = "limits2", type = 1, mspapi = 1, apikey = "volt_cutoff_type"},
            {t = "Cuttoff Voltage",   inline = 1, label = "limits3", type = 1, mspapi = 1, apikey = "cutoff_voltage"}
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
    title = "Basic Setup",
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Hobbywing V5 / Basic",
    headerLine = rfsuite.escHeaderLineText
}
