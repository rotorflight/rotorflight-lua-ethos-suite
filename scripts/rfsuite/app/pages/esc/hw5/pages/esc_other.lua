local labels = {}
local fields = {}

local folder = "hw5"
local ESC = assert(compile.loadScript("app/pages/esc/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local startupPower = {[0] = "1", "2", "3", "4", "5", "6", "7"}

local enabledDisabled = {[0] = "Enabled", "Disabled"}

local brakeType = {[0] = "Disabled", "Normal", "Proportional", "Reverse"}

labels[#labels + 1] = {t = "Motor", label = "motor1", inline_size = 40.6}
fields[#fields + 1] = {t = "Timing", inline = 1, label = "motor1", min = 0, max = 30, vals = {mspHeaderBytes + 76}}

labels[#labels + 1] = {t = "", label = "motor2", inline_size = 40.6}
fields[#fields + 1] = {t = "Startup Power", inline = 1, label = "motor2", min = 0, max = #startupPower, vals = {mspHeaderBytes + 79}, table = startupPower}

labels[#labels + 1] = {t = "", label = "motor3", inline_size = 40.6}
fields[#fields + 1] = {t = "Active Freewheel", inline = 1, label = "motor3", min = 0, max = #enabledDisabled, vals = {mspHeaderBytes + 78}, table = enabledDisabled}

labels[#labels + 1] = {t = "Brake", label = "brake1", inline_size = 40.6}
fields[#fields + 1] = {t = "Brake Type", inline = 1, label = "brake1", min = 0, max = #brakeType, vals = {mspHeaderBytes + 74}, table = brakeType}

labels[#labels + 1] = {t = "", label = "brake2", inline_size = 40.6}
fields[#fields + 1] = {t = "Brake Force %", inline = 1, label = "brake2", min = 0, max = 100, vals = {mspHeaderBytes + 75}}

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
    simulatorResponse = {
        253, 0, 32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32, 72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66, 80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32,
        32, 32, 32, 32, 80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32, 0, 0, 0, 3, 0, 11, 6, 5, 25, 1, 0, 0, 24, 0, 0, 2
    },
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Hobbywing V5 / Other",
    headerLine = rfsuite.escHeaderLineText
}
