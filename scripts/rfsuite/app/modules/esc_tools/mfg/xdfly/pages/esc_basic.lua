

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.session.escBuffer)
local activateWakeup = false

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_XDFLY",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.xdfly.lv_bec_voltage"),  activeFieldPos = 5, type = 1, mspapi = 1, apikey = "lv_bec_voltage"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.xdfly.hv_bec_voltage"),  activeFieldPos = 11, type = 1, mspapi = 1, apikey = "hv_bec_voltage"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.xdfly.motor_direction"), activeFieldPos = 6, type = 1, mspapi = 1, apikey = "motor_direction"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.xdfly.startup_power"),   activeFieldPos = 12, type = 1, mspapi = 1, apikey = "startup_power"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.xdfly.led_colour"),      activeFieldPos = 18, type = 1, mspapi = 1, apikey = "led_color"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.xdfly.smart_fan"),       activeFieldPos = 19, type = 1, mspapi = 1, apikey = "smart_fan"}
        }
    }                 
}

-- This code will disable the field if the ESC does not support it
-- It now uses the activeFieldsPos element to associate to the activeFields table
for i = #mspapi.formdata.fields, 1, -1 do 
    local f = mspapi.formdata.fields[i]
    local fieldIndex = f.activeFieldPos  -- Use activeFieldPos for association
    if activeFields[fieldIndex] == 0 then
        table.remove(mspapi.formdata.fields, i)  -- Remove the field from the table
    end
end



function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder , "esc_tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder , "esc_tools/esc_tool.lua")
        return true
    end

    return false
end

local function wakeup(self)
    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        activateWakeup = false
    end
end

local foundEsc = false
local foundEscDone = false

return {
    mspapi=mspapi,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = rfsuite.i18n.get("app.modules.esc_tools.name") .. " / " ..  rfsuite.i18n.get("app.modules.esc_tools.mfg.xdfly.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.xdfly.basic"),
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}

