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


fields[#fields + 1] = {t = "Timing", activeFieldPos = 3 + 1, xvals = {9, 10}, tableIdxInc = -1, table = timing, mspkey="timing"}
fields[#fields + 1] = {t = "Startup Power", activeFieldPos = 11 + 1, xvals = {25, 26}, tableIdxInc = -1, table = startupPower, mspkey="startup_power"}
fields[#fields + 1] = {t = "Acceleration", activeFieldPos = 8 + 1, xvals = {19, 20}, tableIdxInc = -1, table = accel, mspkey="acceleration"}
fields[#fields + 1] = {t = "Brake Type", activeFieldPos = 12 + 1, xvals = {27, 28}, tableIdxInc = -1, table = brakeType, mspkey="brake_type"}
fields[#fields + 1] = {t = "Brake Force", activeFieldPos = 13 + 1, xmin = 0, max = 100, default = 0, vals = {29, 30}, unit = "%", mspkey="brake_force"}
fields[#fields + 1] = {t = "SR Function", activeFieldPos = 14 + 1, xvals = {31, 32}, tableIdxInc = -1, table = srFunc, mspkey="sr_function"}
fields[#fields + 1] = {t = "Capacity Correction", activeFieldPos = 15 + 1, min = 0, max = 20, default = 10, offset = -10 , xvals = {33, 34}, unit = "%", mspkey="capacity_correction"}
fields[#fields + 1] = {t = "Auto Restart Time", activeFieldPos = 9 + 1, tableIdxInc = -1, table = autoRestart ,xvals = {21, 22}, mspkey="auto_restart_time"}
fields[#fields + 1] = {t = "Cell Cutoff", activeFieldPos = 10 + 1, xvals = {7, 8}, tableIdxInc = -1, table = lowVoltage, mspkey="cell_cutoff"}  


-- This code will disable the field if the ESC does not support it
-- It now uses the activeFieldsPos element to associate to the activeFields table
for i = #fields, 1, -1 do 
    local f = fields[i]
    local fieldIndex = f.activeFieldPos  -- Use activeFieldPos for association
    if activeFields[fieldIndex] == 0 then
        --print("v:" .. f.t .. " disabled")
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
