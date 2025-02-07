local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

local flightMode = {"Helicopter", "Fixed Wing"}
local becVoltage = {"7.5", "8.0", "8.5", "12"}
local motorDirection = {"CW", "CCW"}
local fanControl = {"Automatic", "Always On"}


fields[#fields + 1] = {t = "Cell count", min = 4, max = 14, apikey="cell_count"}
fields[#fields + 1] = {t = "BEC voltage", tableIdxInc = -1, table = becVoltage, unit = "V", apikey="bec_voltage"}
fields[#fields + 1] = {t = "Motor direction", tableIdxInc = -1, table = motorDirection, apikey="motor_direction"}
fields[#fields + 1] = {t = "Soft start", min = 5, max = 55, apikey="soft_start"}
fields[#fields + 1] = {t = "Fan control", tableIdxInc = -1, table = fanControl, apikey="fan_control"}

-- fields[#fields + 1] = {t = "Hardware version", vals = {mspHeaderBytes + 18}}  -- this val does not look correct.  regardless not in right place

rfsuite.utils.print_r(rfsuite.app.Page.values)

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
    mspapi="ESC_PARAMETERS_FLYROTOR",
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    svFlags = 0,
    simulatorResponse =  simulatorResponse,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Basic",
    headerLine = rfsuite.escHeaderLineText
}

