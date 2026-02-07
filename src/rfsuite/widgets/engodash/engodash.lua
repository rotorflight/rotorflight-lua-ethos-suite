--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


--[[
    -- display seems to be 100x100?

    -- docs
    https://github.com/ActiveLook/Activelook-Visual-Assets

    preflight.governor = glasses.createLayout({bitmap={id=10, x=10, y=10}, text={x=10, y=100}, border=false})



]]--

local rfsuite = require("rfsuite")

local engodash = {}

local context = {
    preflight = {},
    inflight = {},
    postflight = {},
}

local sensors = {}
local lastMode = nil
local lastWakeup = 0
local WAKEUP_INTERVAL = 0.5

local function createIconTextLayout(iconId, iconX, iconY, textX, textY)
    return glasses.createLayout({bitmap = {id = iconId, x = iconX, y = iconY}, text = {x = textX, y = textY}, border = false})
end

local function createTextLayout(textX, textY)
    return glasses.createLayout({text = {x = textX, y = textY}, border = false})
end

local function layoutSet(layout, text)
    if glasses.layoutClear then
        glasses.layoutClear(layout)
        if glasses.layoutDisplay then
            glasses.layoutDisplay(layout, text or "")
            return
        end
    end
    glasses.layoutClearAndDisplay(layout, text or "")
end

local function buildTheme(theme)
    theme.governor = createIconTextLayout(14, 1, 1, 30, 1)
    theme.fuel = createIconTextLayout(10, 1, 50, 30, 52)
    theme.voltage = createIconTextLayout(2, 1, 100, 30, 100)
    theme.rpm = createIconTextLayout(2, 1, 150, 30, 150)

    -- text does not like spaces, split labels + values into separate layouts
    theme.profileLabel = createIconTextLayout(2, 1, 200, 30, 200)
    theme.profileValue = createTextLayout(120, 200)
    theme.rateLabel = createIconTextLayout(2, 150, 200, 180, 200)
    theme.rateValue = createTextLayout(270, 200)
end

local function clearTheme(theme)
    if not theme then return end
    for _, layout in pairs(theme) do
        layoutSet(layout, "")
    end
end

local function displayTheme(theme, data)
    if not theme or not data then return end
    layoutSet(theme.governor, data.governor)
    layoutSet(theme.fuel, data.fuel)
    layoutSet(theme.voltage, data.voltage)
    layoutSet(theme.rpm, data.rpm)
    layoutSet(theme.profileLabel, data.profileLabel)
    layoutSet(theme.profileValue, data.profileValue)
    layoutSet(theme.rateLabel, data.rateLabel)
    layoutSet(theme.rateValue, data.rateValue)
end

local function sanitizeText(value)
    if value == nil then return "-" end
    if type(value) ~= "string" then value = tostring(value) end
    return value:gsub("%s+", "")
end

local function formatValue(value, decimals, suffix)
    if value == nil then return "-" end
    if type(value) == "number" then
        if decimals and decimals > 0 then
            value = rfsuite.utils.round(value, decimals)
        else
            value = math.floor(value + 0.5)
        end
    end
    local text = sanitizeText(value)
    if text == "-" then return text end
    if suffix and suffix ~= "" then text = text .. suffix end
    return text
end

function engodash.create()
    return {}
end

function engodash.build()

    local preflight = context.preflight
    local inflight = context.inflight
    local postflight = context.postflight

    buildTheme(preflight)
    buildTheme(inflight)
    buildTheme(postflight)


end

function engodash.wakeup()

    local preflight = context.preflight
    local inflight = context.inflight
    local postflight = context.postflight

    local mode = (rfsuite.flightmode and rfsuite.flightmode.current) or "preflight"
    local now = os.clock()
    if mode == lastMode and (now - lastWakeup) < WAKEUP_INTERVAL then return end
    lastWakeup = now

    local telemetry = rfsuite.tasks and rfsuite.tasks.telemetry
    local getSensor = telemetry and telemetry.getSensor

    local governorRaw = getSensor and getSensor("governor") or nil
    local governorText = rfsuite.utils.getGovernorState(governorRaw)
    local fuel = (getSensor and getSensor("smartfuel")) or (getSensor and getSensor("fuel"))
    local voltage = getSensor and getSensor("voltage") or nil
    local rpm = getSensor and getSensor("rpm") or nil
    local pidProfile = getSensor and getSensor("pid_profile") or nil
    local rateProfile = getSensor and getSensor("rate_profile") or nil

    local data = sensors
    data.preflight = data.preflight or {}
    data.inflight = data.inflight or {}
    data.postflight = data.postflight or {}

    local current = data[mode] or data.preflight
    current.governor = sanitizeText(governorText)
    current.voltage = formatValue(voltage, 1, "")
    current.fuel = formatValue(fuel, 0, "%")
    current.rpm = formatValue(rpm, 0, "rpm")
    current.profileLabel = "PROFILE"
    current.profileValue = formatValue(pidProfile, 0, "")
    current.rateLabel = "RATES"
    current.rateValue = formatValue(rateProfile, 0, "")

    if mode ~= lastMode then
        clearTheme(context[lastMode])
        lastMode = mode
    end

    local theme = context[mode] or preflight
    local themeData = data[mode] or data.preflight
    displayTheme(theme, themeData)

end


return engodash
