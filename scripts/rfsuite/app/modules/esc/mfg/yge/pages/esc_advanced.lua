local labels = {}
local fields = {}

local folder = "yge"

local offOn = {"Off", "On"}

local startupResponse = {"Normal", "Smooth"}

local throttleResponse = {"Slow", "Medium", "Fast", "Custom (PC defined)"}

local motorTiming = {"Auto Normal", "Auto Efficient", "Auto Power", "Auto Extreme", "0 deg", "6 deg", "12 deg", "18 deg", "24 deg", "30 deg"}

local motorTimingToUI = {0, 4, 5, 6, 7, 8, 9, [16] = 0, [17] = 1, [18] = 2, [19] = 3}

local motorTimingFromUI = {0, 17, 18, 19, 1, 2, 3, 4, 5, 6}

local freewheel = {"Off", "Auto", "*unused*", "Always On"}

labels[#labels + 1] = {t = "ESC"}

fields[#fields + 1] = {t = "Min Start Power", min = 0, max = 26, unit = "%", apikey="min_start_power"}
fields[#fields + 1] = {t = "Max Start Power", min = 0, max = 31, unit = "%", apikey="max_start_power"}
-- not sure this field exists?
-- fields[#fields + 1] = {t = "Startup Response", min = 0, max = #startupResponse, vals = {11, 12}, table = startupResponse}
fields[#fields + 1] = {t = "Throttle Response", min = 0, max = #throttleResponse, tableIdxInc = -1, table = throttleResponse, apikey="throttle_response"}

fields[#fields + 1] = {t = "Motor Timing", min = 0, max = #motorTiming, tableIdxInc = -1, table = motorTiming, apikey="timing"}
fields[#fields + 1] = {t = "Active Freewheel", min = 0, max = #freewheel, tableIdxInc = -1, table = freewheel, apikey="active_freewheel"}
fields[#fields + 1] = {t = "F3C Autorotation", min = 0, max = 1, tableIdxInc = -1, table = offOn, apikey="f3c_auto"}

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
    mspapi = "ESC_PARAMETERS_YGE",
    eepromWrite = true,
    reboot = false,
    title = "Advanced Setup",
    labels = labels,
    fields = fields,
    escinfo = escinfo,
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "ESC / YGE / Advanced",
    headerLine = rfsuite.escHeaderLineText
}
