local labels = {}
local fields = {}

local folder = "scorp"




labels[#labels + 1] = {t = "Scorpion ESC"}

fields[#fields + 1] = {t = "Soft Start Time", apikey="soft_start_time"}
fields[#fields + 1] = {t = "Runup Time", apikey="runup_time"}
fields[#fields + 1] = {t = "Bailout", apikey="bailout"}

-- data types are IQ22 - decoded/encoded by FC - regual scaled integers here
fields[#fields + 1] = {t = "Gov Proportional", apikey="gov_proportional"}
fields[#fields + 1] = {t = "Gov Integral", apikey="gov_integral"}

fields[#fields + 1] = {t = "Motor Startup Sound", type = 1, apikey="motor_startup_sound"}

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
    mspapi="ESC_PARAMETERS_SCORPION",
    eepromWrite = false,
    reboot = false,
    title = "Advanced Setup",
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
    pageTitle = "ESC / Scorpion / Advanced",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "Please reboot the ESC to apply the changes",   
}
