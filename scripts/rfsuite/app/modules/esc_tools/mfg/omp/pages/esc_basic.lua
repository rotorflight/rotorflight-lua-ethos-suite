

local folder = "omp"
local ESC = assert(rfsuite.compiler.loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.session.escBuffer)
local activateWakeup = false
local i18n = rfsuite.i18n.get

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_OMP",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = i18n("app.modules.esc_tools.mfg.omp.lv_bec_voltage"),  activeFieldPos = 5, type = 1, mspapi = 1, apikey = "lv_bec_voltage"},
            {t = i18n("app.modules.esc_tools.mfg.omp.hv_bec_voltage"),  activeFieldPos = 11, type = 1, mspapi = 1, apikey = "hv_bec_voltage"},
            {t = i18n("app.modules.esc_tools.mfg.omp.motor_direction"), activeFieldPos = 6, type = 1, mspapi = 1, apikey = "motor_direction"},
            {t = i18n("app.modules.esc_tools.mfg.omp.startup_power"),   activeFieldPos = 12, type = 1, mspapi = 1, apikey = "startup_power"},
            {t = i18n("app.modules.esc_tools.mfg.omp.led_color"),       activeFieldPos = 18, type = 1, mspapi = 1, apikey = "led_color"},
            {t = i18n("app.modules.esc_tools.mfg.omp.smart_fan"),       activeFieldPos = 19, type = 1, mspapi = 1, apikey = "smart_fan"}
        }
    }                 
}

-- This code will disable the field if the ESC does not support it
-- It now uses the activeFieldsPos element to associate to the activeFields table
for i = #apidata.formdata.fields, 1, -1 do 
    local f = apidata.formdata.fields[i]
    local fieldIndex = f.activeFieldPos  -- Use activeFieldPos for association
    if activeFields[fieldIndex] == 0 then
        table.remove(apidata.formdata.fields, i)  -- Remove the field from the table
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

    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
        return true
    end


end

local function wakeup(self)
    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        activateWakeup = false
    end
end

local foundEsc = false
local foundEscDone = false

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = i18n("app.modules.esc_tools.name") .. " / " ..  i18n("app.modules.esc_tools.mfg.omp.name") .. " / " .. i18n("app.modules.esc_tools.mfg.omp.basic"),
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}

