local labels = {}
local fields = {}

local folder = "yge"



labels[#labels + 1] = {t = "ESC"}

fields[#fields + 1] = {t = "Min Start Power", apikey="min_start_power"}
fields[#fields + 1] = {t = "Max Start Power", apikey="max_start_power"}
fields[#fields + 1] = {t = "Throttle Response", type = 1, apikey="throttle_response"}
fields[#fields + 1] = {t = "Motor Timing", type = 1, apikey="timing"}
fields[#fields + 1] = {t = "Active Freewheel", type = 1, apikey="active_freewheel"}
fields[#fields + 1] = {t = "F3C Autorotation", type = 1, apikey="f3c_auto"}
-- not sure this field exists?
-- fields[#fields + 1] = {t = "Startup Response", min = 0, max = #startupResponse, vals = {11, 12}, table = startupResponse}

local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder, "esc/esc_tool.lua")
        return true
    end

    return false
end

return {
    mspapi = "ESC_PARAMETERS_YGE",
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    labels = labels,
    fields = fields,
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
