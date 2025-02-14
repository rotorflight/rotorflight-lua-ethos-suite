local labels = {}
local fields = {}


local folder = "hw5"

labels[#labels + 1] = {t = "ESC", label = "esc1", inline_size = 40.6}
fields[#fields + 1] = {t = "Flight Mode", inline = 1, label = "esc1", type = 1, apikey="flight_mode"}

labels[#labels + 1] = {t = "", label = "esc2", inline_size = 40.6}
fields[#fields + 1] = {t = "Rotation", inline = 1, label = "esc2", type = 1, apikey="rotation"}

labels[#labels + 1] = {t = "", label = "esc3", inline_size = 40.6}
fields[#fields + 1] = {t = "BEC Voltage", inline = 1, label = "esc3", type = 1, apikey="bec_voltage"}

labels[#labels + 1] = {t = "Protection and Limits", label = "limits1", inline_size = 40.6}
fields[#fields + 1] = {t = "LiPo Cell Count", inline = 1, label = "limits1", type = 1, apikey="lipo_cell_count"}

labels[#labels + 1] = {t = "", label = "limits2", inline_size = 40.6}
fields[#fields + 1] = {t = "Volt Cutoff Type", inline = 1, label = "limits2", type = 1, apikey="volt_cutoff_type"}

labels[#labels + 1] = {t = "", label = "limits3", inline_size = 40.6}
fields[#fields + 1] = {t = "Cuttoff Voltage", inline = 1, label = "limits3", type = 1, apikey="cutoff_voltage"}

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
    title = "Basic Setup",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Hobbywing V5 / Basic",
    headerLine = rfsuite.escHeaderLineText
}
