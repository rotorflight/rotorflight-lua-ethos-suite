local labels = {}
local fields = {}

local folder = "hw5"
local ESC = assert(compile.loadScript("app/pages/esc/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local restartTime = {"1s", "1.5s", "2s", "2.5s", "3s"}

labels[#labels + 1] = {t = "Governor", label = "gov", inline_size = 13.4}
fields[#fields + 1] = {t = "P-Gain", inline = 2, label = "gov", min = 0, max = 9, vals = {mspHeaderBytes + 70}}
fields[#fields + 1] = {t = "I-Gain", inline = 1, label = "gov", min = 0, max = 9, vals = {mspHeaderBytes + 71}}

labels[#labels + 1] = {t = "Soft Start", label = "start", inline_size = 40.6}
fields[#fields + 1] = {t = "Startup Time", inline = 1, label = "start", units = "s", min = 4, max = 25, vals = {mspHeaderBytes + 69}}

labels[#labels + 1] = {t = "", label = "start2", inline_size = 40.6}
fields[#fields + 1] = {t = "Restart Time", inline = 1, label = "start2", units = "s", tableIdxInc = -1, min = 0, max = #restartTime, vals = {mspHeaderBytes + 73}, table = restartTime}

labels[#labels + 1] = {t = "", label = "start3", inline_size = 40.6}
fields[#fields + 1] = {t = "Auto Restart", inline = 1, label = "start3", units = "s", min = 0, max = 90, vals = {mspHeaderBytes + 72}}

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
    simulatorResponse = {
        253, 0, 32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32, 72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66, 80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32,
        32, 32, 32, 32, 80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32, 0, 0, 0, 3, 0, 11, 6, 5, 25, 1, 0, 0, 24, 0, 0, 2
    },
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Hobbywing V5 / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
