local labels = {}
local fields = {}

local folder = "scorp"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local onOff = {"On", "Off"}

labels[#labels + 1] = {t = "Scorpion ESC"}

fields[#fields + 1] = {t = "Soft Start Time", unit = "s", min = 0, max = 60000, scale = 1000, vals = {mspHeaderBytes + 61, mspHeaderBytes + 62}}
fields[#fields + 1] = {t = "Runup Time", unit = "s", min = 0, max = 60000, scale = 1000, vals = {mspHeaderBytes + 63, mspHeaderBytes + 64}}
fields[#fields + 1] = {t = "Bailout", unit = "s", min = 0, max = 100000, scale = 1000, vals = {mspHeaderBytes + 65, mspHeaderBytes + 66}}

-- data types are IQ22 - decoded/encoded by FC - regual scaled integers here
fields[#fields + 1] = {t = "Gov Proportional", min = 30, max = 180, scale = 100, vals = {mspHeaderBytes + 67, mspHeaderBytes + 68, mspHeaderBytes + 69, mspHeaderBytes + 70}}
fields[#fields + 1] = {t = "Gov Integral", min = 150, max = 250, scale = 100, vals = {mspHeaderBytes + 71, mspHeaderBytes + 72, mspHeaderBytes + 73, mspHeaderBytes + 74}}

fields[#fields + 1] = {t = "Motor Startup Sound", min = 0, max = #onOff, vals = {mspHeaderBytes + 53, mspHeaderBytes + 54}, tableIdxInc = -1, table = onOff}

local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    -- print("Event received:" .. ", " .. category .. "," .. value .. "," .. x .. "," .. y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder, "esc/esc_tool.lua")
        return true
    end

    return false
end

return {
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = false,
    reboot = false,
    title = "Advanced Setup",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    svFlags = 0,
    simulatorResponse = {83, 128, 84, 114, 105, 98, 117, 110, 117, 115, 32, 69, 83, 67, 45, 54, 83, 45, 56, 48, 65, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 3, 0, 3, 0, 1, 0, 3, 0, 136, 19, 22, 3, 16, 39, 64, 31, 136, 19, 0, 0, 1, 0, 7, 2, 0, 6, 63, 0, 160, 15, 64, 31, 208, 7, 100, 0, 0, 0, 200, 0, 0, 0, 1, 0, 0, 0, 200, 250, 0, 0},
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Scorpion / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
