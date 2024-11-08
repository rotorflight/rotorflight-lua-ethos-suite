local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(loadfile("app/pages/esc/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

-- fields[#fields + 1] = {t = "Throttle min", min = 1000, max = 2000, default = 1100, vals = {mspHeaderBytes + 20, mspHeaderBytes + 19},unit = "us"} -- informational only. cant be saved
-- fields[#fields + 1] = {t = "Throttle max", min = 1000, max = 2000, default = 1940,  vals = {mspHeaderBytes + 22, mspHeaderBytes + 21},unit = "us"} -- informational only. cant be saved
fields[#fields + 1] = {t = "Low voltage protection", min = 28, max = 38, scale = 10, default = 30, decimals = 1, vals = {mspHeaderBytes + 25}, unit = "V"}
fields[#fields + 1] = {t = "Temperature protection", min = 50, max = 150, default = 125, vals = {mspHeaderBytes + 26}, unit = "°"}
fields[#fields + 1] = {t = "Timing angle", min = 1, max = 20, default = 10, vals = {mspHeaderBytes + 28}, unit = "°"}
fields[#fields + 1] = {t = "Starting torque", min = 1, max = 15, default = 3, vals = {mspHeaderBytes + 30}}
fields[#fields + 1] = {t = "Response speed", min = 1, max = 15, default = 5, vals = {mspHeaderBytes + 31}}
fields[#fields + 1] = {t = "Buzzer volume", min = 1, max = 5, default = 2, vals = {mspHeaderBytes + 32}}
fields[#fields + 1] = {t = "Current gain", min = 0, max = 40, default = 20, offset = -20, vals = {mspHeaderBytes + 33}}

local foundEsc = false
local foundEscDone = false

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
    title = "Advanced Setup",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse = {115, 0, 0, 0, 150, 231, 79, 190, 216, 78, 29, 169, 244, 1, 0, 0, 1, 0, 2, 0, 4, 76, 7, 148, 0, 6, 30, 125, 0, 15, 0, 3, 15, 1, 20, 0, 10, 0, 0, 0, 0, 0, 0, 2, 73, 240},
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
