local labels = {}
local fields = {}

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.escBuffer)
local activateWakeup = false


fields[#fields + 1] = {t = "LV BEC voltage", activeFieldPos = 5, type = 1, apikey = "lv_bec_voltage"}
fields[#fields + 1] = {t = "HV BEC voltage",  activeFieldPos = 11, type = 1,apikey = "hv_bec_voltage"}
fields[#fields + 1] = {t = "Motor direction",  activeFieldPos = 6, type = 1,apikey = "motor_direction"}
fields[#fields + 1] = {t = "Startup Power",   activeFieldPos = 12, apikey = "startup_power"}
fields[#fields + 1] = {t = "LED Colour",   activeFieldPos = 18, type = 1, apikey = "led_color"}
fields[#fields + 1] = {t = "Smart Fan",   activeFieldPos = 19, type = 1, apikey = "smart_fan"}

-- This code will disable the field if the ESC does not support it
-- It now uses the activeFieldsPos element to associate to the activeFields table
for i = #fields, 1, -1 do 
    local f = fields[i]
    local fieldIndex = f.activeFieldPos  -- Use activeFieldPos for association
    if activeFields[fieldIndex] == 0 then
        table.remove(fields, i)  -- Remove the field from the table
    end
end



function postLoad()
    rfsuite.app.triggers.isReady = true
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
    if activateWakeup == true and rfsuite.bg.msp.mspQueue:isProcessed() then
        activateWakeup = false
    end
end

local foundEsc = false
local foundEscDone = false

return {
    mspapi="ESC_PARAMETERS_XDFLY",
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / XDFLY / Basic",
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}

