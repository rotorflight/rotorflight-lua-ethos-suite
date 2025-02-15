local labels = {}
local fields = {}

local folder = "scorp"


local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()



labels[#labels + 1] = {t = "Scorpion ESC"}

fields[#fields + 1] = {t = "ESC Mode", type = 1, apikey="esc_mode"}
fields[#fields + 1] = {t = "Rotation", type = 1, apikey="rotation"}
fields[#fields + 1] = {t = "BEC Voltage", type = 1, apikey="bec_voltage"}
-- fields[#fields + 1] = {t = "Telemetry Protocol", type = 1, apikey="telemetry_protocol"} -- not used as dangerous to change

function postLoad()
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc/esc_tool.lua")
end

local function event(widget, category, value, x, y)

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
    title = "Basic Setup",
    labels = labels,
    fields = fields,
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Scorpion / Basic",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "Please reboot the ESC to apply the changes",    
}
