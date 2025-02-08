local folder = "hw5"

local labels = {}
local fields = {}


local startupPower = {[0] = "1", "2", "3", "4", "5", "6", "7"}

local enabledDisabled = {[0] = "Enabled", "Disabled"}

local brakeType = {[0] = "Disabled", "Normal", "Proportional", "Reverse"}
labels[#labels + 1] = {t = "Motor", label = "motor1", inline_size = 40.6}
fields[#fields + 1] = {t = "Timing", inline = 1, label = "motor1", min = 0, max = 30, xvals = {78}, apikey="timing"}

labels[#labels + 1] = {t = "", label = "motor2", inline_size = 40.6}
fields[#fields + 1] = {t = "Startup Power", inline = 1, label = "motor2", min = 0, max = #startupPower, xvals = {81}, table = startupPower, apikey="startup_power"}

labels[#labels + 1] = {t = "", label = "motor3", inline_size = 40.6}
fields[#fields + 1] = {t = "Active Freewheel", inline = 1, label = "motor3", min = 0, max = #enabledDisabled, vals = {80}, table = enabledDisabled, apikey="active_freewheel"}

labels[#labels + 1] = {t = "Brake", label = "brake1", inline_size = 40.6}
fields[#fields + 1] = {t = "Brake Type", inline = 1, label = "brake1", min = 0, max = #brakeType, xvals = {76}, table = brakeType, apikey="brake_type"}

labels[#labels + 1] = {t = "", label = "brake2", inline_size = 40.6}
fields[#fields + 1] = {t = "Brake Force %", inline = 1, label = "brake2", min = 0, max = 100, xvals = {77}, apikey="brake_force"}

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
