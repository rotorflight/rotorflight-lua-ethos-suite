local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(compile.loadScript("app/pages/esc/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local foundEsc = false
local foundEscDone = false

local govMode = {"External Governor", "ESC Governor"}

fields[#fields + 1] = {t = "Governor", vals = {mspHeaderBytes + 23}, tableIdxInc = -1, table = govMode}
fields[#fields + 1] = {t = "Gov-P", vals = {mspHeaderBytes + 37, mspHeaderBytes + 36}}
fields[#fields + 1] = {t = "Gov-I", vals = {mspHeaderBytes + 39, mspHeaderBytes + 38}}
fields[#fields + 1] = {t = "Gov-D", vals = {mspHeaderBytes + 41, mspHeaderBytes + 40}}
fields[#fields + 1] = {t = "Motor ERPM max", vals = {mspHeaderBytes + 44, mspHeaderBytes + 43, mspHeaderBytes + 42}}

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
    title = "Other Settings",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse = {115, 0, 0, 0, 150, 231, 79, 190, 216, 78, 29, 169, 244, 1, 0, 0, 1, 0, 2, 0, 4, 76, 7, 148, 0, 6, 30, 125, 0, 15, 0, 3, 15, 1, 20, 0, 10, 0, 0, 0, 0, 0, 0, 2, 73, 240},
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Other",
    headerLine = rfsuite.escHeaderLineText

}
