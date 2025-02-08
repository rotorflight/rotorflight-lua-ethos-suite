local labels = {}
local fields = {}

local folder = "yge"

-- update pole count label text
local function updatePoles(self)
    local f = self.fields[3]
    -- local l = self.labels[4]
    l.t = f.value * 2
end

-- update gear ratio label text
local function updateRatio(self)
    local fm = self.fields[4]
    local fp = self.fields[5]
    -- local l = self.labels[5]
    local v = fp.value ~= 0 and fm.value / fp.value or 0
    l.t = string.format("%.2f", v) .. ":1"
end

local foundEsc = false
local foundEscDone = false

labels[#labels + 1] = {t = "ESC"}

fields[#fields + 1] = {t = "P-Gain", min = 1, max = 10, apikey="gov_p"}
fields[#fields + 1] = {t = "I-Gain", min = 1, max = 10, apikey="gov_i"}

fields[#fields + 1] = {t = "Motor Pole Pairs", min = 1, max = 100, upd = updatePoles, apikey="motor_pole_pairs"}
labels[#labels + 1] = {t = "0"}
fields[#fields + 1] = {t = "Main Teeth", min = 1, max = 1800, upd = updateRatio, apikey="main_teeth"}
labels[#labels + 1] = {t = ":"}
fields[#fields + 1] = {t = "Pinion Teeth", min = 1, max = 255, apikey="pinion_teeth"}

fields[#fields + 1] = {t = "Stick Zero (us)", min = 900, max = 1900, apikey="stick_zero_us"}
fields[#fields + 1] = {t = "Stick Range (us)", min = 600, max = 1500, apikey="stick_range_us"}

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
    mspapi = "ESC_PARAMETERS_YGE",
    eepromWrite = true,
    reboot = false,
    title = "Other Settings",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / YGE / Other",
    headerLine = rfsuite.escHeaderLineText

}
