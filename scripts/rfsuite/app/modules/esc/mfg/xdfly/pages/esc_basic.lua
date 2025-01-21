local labels = {}
local fields = {}

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local activateWakeup = false

local flightMode = {"Helicopter", "Fixed Wing"}
local motorDirection = {"CW", "CCW"}
local startupPower = {"Low", "Medium", "High"}
local fanControl = {"On", "Off"}

fields[#fields + 1] = {t = "LV BEC voltage",min = 60, max = 84, default = 74, step = 2 , scale = 10, decimals = 1, vals = {mspHeaderBytes + 10, mspHeaderBytes + 9}, unit = "V"}
fields[#fields + 1] = {t = "HV BEC voltage",min = 60, max = 120, default = 84, step = 2 , scale = 10, decimals = 1, vals = {mspHeaderBytes + 22, mspHeaderBytes + 21}, tableIdxInc = -1, table = becVoltage, unit = "V"}
fields[#fields + 1] = {t = "Motor direction", vals = {mspHeaderBytes + 12, mspHeaderBytes + 11}, tableIdxInc = -1, table = motorDirection}
fields[#fields + 1] = {t = "Motor Poles", min = 1, max = 550, default = 1, step = 1 ,  vals = {mspHeaderBytes + 34, mspHeaderBytes + 33}}
fields[#fields + 1] = {t = "Startup Power",  vals = {mspHeaderBytes + 24, mspHeaderBytes + 23}, tableIdxInc = -1, table = startupPower}
fields[#fields + 1] = {t = "Smart Fan",  vals = {mspHeaderBytes + 36, mspHeaderBytes + 35}, tableIdxInc = -1, table = fanControl}

-- this code will disable the field if the ESC does not support it
-- it uses the rfsuite.escBuffer variable that is set on first init
for i = #fields, 1, -1 do 
    local f = fields[i]
    if (rfsuite.escBuffer[f.vals[2]] & 0xF0) ~= 0 then
        --print("v:" .. f.t .. " " .. rfsuite.escBuffer[f.vals[2]] .. " " .. rfsuite.escBuffer[f.vals[1]])
        --print("element disabled")
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
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse = {115, 0, 6, 18, 0, 1, 0, 1, 0, 2, 128, 84, 0, 1, 0, 5, 0, 4, 0, 2, 0, 1, 0, 92, 0, 1, 0, 0, 0, 50, 0, 1, 0, 11, 0, 18, 0, 0},
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / XDFLY / Basic",
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}

