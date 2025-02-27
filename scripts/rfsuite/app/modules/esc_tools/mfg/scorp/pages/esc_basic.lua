

local folder = "scorp"


local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_SCORPION",
    },
    formdata = {
        labels = {
        },
        fields = {

            {t = "ESC Mode", type = 1, mspapi=1, apikey="esc_mode"},
            {t = "Rotation", type = 1, mspapi=1, apikey="rotation"},
            {t = "BEC Voltage", type = 1, mspapi=1, apikey="bec_voltage"},
            -- {t = "Telemetry Protocol", type = 1, mspapi=1, apikey="telemetry_protocol"} -- not used as dangerous to change
        }
    }                 
}




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
    title = "Basic Setup",
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
