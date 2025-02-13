local labels = {}
local fields = {}

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

local foundEsc = false
local foundEscDone = false

local govMode = {"External Governor", "ESC Governor"}

fields[#fields + 1] = {t = "Governor", tableIdxInc = -1, table = govMode, apikey="governor"}
fields[#fields + 1] = {t = "Gov-P", min = 1, max = 100, default = 45, apikey="gov_p"}
fields[#fields + 1] = {t = "Gov-I", min = 1, max = 100, default = 35, apikey="gov_i"}
fields[#fields + 1] = {t = "Gov-D", min = 0, max = 100, default = 0, apikey="gov_d"}
fields[#fields + 1] = {t = "Motor ERPM max", min = 0, max = 1000000, step = 100, apikey="motor_erpm_max"}

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
    title = "Governor",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    postLoad = postLoad,
    simulatorResponse =  simulatorResponse,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / FLYROTOR / Governor",
    headerLine = rfsuite.escHeaderLineText

}
