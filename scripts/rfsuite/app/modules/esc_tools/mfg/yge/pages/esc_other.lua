local labels = {}
local fields = {}

local folder = "yge"


local foundEsc = false
local foundEscDone = false

labels[#labels + 1] = {t = "ESC"}

fields[#fields + 1] = {t = "P-Gain", apikey="gov_p"}
fields[#fields + 1] = {t = "I-Gain", apikey="gov_i"}

fields[#fields + 1] = {t = "Motor Pole Pairs", apikey="motor_pole_pairs"}
fields[#fields + 1] = {t = "Main Teeth", apikey="main_teeth"}
fields[#fields + 1] = {t = "Pinion Teeth" , apikey="pinion_teeth"}

fields[#fields + 1] = {t = "Stick Zero (us)", apikey="stick_zero_us"}
fields[#fields + 1] = {t = "Stick Range (us)", apikey="stick_range_us"}

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
    mspapi = "ESC_PARAMETERS_YGE",
    eepromWrite = true,
    reboot = false,
    title = "Other Settings",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / YGE / Other",
    headerLine = rfsuite.escHeaderLineText

}
