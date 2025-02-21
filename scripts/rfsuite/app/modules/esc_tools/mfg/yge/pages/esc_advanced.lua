
local folder = "yge"

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_YGE",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Min Start Power", mspapi = 1, apikey="min_start_power"},
            {t = "Max Start Power", mspapi = 1, apikey="max_start_power"},
            {t = "Throttle Response", type = 1, mspapi = 1, apikey="throttle_response"},
            {t = "Motor Timing", type = 1, mspapi = 1, apikey="timing"},
            {t = "Active Freewheel", type = 1, mspapi = 1, apikey="active_freewheel"},
            {t = "F3C Autorotation", type = 1, mspapi = 1, apikey="f3c_auto"},
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
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    escinfo = escinfo,
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / YGE / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
