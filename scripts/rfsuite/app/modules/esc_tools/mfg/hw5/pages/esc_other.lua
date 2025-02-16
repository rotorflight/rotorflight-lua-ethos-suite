local folder = "hw5"

local labels = {}
local fields = {}


labels[#labels + 1] = {t = "Motor", label = "motor1", inline_size = 40.6}
fields[#fields + 1] = {t = "Timing", inline = 1, label = "motor1", min = 0, max = 30, xvals = {78}, apikey="timing"}

labels[#labels + 1] = {t = "", label = "motor2", inline_size = 40.6}
fields[#fields + 1] = {t = "Startup Power", inline = 1, label = "motor2", type = 1, apikey="startup_power"}

labels[#labels + 1] = {t = "", label = "motor3", inline_size = 40.6}
fields[#fields + 1] = {t = "Active Freewheel", inline = 1, label = "motor3", type = 1, apikey="active_freewheel"}

labels[#labels + 1] = {t = "Brake", label = "brake1", inline_size = 40.6}
fields[#fields + 1] = {t = "Brake Type", inline = 1, label = "brake1", type = 1, apikey="brake_type"}

labels[#labels + 1] = {t = "", label = "brake2", inline_size = 40.6}
fields[#fields + 1] = {t = "Brake Force %", inline = 1, label = "brake2", apikey="brake_force"}

function postLoad()
    rfsuite.app.triggers.isReady = true
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
    mspapi="ESC_PARAMETERS_HW5",
    eepromWrite = true,
    reboot = false,
    title = "Other Settings",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Hobbywing V5 / Other",
    headerLine = rfsuite.escHeaderLineText
}
