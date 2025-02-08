local labels = {}
local fields = {}

local folder = "scorp"


local ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()

local escMode = {"Heli Governor", "Heli Governor (stored)", "VBar Governor", "External Governor", "Airplane mode", "Boat mode", "Quad mode"}

local rotation = {"CCW", "CW"}

local becVoltage = {"5.1 V", "6.1 V", "7.3 V", "8.3 V", "Disabled"}

local teleProtocol = {"Standard", "VBar", "Jeti Exbus", "Unsolicited", "Futaba SBUS"}

labels[#labels + 1] = {t = "Scorpion ESC"}

fields[#fields + 1] = {t = "ESC Mode", min = 0, max = #escMode, tableIdxInc = -1, table = escMode, apikey="esc_mode"}
fields[#fields + 1] = {t = "Rotation", min = 0, max = #rotation, tableIdxInc = -1, table = rotation, apikey="rotation"}
fields[#fields + 1] = {t = "BEC Voltage", min = 0, max = #becVoltage, tableIdxInc = -1, table = becVoltage, apikey="bec_voltage"}

-- not a good idea to allow this to be changed
-- fields[#fields + 1] = {t = "Telemetry Protocol", min = 0, max = #teleProtocol, vals = {mspHeaderBytes + 39, mspHeaderBytes + 40}, tableIdxInc = -1,table = teleProtocol}

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
    mspapi="ESC_PARAMETERS_SCORPION",
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    labels = labels,
    fields = fields,
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
