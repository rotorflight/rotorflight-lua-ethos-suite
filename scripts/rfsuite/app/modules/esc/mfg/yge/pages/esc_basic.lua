local labels = {}
local fields = {}

local folder = "yge"



labels[#labels + 1] = {t = "ESC", label = "esc1", inline_size = 40.6}
fields[#fields + 1] = {t = "ESC Mode", inline = 1, label = "esc1", type = 1, apikey="governor"}

labels[#labels + 1] = {t = "", label = "esc2", inline_size = 40.6}
fields[#fields + 1] = {t = "Direction", inline = 1, label = "esc2", type = 1, apikey="direction"}

labels[#labels + 1] = {t = "", label = "esc3", inline_size = 40.6}
fields[#fields + 1] = {t = "BEC", inline = 1, label = "esc3", apikey="lv_bec_voltage"}

labels[#labels + 1] = {t = "Limits", label = "limits1", inline_size = 40.6}
fields[#fields + 1] = {t = "Cutoff Handling", inline = 1, label = "limits1", type = 1, apikey="auto_restart_time"}

labels[#labels + 1] = {t = "", label = "limits2", inline_size = 40.6}
fields[#fields + 1] = {t = "Cutoff Cell Voltage", inline = 1, label = "limits2", type = 1, apikey="cell_cutoff"}

-- need to work current limit out - disable for now
labels[#labels + 1] = {t = "", label = "limits3", inline_size = 40.6}
fields[#fields + 1] = {t = "Current Limit", units = "A", inline = 1, label = "limits3", apikey="current_limit"}

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

local foundEsc = false
local foundEscDone = false

return {
    mspapi = "ESC_PARAMETERS_YGE",
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / YGE / Basic",
    headerLine = rfsuite.escHeaderLineText
}

