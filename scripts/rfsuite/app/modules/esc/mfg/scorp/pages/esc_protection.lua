local labels = {}
local fields = {}

local folder = "scorp"


labels[#labels + 1] = {t = "Scorpion ESC"}

fields[#fields + 1] = {t = "Protection Delay", apikey="protection_delay"}
fields[#fields + 1] = {t = "Cutoff Handling", apikey="cutoff_handling"}

fields[#fields + 1] = {t = "Max Temperature",apikey="max_temperature"}
fields[#fields + 1] = {t = "Max Current",  apikey="max_current"}
fields[#fields + 1] = {t = "Min Voltage" ,apikey="min_voltage"}
fields[#fields + 1] = {t = "Max Used", apikey="max_used"}

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
    mspapi="ESC_PARAMETERS_SCORPION",
    eepromWrite = false,
    reboot = false,
    title = "Limits",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Scorpion / Limits",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "Please reboot the ESC to apply the changes",   
}
