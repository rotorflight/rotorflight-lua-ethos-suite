local labels = {}
local fields = {}

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.escBuffer)
local activateWakeup = false

local flightMode = {"Helicopter", "Fixed Wing"}
local motorDirection = {"CW", "CCW"}
local becLvVoltage = {"6.0V", "7.4V","8.4V"}
local becHvVoltage = {"6.0V", "6.2V", "6.4V", "6.6V", "6.8V", "7.0V", "7.2V", "7.4V", "7.6V", "7.8V", "8.0V", "8.2V", "8.4V", "8.6V", "8.8V", "9.0V", "9.2V", "9.4V", "9.6V", "9.8V", "10.0V", "10.2V", "10.4V", "10.6V", "10.8V", "11.0V", "11.2V", "11.4V", "11.6V", "11.8V", "12.0V"}
local startupPower = {"Low", "Medium", "High"}
local fanControl = {"On", "Off"}
local ledColor = {"RED", "YELOW","ORANGE","GREEN","JADE GREEN","BLUE","CYAN","PURPLE","PINK","WHITE"}

fields[#fields + 1] = {t = "LV BEC voltage", activeFieldPos = 5, min = 60, max = 84, default = 74, step = 2 , scale = 10, decimals = 1, table = becLvVoltage, apikey = "lv_bec_voltage"}
fields[#fields + 1] = {t = "HV BEC voltage",  activeFieldPos = 11, min = 60, max = 120, tableIdxInc = -1, table = becHvVoltage, apikey = "hv_bec_voltage"}
fields[#fields + 1] = {t = "Motor direction",  activeFieldPos = 6, tableIdxInc = -1, table = motorDirection, apikey = "motor_direction"}
fields[#fields + 1] = {t = "Startup Power",   activeFieldPos = 12, tableIdxInc = -1, table = startupPower, apikey = "startup_power"}
fields[#fields + 1] = {t = "LED Colour",   activeFieldPos = 18, tableIdxInc = -1, table = ledColor, apikey = "led_color"}
fields[#fields + 1] = {t = "Smart Fan",   activeFieldPos = 19, tableIdxInc = -1, table = fanControl, apikey = "smart_fan"}

-- This code will disable the field if the ESC does not support it
-- It now uses the activeFieldsPos element to associate to the activeFields table
for i = #fields, 1, -1 do 
    local f = fields[i]
    local fieldIndex = f.activeFieldPos  -- Use activeFieldPos for association
    if activeFields[fieldIndex] == 0 then
        -- print("v:" .. f.t .. " disabled")
        table.remove(fields, i)  -- Remove the field from the table
    end
end



function postLoad()
    rfsuite.app.triggers.isReady = true
    activateWakeup = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder , "esc/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    -- print("Event received:" .. ", " .. category .. "," .. value .. "," .. x .. "," .. y)

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

