

local folder = "omp"
local ESC = assert(rfsuite.compiler.loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.session.escBuffer)
local activateWakeup = false


local foundEsc = false
local foundEscDone = false

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_OMP",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.omp.gov)@", activeFieldPos = 2, type = 1,  mspapi = 1, apikey = "governor"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.gov_p)@", activeFieldPos = 6,  mspapi = 1, apikey="gov_p"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.gov_i)@", activeFieldPos = 7,  mspapi = 1, apikey="gov_i"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.motor_poles)@",  activeFieldPos = 17 ,  mspapi = 1, apikey="motor_poles"},
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

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " ..  "@i18n(app.modules.esc_tools.mfg.omp.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.omp.governor)@",
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}
