
local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.escBuffer)
local activateWakeup = false

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_XDFLY",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Timing",              activeFieldPos = 4,  mspapi = 1, apikey = "timing"},
            {t = "Acceleration",        activeFieldPos = 9,  mspapi = 1, apikey = "brake_type"},
            {t = "Brake Force",         activeFieldPos = 14, mspapi = 1, apikey = "brake_force"},
            {t = "SR Function",         activeFieldPos = 15, mspapi = 1, apikey = "sr_function"},
            {t = "Capacity Correction", activeFieldPos = 16, mspapi = 1, apikey = "capacity_correction"},
            {t = "Auto Restart Time",   activeFieldPos = 10, mspapi = 1, apikey = "auto_restart_time"},
            {t = "Cell Cutoff",         activeFieldPos = 11, mspapi = 1, apikey = "cell_cutoff"}
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

return {
    mspapi=mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    escinfo = escinfo,
    simulatorResponse =  simulatorResponse,
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / XDFLY / Advanced",
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}
