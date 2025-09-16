
local folder = "scorp"


local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_SCORPION",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.protection_delay)@", mspapi = 1, apikey="protection_delay"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.cutoff_handling)@", mspapi = 1, apikey="cutoff_handling"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.max_temperature)@", mspapi = 1, apikey="max_temperature"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.max_current)@",     mspapi = 1, apikey="max_current"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.min_voltage)@",     mspapi = 1, apikey="min_voltage"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.max_used)@",        mspapi = 1, apikey="max_used"}
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
    apidata = apidata,
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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " ..  "@i18n(app.modules.esc_tools.mfg.scorp.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.scorp.limits)@",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "@i18n(app.modules.esc_tools.mfg.scorp.extra_msg_save)@", 
}
