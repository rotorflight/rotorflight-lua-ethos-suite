local labels = {}
local fields = {}

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local activateWakeup = false

local lowVoltage = {"OFF", "2.7V", "3.0V", "3.2V", "3.4V", "3.6V", "3.8V"}
local timing = {"Auto", "Low", "Medium", "High"}
local startupPower = {"Low", "Medium", "High"}
local accel = {"Fast", "Normal", "Slow", "Very Slow"}
local brakeType = {"Normal", "Reverse"}
local autoRestart = {"OFF", "90s"}
local srFunc = {"ON", "OFF"}

-- this is a 'session buffer' from first init that can be used to modify the table below
rfsuite.utils.print_r(rfsuite.escBuffer)

fields[#fields + 1] = {t = "Low voltage protection", vals = {mspHeaderBytes + 6, mspHeaderBytes + 5}, tableIdxInc = -1, table = lowVoltage}
fields[#fields + 1] = {t = "Timing", vals = {mspHeaderBytes + 8, mspHeaderBytes + 7}, tableIdxInc = -1, table = timing}
fields[#fields + 1] = {t = "Startup Power", vals = {mspHeaderBytes + 24, mspHeaderBytes + 23}, tableIdxInc = -1, table = startupPower}
fields[#fields + 1] = {t = "Acceleration",  vals = {mspHeaderBytes + 18, mspHeaderBytes + 17}, tableIdxInc = -1, table = accel}
fields[#fields + 1] = {t = "Brake Type", vals = {mspHeaderBytes + 26, mspHeaderBytes + 25}, tableIdxInc = -1, table = brakeType}
fields[#fields + 1] = {t = "Brake Force", min = 0, max = 100, default = 0, vals = {mspHeaderBytes + 28, mspHeaderBytes + 27}, unit = "%"}
fields[#fields + 1] = {t = "SR Function", vals = {mspHeaderBytes + 30, mspHeaderBytes + 29}, tableIdxInc = -1, table = srFunc}
fields[#fields + 1] = {t = "Capacity Correction", min = 0, max = 20, default = 10, offset = -10 , vals = {mspHeaderBytes + 32, mspHeaderBytes + 31}, unit = "%"}
fields[#fields + 1] = {t = "Auto Restart", tableIdxInc = -1, table = autoRestart ,vals = {mspHeaderBytes + 20, mspHeaderBytes + 19}}


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
        for i, f in ipairs(rfsuite.app.Page.fields) do 
            print("v:" .. f.t .. " " .. rfsuite.app.Page.values[f.vals[2]] .. " " .. rfsuite.app.Page.values[f.vals[1]])
            if (rfsuite.app.Page.values[f.vals[2]] & 0xF0) ~= 0 then
                -- rfsuite.app.Page.values[f.vals[2]] = (rfsuite.app.Page.values[f.vals[2]] & 0x7F)
                rfsuite.app.formFields[i]:enable(false)
                print("v:" .. f.t .. " " .. rfsuite.app.Page.values[f.vals[2]] .. " " .. rfsuite.app.Page.values[f.vals[1]])
                print("element disabled")
            end
        end
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
    simulatorResponse = {115, 0, 6, 18, 0, 1, 0, 1, 0, 2, 240, 84, 0, 1, 0, 5, 0, 4, 0, 2, 0, 1, 0, 92, 0, 1, 0, 0, 0, 50, 0, 1, 0, 11, 0, 18, 0, 0,},
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
