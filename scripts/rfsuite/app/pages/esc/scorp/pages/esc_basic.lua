local labels = {}
local fields = {}

local folder = "scorp"
local ESC = assert(compile.loadScript("app/pages/esc/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local ESC = assert(compile.loadScript("app/pages/esc/" .. folder .. "/init.lua"))()

local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature

local escMode = {"Heli Governor", "Heli Governor (stored)", "VBar Governor", "External Governor", "Airplane mode", "Boat mode", "Quad mode"}

local rotation = {"CCW", "CW"}

local becVoltage = {"5.1 V", "6.1 V", "7.3 V", "8.3 V", "Disabled"}

local teleProtocol = {"Standard", "VBar", "Jeti Exbus", "Unsolicited", "Futaba SBUS"}

labels[#labels + 1] = {t = "Scorpion ESC"}

fields[#fields + 1] = {t = "ESC Mode", min = 0, max = #escMode, vals = {mspHeaderBytes + 33, mspHeaderBytes + 34}, tableIdxInc = -1, table = escMode}
fields[#fields + 1] = {t = "Rotation", min = 0, max = #rotation, vals = {mspHeaderBytes + 37, mspHeaderBytes + 38}, tableIdxInc = -1, table = rotation}
fields[#fields + 1] = {t = "BEC Voltage", min = 0, max = #becVoltage, vals = {mspHeaderBytes + 35, mspHeaderBytes + 36}, tableIdxInc = -1, table = becVoltage}

-- not a good idea to allow this to be changed
-- fields[#fields + 1] = {t = "Telemetry Protocol", min = 0, max = #teleProtocol, vals = {mspHeaderBytes + 39, mspHeaderBytes + 40}, tableIdxInc = -1,table = teleProtocol}

function postLoad()
    rfsuite.app.triggers.isReady = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_tool.lua")
end

local function event(widget, category, value, x, y)

    -- print("Event received:" .. ", " .. category .. "," .. value .. "," .. x .. "," .. y)

    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder, "esc_tool.lua")
        return true
    end

    return false
end

return {
    read = 217, -- msp_ESC_PARAMETERS
    write = 218, -- msp_SET_ESC_PARAMETERS
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    minBytes = mspBytes,
    labels = labels,
    fields = fields,
    simulatorResponse = {
        83, 128, 84, 114, 105, 98, 117, 110, 117, 115, 32, 69, 83, 67, 45, 54, 83, 45, 56, 48, 65, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 3, 0, 3, 0, 1, 0, 3, 0, 136, 19, 22, 3, 16, 39, 64, 31, 136,
        19, 0, 0, 1, 0, 7, 2, 0, 6, 63, 0, 160, 15, 64, 31, 208, 7, 100, 0, 0, 0, 200, 0, 0, 0, 1, 0, 0, 0, 200, 250, 0, 0
    },
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / Scorpion / Basic",
    headerLine = rfsuite.escHeaderLineText
}
