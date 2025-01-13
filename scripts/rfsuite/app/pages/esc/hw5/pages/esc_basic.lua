local labels = {}
local fields = {}

local folder = "hw5"
local ESC = assert(loadfile("app/pages/esc/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local flightMode = {"Fixed Wing", "Heli Ext Governor", "Heli Governor", "Heli Governor Store"}

local rotation = {"CW", "CCW"}

local lipoCellCount = {"Auto Calculate", "3S", "4S", "5S", "6S", "7S", "8S", "9S", "10S", "11S", "12S", "13S", "14S"}

local cutoffType = {"Soft Cutoff", "Hard Cutoff"}

local cutoffVoltage = {"Disabled", "2.8", "2.9", "3.0", "3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8"}

local voltages = {"5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4"}

labels[#labels + 1] = {t = "ESC", label = "esc1", inline_size = 40.6}
fields[#fields + 1] = {t = "Flight Mode", inline = 1, label = "esc1", min = 0, max = #flightMode, tableIdxInc = -1, vals = {mspHeaderBytes + 64}, table = flightMode}

labels[#labels + 1] = {t = "", label = "esc2", inline_size = 40.6}
fields[#fields + 1] = {t = "Rotation", inline = 1, label = "esc2", min = 0, max = #rotation, vals = {mspHeaderBytes + 77}, tableIdxInc = -1, table = rotation}

labels[#labels + 1] = {t = "", label = "esc3", inline_size = 40.6}
fields[#fields + 1] = {t = "BEC Voltage", inline = 1, label = "esc3", min = 0, max = #voltages, vals = {mspHeaderBytes + 68}, tableIdxInc = -1, table = voltages}

labels[#labels + 1] = {t = "Protection and Limits", label = "limits1", inline_size = 40.6}
fields[#fields + 1] = {t = "LiPo Cell Count", inline = 1, label = "limits1", min = 0, max = #lipoCellCount, vals = {mspHeaderBytes + 65}, tableIdxInc = -1, table = lipoCellCount}

labels[#labels + 1] = {t = "", label = "limits2", inline_size = 40.6}
fields[#fields + 1] = {t = "Volt Cutoff Type", inline = 1, label = "limits2", min = 0, max = #cutoffType, vals = {mspHeaderBytes + 66}, tableIdxInc = -1, table = cutoffType}

labels[#labels + 1] = {t = "", label = "limits3", inline_size = 40.6}
fields[#fields + 1] = {t = "Cuttoff Voltage", inline = 1, label = "limits3", min = 0, max = #cutoffVoltage, vals = {mspHeaderBytes + 67}, tableIdxInc = -1, table = cutoffVoltage}

function postLoad()
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_tool.lua")
end

local function event(widget, category, value, x, y)

    -- print("Event received:" .. ", " .. category .. "," .. value .. "," .. x .. "," .. y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder, "esc_tool.lua")
        return true
    end

    return false
end

return {
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = true,
    reboot = false,
    title = "Basic Setup",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse = {253, 0, 32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32, 72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66, 80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32, 32, 32, 32, 32, 80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32, 0, 0, 0, 3, 0, 11, 6, 5, 25, 1, 0, 0, 24, 0, 0, 2},
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Hobbywing V5 / Basic",
    headerLine = rfsuite.escHeaderLineText
}
