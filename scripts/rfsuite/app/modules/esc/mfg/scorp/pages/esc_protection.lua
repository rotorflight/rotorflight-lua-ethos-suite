local labels = {}
local fields = {}

local folder = "scorp"
local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

labels[#labels + 1] = {t = "Scorpion ESC"}

fields[#fields + 1] = {t = "Protection Delay", min = 0, max = 5000, unit = "s", scale = 1000, vals = {mspHeaderBytes + 41, mspHeaderBytes + 42}}
fields[#fields + 1] = {t = "Cutoff Handling", min = 0, max = 10000, unit = "%", scale = 100, vals = {mspHeaderBytes + 49, mspHeaderBytes + 50}}

fields[#fields + 1] = {t = "Max Temperature", min = 0, max = 40000, unit = "°", scale = 100, vals = {mspHeaderBytes + 45, mspHeaderBytes + 46}}
fields[#fields + 1] = {t = "Max Current", min = 0, max = 30000, unit = "A", scale = 100, vals = {mspHeaderBytes + 47, mspHeaderBytes + 48}}
fields[#fields + 1] = {t = "Min Voltage", min = 0, max = 7000, unit = "v", decimals = 1, scale = 100, vals = {mspHeaderBytes + 43, mspHeaderBytes + 44}}
fields[#fields + 1] = {t = "Max Used", min = 0, max = 6000, unit = "Ah", scale = 100, vals = {mspHeaderBytes + 51, mspHeaderBytes + 52}}

local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.isReady = true
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

return {
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = false,
    reboot = false,
    title = "Limits",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    simulatorResponse = {83, 128, 84, 114, 105, 98, 117, 110, 117, 115, 32, 69, 83, 67, 45, 54, 83, 45, 56, 48, 65, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 3, 0, 3, 0, 1, 0, 3, 0, 136, 19, 22, 3, 16, 39, 64, 31, 136, 19, 0, 0, 1, 0, 7, 2, 0, 6, 63, 0, 160, 15, 64, 31, 208, 7, 100, 0, 0, 0, 200, 0, 0, 0, 1, 0, 0, 0, 200, 250, 0, 0},
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Scorpion / Limits",
    headerLine = rfsuite.escHeaderLineText
}
