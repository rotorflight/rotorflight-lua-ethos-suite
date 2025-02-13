local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse



fields[#fields + 1] = {t = "Cell count", apikey="cell_count"}
fields[#fields + 1] = {t = "BEC voltage", apikey="bec_voltage", type = 1}
fields[#fields + 1] = {t = "Motor direction", apikey="motor_direction", type = 1}
fields[#fields + 1] = {t = "Soft start", apikey="soft_start"}
fields[#fields + 1] = {t = "Fan control", apikey="fan_control"}

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

