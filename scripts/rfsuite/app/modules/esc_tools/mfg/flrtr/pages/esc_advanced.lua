local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

fields[#fields + 1] = {t = "Low voltage protection", apikey="low_voltage_protection"}
fields[#fields + 1] = {t = "Temperature protection",  apikey="temperature_protection"}
fields[#fields + 1] = {t = "Timing angle", apikey="timing_angle"}
fields[#fields + 1] = {t = "Starting torque", apikey="starting_torque"}
fields[#fields + 1] = {t = "Response speed", apikey="response_speed"}
fields[#fields + 1] = {t = "Buzzer volume", apikey="buzzer_volume"}
fields[#fields + 1] = {t = "Current gain", apikey="current_gain"}

local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
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
