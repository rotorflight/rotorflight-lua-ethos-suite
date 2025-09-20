
local folder = "omp"
local ESC = assert(rfsuite.compiler.loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.session.escBuffer)
local activateWakeup = false


local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_OMP",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.omp.timing)@",              activeFieldPos = 4,  mspapi = 1, type = 1, apikey = "timing"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.acceleration)@",        activeFieldPos = 9,  mspapi = 1, type = 1, apikey = "acceleration"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.brake_force)@",         activeFieldPos = 14, mspapi = 1, apikey = "brake_force"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.sr_function)@",         activeFieldPos = 15, mspapi = 1, type = 1, apikey = "sr_function"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.capacity_correction)@", activeFieldPos = 16, mspapi = 1, apikey = "capacity_correction"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.auto_restart_time)@",   activeFieldPos = 10, mspapi = 1, type = 1, apikey = "auto_restart_time"},
            {t = "@i18n(app.modules.esc_tools.mfg.omp.cell_cutoff)@",         activeFieldPos = 11, mspapi = 1, type = 1, apikey = "cell_cutoff"}
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


local foundEsc = false
local foundEscDone = false

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
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " ..  "@i18n(app.modules.esc_tools.mfg.omp.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.omp.advanced)@",
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}
