local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

fields[#fields + 1] = {t = "Low voltage protection", min = 28, max = 38, scale = 10, default = 30, decimals = 1, unit = "V", apikey="low_voltage_protection"}
fields[#fields + 1] = {t = "Temperature protection", min = 50, max = 135, default = 125, unit = "°", apikey="temperature_protection"}
fields[#fields + 1] = {t = "Timing angle", min = 1, max = 10, default = 5, unit = "°", apikey="timing_angle"}
fields[#fields + 1] = {t = "Starting torque", min = 1, max = 15, default = 3, apikey="starting_torque"}
fields[#fields + 1] = {t = "Response speed", min = 1, max = 15, default = 5, apikey="response_speed"}
fields[#fields + 1] = {t = "Buzzer volume", min = 1, max = 5, default = 2, apikey="buzzer_volume"}
fields[#fields + 1] = {t = "Current gain", min = 0, max = 40, default = 20, offset = -20, apikey="current_gain"}

local foundEsc = false
local foundEscDone = false

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
    mspapi="ESC_PARAMETERS_FLYROTOR",    
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse =  simulatorResponse,
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
