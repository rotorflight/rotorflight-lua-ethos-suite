local labels = {}
local fields = {}

local folder = "yge"

local escMode = {"Free (Attention!)", "Heli Ext Governor", "Heli Governor", "Heli Governor Store", "Aero Glider", "Aero Motor", "Aero F3A"}

local direction = {"Normal", "Reverse"}

local cuttoff = {"Off", "Slow Down", "Cutoff"}

local cuttoffVoltage = {"2.9 V", "3.0 V", "3.1 V", "3.2 V", "3.3 V", "3.4 V"}

labels[#labels + 1] = {t = "ESC", label = "esc1", inline_size = 40.6}
fields[#fields + 1] = {t = "ESC Mode", inline = 1, label = "esc1", min = 1, max = #escMode, tableIdxInc = -1, table = escMode, apikey="governor"}

labels[#labels + 1] = {t = "", label = "esc2", inline_size = 40.6}
fields[#fields + 1] = {t = "Direction", inline = 1, label = "esc2", min = 0, max = 1, tableIdxInc = -1, table = direction, apikey="direction"}

labels[#labels + 1] = {t = "", label = "esc3", inline_size = 40.6}
fields[#fields + 1] = {t = "BEC", inline = 1, label = "esc3", unit = "v", min = 55, max = 84, scale = 10, decimals = 1, apikey="lv_bec_voltage"}

labels[#labels + 1] = {t = "Limits", label = "limits1", inline_size = 40.6}
fields[#fields + 1] = {t = "Cutoff Handling", inline = 1, label = "limits1", min = 0, max = #cuttoff, tableIdxInc = -1, table = cuttoff, apikey="auto_restart_time"}

labels[#labels + 1] = {t = "", label = "limits2", inline_size = 40.6}
fields[#fields + 1] = {t = "Cutoff Cell Voltage", inline = 1, label = "limits2", min = 0, max = #cuttoffVoltage, tableIdxInc = -1, table = cuttoffVoltage, apikey="cell_cutoff"}

-- need to work current limit out - disable for now
labels[#labels + 1] = {t = "", label = "limits3", inline_size = 40.6}
fields[#fields + 1] = {t = "Current Limit", units = "A", inline = 1, label = "limits3", unit="A", min = 1, max = 65500, decimals = 2, scale="100", vals = {57, 58}}

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

