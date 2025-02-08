local labels = {}
local fields = {}


local folder = "hw5"

--local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
--local mspHeaderBytes = ESC.mspHeaderBytes
--local mspSignature = ESC.mspSignature

local flightMode = {"Fixed Wing", "Heli Ext Governor", "Heli Governor", "Heli Governor Store"}

local rotation = {"CW", "CCW"}

local lipoCellCount = {"Auto Calculate", "3S", "4S", "5S", "6S", "7S", "8S", "9S", "10S", "11S", "12S", "13S", "14S"}

local cutoffType = {"Soft Cutoff", "Hard Cutoff"}

local cutoffVoltage = {"Disabled", "2.8", "2.9", "3.0", "3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8"}

local voltages = {"5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4"}

labels[#labels + 1] = {t = "ESC", label = "esc1", inline_size = 40.6}
fields[#fields + 1] = {t = "Flight Mode", inline = 1, label = "esc1", min = 0, max = #flightMode, tableIdxInc = -1, xvals = {66}, table = flightMode, apikey="flight_mode"}

labels[#labels + 1] = {t = "", label = "esc2", inline_size = 40.6}
fields[#fields + 1] = {t = "Rotation", inline = 1, label = "esc2", min = 0, max = #rotation, xvals = {79}, tableIdxInc = -1, table = rotation, apikey="rotation"}

labels[#labels + 1] = {t = "", label = "esc3", inline_size = 40.6}
fields[#fields + 1] = {t = "BEC Voltage", inline = 1, label = "esc3", min = 0, max = #voltages, xvals = {70}, tableIdxInc = -1, table = voltages, apikey="bec_voltage"}

labels[#labels + 1] = {t = "Protection and Limits", label = "limits1", inline_size = 40.6}
fields[#fields + 1] = {t = "LiPo Cell Count", inline = 1, label = "limits1", min = 0, max = #lipoCellCount, xvals = {67}, tableIdxInc = -1, table = lipoCellCount, apikey="lipo_cell_count"}

labels[#labels + 1] = {t = "", label = "limits2", inline_size = 40.6}
fields[#fields + 1] = {t = "Volt Cutoff Type", inline = 1, label = "limits2", min = 0, max = #cutoffType, xvals = {68}, tableIdxInc = -1, table = cutoffType, apikey="volt_cutoff_type"}

labels[#labels + 1] = {t = "", label = "limits3", inline_size = 40.6}
fields[#fields + 1] = {t = "Cuttoff Voltage", inline = 1, label = "limits3", min = 0, max = #cutoffVoltage, xvals = {69}, tableIdxInc = -1, table = cutoffVoltage, apikey="cutoff_voltage"}

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
