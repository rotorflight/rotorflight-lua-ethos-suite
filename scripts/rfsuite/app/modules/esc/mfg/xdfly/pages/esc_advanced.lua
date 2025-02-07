local labels = {}
local fields = {}

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.escBuffer)
local activateWakeup = false

local lowVoltage = {"OFF", "2.7V", "3.0V", "3.2V", "3.4V", "3.6V", "3.8V"}
local timing = {"Auto", "Low", "Medium", "High"}
local startupPower = {"Low", "Medium", "High"}
local accel = {"Fast", "Normal", "Slow", "Very Slow"}
local brakeType = {"Normal", "Reverse"}
local autoRestart = {"OFF", "90s"}
local srFunc = {"ON", "OFF"}


fields[#fields + 1] = {t = "Timing", activeFieldPos = 3 + 1, vals = {mspHeaderBytes + 7, mspHeaderBytes + 8}, tableIdxInc = -1, table = timing}
fields[#fields + 1] = {t = "Startup Power", activeFieldPos = 11 + 1, vals = {mspHeaderBytes + 23, mspHeaderBytes + 24}, tableIdxInc = -1, table = startupPower}
fields[#fields + 1] = {t = "Acceleration", activeFieldPos = 8 + 1, vals = {mspHeaderBytes + 17, mspHeaderBytes + 18}, tableIdxInc = -1, table = accel}
fields[#fields + 1] = {t = "Brake Type", activeFieldPos = 12 + 1, vals = {mspHeaderBytes + 25, mspHeaderBytes + 26}, tableIdxInc = -1, table = brakeType}
fields[#fields + 1] = {t = "Brake Force", activeFieldPos = 13 + 1, min = 0, max = 100, default = 0, vals = {mspHeaderBytes + 27, mspHeaderBytes + 28}, unit = "%"}
fields[#fields + 1] = {t = "SR Function", activeFieldPos = 14 + 1, vals = {mspHeaderBytes + 29, mspHeaderBytes + 30}, tableIdxInc = -1, table = srFunc}
fields[#fields + 1] = {t = "Capacity Correction", activeFieldPos = 15 + 1, min = 0, max = 20, default = 10, offset = -10 , vals = {mspHeaderBytes + 31, mspHeaderBytes + 32}, unit = "%"}
fields[#fields + 1] = {t = "Auto Restart Time", activeFieldPos = 9 + 1, tableIdxInc = -1, table = autoRestart ,vals = {mspHeaderBytes + 19, mspHeaderBytes + 20}}
fields[#fields + 1] = {t = "Cell Cutoff", activeFieldPos = 10 + 1, vals = {mspHeaderBytes + 5, mspHeaderBytes + 6}, tableIdxInc = -1, table = lowVoltage}

-- This code will disable the field if the ESC does not support it
-- It now uses the activeFieldsPos element to associate to the activeFields table
for i = #fields, 1, -1 do 
    local f = fields[i]
    local fieldIndex = f.activeFieldPos  -- Use activeFieldPos for association
    if activeFields[fieldIndex] == 0 then
         print("v:" .. f.t .. " disabled")
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

return {
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    minBytes = mspBytes,
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
