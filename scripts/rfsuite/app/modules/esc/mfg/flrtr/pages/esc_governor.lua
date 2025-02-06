local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local foundEsc = false
local foundEscDone = false

local govMode = {"External Governor", "ESC Governor"}

fields[#fields + 1] = {t = "Governor", vals = {mspHeaderBytes + 23}, tableIdxInc = -1, table = govMode}
fields[#fields + 1] = {t = "Gov-P", vals = {mspHeaderBytes + 37, mspHeaderBytes + 36}, min = 1, max = 100, default = 45}
fields[#fields + 1] = {t = "Gov-I", vals = {mspHeaderBytes + 39, mspHeaderBytes + 38}, min = 1, max = 100, default = 35}
fields[#fields + 1] = {t = "Gov-D", vals = {mspHeaderBytes + 41, mspHeaderBytes + 40}, min = 0, max = 100, default = 0}
fields[#fields + 1] = {t = "Motor ERPM max", vals = {mspHeaderBytes + 44, mspHeaderBytes + 43, mspHeaderBytes + 42}, min = 0, max = 1000000, step = 100}

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
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = true,
    reboot = false,
    title = "Governor",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse = {115, 0, 0, 0, 150, 255, 156, 190, 216, 70, 69, 169, 239, 1, 0, 0, 1, 0, 8, 1, 4, 76, 7, 148, 1, 6, 30, 125, 0, 5, 0, 1, 5, 1, 20, 0, 15, 0, 30, 0, 18, 0, 10, 1, 193, 56},
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Governor",
    headerLine = rfsuite.escHeaderLineText

}
