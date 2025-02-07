local labels = {}
local fields = {}

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activeFields = ESC.getActiveFields(rfsuite.escBuffer)
local activateWakeup = false

local foundEsc = false
local foundEscDone = false

local govMode = {"External Governor", "ESC Governor" , "Fixed Wing"}

fields[#fields + 1] = {t = "Governor", activeFieldPos = 1 + 1,  vals = {mspHeaderBytes + 3, mspHeaderBytes + 4}, tableIdxInc = -1, table = govMode}
fields[#fields + 1] = {t = "Gov-P", activeFieldPos = 6,  vals = {mspHeaderBytes + 13, mspHeaderBytes + 14}, min = 1, max = 10, default = 4}
fields[#fields + 1] = {t = "Gov-I", activeFieldPos = 7,  vals = {mspHeaderBytes + 15, mspHeaderBytes + 16}, min = 1, max = 10, default = 3}

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
    title = "Governor",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse =  simulatorResponse,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / XDFLY / Governor",
    headerLine = rfsuite.escHeaderLineText,
    wakeup = wakeup
}
