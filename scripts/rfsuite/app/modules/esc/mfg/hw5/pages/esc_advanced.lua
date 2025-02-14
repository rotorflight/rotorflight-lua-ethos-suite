local labels = {}
local fields = {}

local folder = "hw5"

labels[#labels + 1] = {t = "Governor", label = "gov", inline_size = 13.4}
fields[#fields + 1] = {t = "P-Gain", inline = 2, label = "gov", min = 0, max = 9, xvals = {72}, apikey="gov_p_gain"}
fields[#fields + 1] = {t = "I-Gain", inline = 1, label = "gov", min = 0, max = 9, xvals = {73}, apikey="gov_i_gain"}

labels[#labels + 1] = {t = "Soft Start", label = "start", inline_size = 40.6}
fields[#fields + 1] = {t = "Startup Time", inline = 1, label = "start", units = "s", min = 4, max = 25, xvals = {71}, apikey="startup_time"}

labels[#labels + 1] = {t = "", label = "start2", inline_size = 40.6}
fields[#fields + 1] = {t = "Restart Time", inline = 1, label = "start2", type = 1, apikey="restart_time"}

labels[#labels + 1] = {t = "", label = "start3", inline_size = 40.6}
fields[#fields + 1] = {t = "Auto Restart", inline = 1, label = "start3", apikey="auto_restart"}

function postLoad()
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    -- print("Event received:" .. ", " .. category .. "," .. value .. "," .. x .. "," .. y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder, "esc/esc_tool.lua")
        return true
    end

    return false
end
return {
    mspapi="ESC_PARAMETERS_HW5", 
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Hobbywing V5 / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
