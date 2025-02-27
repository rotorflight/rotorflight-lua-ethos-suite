
local folder = "scorp"

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_SCORPION",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Protection Delay", mspapi = 1, apikey="protection_delay"},
            {t = "Cutoff Handling", mspapi = 1, apikey="cutoff_handling"},
            {t = "Max Temperature", mspapi = 1, apikey="max_temperature"},
            {t = "Max Current", mspapi = 1, apikey="max_current"},
            {t = "Min Voltage", mspapi = 1, apikey="min_voltage"},
            {t = "Max Used", mspapi = 1, apikey="max_used"}
        }
    }                 
}




local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
        return true
    end


end

return {
    mspapi=mspapi,
    eepromWrite = false,
    reboot = false,
    title = "Limits",
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
