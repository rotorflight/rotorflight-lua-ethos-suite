local labels = {}
local fields = {}

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.escBuffer)
local activateWakeup = false




fields[#fields + 1] = {t = "Timing", activeFieldPos = 4, apikey="timing"}
fields[#fields + 1] = {t = "Acceleration", activeFieldPos = 9, apikey="acceleration"}
fields[#fields + 1] = {t = "Brake Type", activeFieldPos = 13, apikey="brake_type"}
fields[#fields + 1] = {t = "Brake Force", activeFieldPos = 14, apikey="brake_force"}
fields[#fields + 1] = {t = "SR Function", activeFieldPos = 15, apikey="sr_function"}
fields[#fields + 1] = {t = "Capacity Correction", activeFieldPos = 16, apikey="capacity_correction"}
fields[#fields + 1] = {t = "Auto Restart Time", activeFieldPos = 10 , apikey="auto_restart_time"}
fields[#fields + 1] = {t = "Cell Cutoff", activeFieldPos = 11, apikey="cell_cutoff"}  


-- This code will disable the field if the ESC does not support it
-- It now uses the activeFieldsPos element to associate to the activeFields table
for i = #fields, 1, -1 do 
    local f = fields[i]
    local fieldIndex = f.activeFieldPos  -- Use activeFieldPos for association
    if activeFields[fieldIndex] == 0 then
        table.remove(fields, i)  -- Remove the field from the table
    end
end


local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.isReady = true
    activateWakeup = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder , "esc/esc_tool.lua")
end

local function event(widget, category, value, x, y)
    
    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder , "esc/esc_tool.lua")
        return true
    end

    return false
end

local function wakeup(self)
    if activateWakeup == true and rfsuite.bg.msp.mspQueue:isProcessed() then
        activateWakeup = false
    end
end

return {
    mspapi="ESC_PARAMETERS_XDFLY",
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    labels = labels,
    fields = fields,
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
