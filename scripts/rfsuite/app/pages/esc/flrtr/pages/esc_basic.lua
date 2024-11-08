local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(compile.loadScript("app/pages/esc/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local flightMode = {"Helicopter", "Fixed Wing"}
local becVoltage = {"7.5", "8.0", "8.5", "12"}
local motorDirection = {"CW", "CCW"}
local fanControl = {"Automatic", "Always On"}

-- fields[#fields + 1] = {t = "ESC type", tablevals = {mspHeaderBytes + 1}, tableIdxInc = -1, table = flightMode} -- informational - maybe put in header
-- fields[#fields + 1] = {t = "Current spec", vals = {mspHeaderBytes + 3, mspHeaderBytes + 2}, unit="A"}  -- informational - maybe put in header?
fields[#fields + 1] = {t = "Cell count", min = 4, max = 14, vals = {mspHeaderBytes + 24}}
fields[#fields + 1] = {t = "BEC voltage", vals = {mspHeaderBytes + 27}, tableIdxInc = -1, table = becVoltage, unit = "V"}
fields[#fields + 1] = {t = "Motor direction", vals = {mspHeaderBytes + 29}, tableIdxInc = -1, table = motorDirection}
fields[#fields + 1] = {t = "Soft start", min = 5, max = 55, vals = {mspHeaderBytes + 35}}
fields[#fields + 1] = {t = "Fan control", vals = {mspHeaderBytes + 34}, tableIdxInc = -1, table = fanControl}

-- fields[#fields + 1] = {t = "Hardware version", vals = {mspHeaderBytes + 18}}  -- this val does not look correct.  regardless not in right place

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
    simulatorResponse = {115, 0, 0, 0, 150, 231, 79, 190, 216, 78, 29, 169, 244, 1, 0, 0, 1, 0, 2, 0, 4, 76, 7, 148, 0, 6, 30, 125, 0, 15, 0, 3, 15, 1, 20, 0, 10, 0, 0, 0, 0, 0, 0, 2, 73, 240},
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Basic",
    headerLine = rfsuite.escHeaderLineText
}

