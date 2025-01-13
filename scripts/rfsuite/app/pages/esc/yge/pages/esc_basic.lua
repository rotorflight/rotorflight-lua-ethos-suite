local labels = {}
local fields = {}

local folder = "yge"
local ESC = assert(loadfile("app/pages/esc/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local escMode = {"Free (Attention!)", "Heli Ext Governor", "Heli Governor", "Heli Governor Store", "Aero Glider", "Aero Motor", "Aero F3A"}

local direction = {"Normal", "Reverse"}

local cuttoff = {"Off", "Slow Down", "Cutoff"}

local cuttoffVoltage = {"2.9 V", "3.0 V", "3.1 V", "3.2 V", "3.3 V", "3.4 V"}

labels[#labels + 1] = {t = "ESC", label = "esc1", inline_size = 40.6}
fields[#fields + 1] = {t = "ESC Mode", inline = 1, label = "esc1", min = 1, max = #escMode, vals = {mspHeaderBytes + 3, mspHeaderBytes + 4}, tableIdxInc = -1, table = escMode}

labels[#labels + 1] = {t = "", label = "esc2", inline_size = 40.6}
fields[#fields + 1] = {t = "Direction", inline = 1, label = "esc2", min = 0, max = 1, vals = {mspHeaderBytes + 53}, tableIdxInc = -1, table = direction}

labels[#labels + 1] = {t = "", label = "esc3", inline_size = 40.6}
fields[#fields + 1] = {t = "BEC", inline = 1, label = "esc3", unit = "v", min = 55, max = 84, vals = {mspHeaderBytes + 5, mspHeaderBytes + 6}, scale = 10, decimals = 1}

labels[#labels + 1] = {t = "Limits", label = "limits1", inline_size = 40.6}
fields[#fields + 1] = {t = "Cutoff Handling", inline = 1, label = "limits1", min = 0, max = #cuttoff, vals = {mspHeaderBytes + 17, mspHeaderBytes + 18}, tableIdxInc = -1, table = cuttoff}

labels[#labels + 1] = {t = "", label = "limits2", inline_size = 40.6}
fields[#fields + 1] = {t = "Cutoff Cell Voltage", inline = 1, label = "limits2", min = 0, max = #cuttoffVoltage, vals = {mspHeaderBytes + 19, mspHeaderBytes + 20}, tableIdxInc = -1, table = cuttoffVoltage}

-- need to work current limit out - disable for now
-- labels[#labels + 1] = {t = "", label = "limits3", inline_size = 40.6}
-- fields[#fields + 1] = {t = "Current Limit", units = "A", inline = 1, label = "limits3", min = 1, max = 65500, decimals = 2, vals = {mspHeaderBytes+55, mspHeaderBytes+56}}

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

local foundEsc = false
local foundEscDone = false
return {
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse = {165, 0, 32, 0, 3, 0, 55, 0, 0, 0, 0, 0, 4, 0, 3, 0, 1, 0, 1, 0, 2, 0, 3, 0, 80, 3, 131, 148, 1, 0, 30, 170, 0, 0, 3, 0, 86, 4, 22, 3, 163, 15, 1, 0, 2, 0, 2, 0, 20, 0, 20, 0, 0, 0, 0, 0, 2, 19, 2, 0, 20, 0, 22, 0, 0, 0},
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / YGE / Basic",
    headerLine = rfsuite.escHeaderLineText
}

