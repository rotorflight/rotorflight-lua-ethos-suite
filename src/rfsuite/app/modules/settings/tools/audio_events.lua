--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local config = {}
local enableWakeup = false

local function setFieldEnabled(field, enabled) if field and field.enable then field:enable(enabled) end end

local function openPage(opts)

    local pageIdx = opts.idx
    local title = opts.title
    local script = opts.script
    enableWakeup = true
    if not rfsuite.app.navButtons then rfsuite.app.navButtons = {} end
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx = pageIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader("Settings" .. " / " .. "Audio" .. " / " .. "Events")
    rfsuite.app.formLineCnt = 0

    local formFieldCount = 0

    local app = rfsuite.app
    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end

    local savedEvents = rfsuite.preferences.events or {}
    for k, v in pairs(savedEvents) do config[k] = v end

    local escFields, becFields, fuelFields = {}, {}, {}

    local armEnabled = config.armflags == true
    local armPanel = form.addExpansionPanel("Arming Flags")
    armPanel:open(armEnabled)
    local armLine = armPanel:addLine("Arming Flags")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(armLine, nil, function() return config.armflags end, function(val) config.armflags = val end)

    local govEnabled = config.governor == true
    local govPanel = form.addExpansionPanel("Governor State")
    govPanel:open(govEnabled)
    local govLine = govPanel:addLine("Governor State")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(govLine, nil, function() return config.governor end, function(val) config.governor = val end)

    local voltEnabled = config.voltage == true
    local voltPanel = form.addExpansionPanel("Voltage")
    voltPanel:open(voltEnabled)
    local voltLine = voltPanel:addLine("Voltage")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(voltLine, nil, function() return config.voltage end, function(val) config.voltage = val end)

    local ratesEnabled = (config.pid_profile == true) or (config.rate_profile == true)
    local ratesPanel = form.addExpansionPanel("PID/Rates Profile")
    ratesPanel:open(ratesEnabled)
    local pidLine = ratesPanel:addLine("PID Profile")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(pidLine, nil, function() return config.pid_profile end, function(val) config.pid_profile = val end)
    local rateLine = ratesPanel:addLine("Rate Profile")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rateLine, nil, function() return config.rate_profile end, function(val) config.rate_profile = val end)

    local escEnabled = config.temp_esc == true
    local escPanel = form.addExpansionPanel("ESC Temperature")
    escPanel:open(escEnabled)
    local escEnable = escPanel:addLine("ESC Temperature")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    escFields.enable = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(escEnable, nil, function() return config.temp_esc end, function(val)
        config.temp_esc = val
        setFieldEnabled(rfsuite.app.formFields[escFields.thresh], val)
    end)
    local escThresh = escPanel:addLine("Threshold (Ã‚Â°)")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    escFields.thresh = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(escThresh, nil, 60, 300, function() return config.escalertvalue or 90 end, function(val) config.escalertvalue = val end, 1)
    rfsuite.app.formFields[formFieldCount]:suffix("°")
    setFieldEnabled(rfsuite.app.formFields[escFields.thresh], escEnabled)

    local adjEnabled = (config.adj_f == true) or (config.adj_v == true)
    local adjPanel = form.addExpansionPanel("Adjustment Callouts")
    adjPanel:open(adjEnabled)

    local adjFuncLine = adjPanel:addLine("Adjustment Function")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(adjFuncLine, nil, function() return config.adj_f == true end, function(val) config.adj_f = val end)

    local adjValueLine = adjPanel:addLine("Adjustment Value")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(adjValueLine, nil, function() return config.adj_v == true end, function(val) config.adj_v = val end)

    local fuelEnabled = config.smartfuel == true
    local fuelPanel = form.addExpansionPanel("Fuel")
    fuelPanel:open(fuelEnabled)
    local fuelEnable = fuelPanel:addLine("Fuel")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    fuelFields.enable = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(fuelEnable, nil, function() return config.smartfuel end, function(val)
        config.smartfuel = val
        setFieldEnabled(rfsuite.app.formFields[fuelFields.callout], val)
        setFieldEnabled(rfsuite.app.formFields[fuelFields.repeats], val)
        setFieldEnabled(rfsuite.app.formFields[fuelFields.haptic], val)
    end)
    local calloutChoices = {{"Default (Only at 10%)", 0}, {"50% and 5%", 5}, {"Every 10%", 10}, {"Every 20%", 20}, {"Every 25%", 25}, {"Every 50%", 50}}
    local fuelThresh = fuelPanel:addLine("Callout %")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    fuelFields.callout = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(fuelThresh, nil, calloutChoices, function()
        local v = config.smartfuelcallout
        if v == nil or v == false then return 10 end
        return v
    end, function(val) config.smartfuelcallout = val end)
    setFieldEnabled(rfsuite.app.formFields[fuelFields.callout], fuelEnabled)

    local fuelRepeats = fuelPanel:addLine("Repeats below 0%")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    fuelFields.repeats = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addNumberField(fuelRepeats, nil, 1, 10, function() return config.smartfuelrepeats or 1 end, function(val) config.smartfuelrepeats = val end, 1)
    rfsuite.app.formFields[formFieldCount]:suffix("x")
    setFieldEnabled(rfsuite.app.formFields[fuelFields.repeats], fuelEnabled)

    local fuelHaptic = fuelPanel:addLine("Haptic below 0%")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    fuelFields.haptic = formFieldCount
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(fuelHaptic, nil, function() return config.smartfuelhaptic == true end, function(val) config.smartfuelhaptic = val end)
    setFieldEnabled(rfsuite.app.formFields[fuelFields.haptic], fuelEnabled)

    setFieldEnabled(rfsuite.app.formFields[escFields.enable], true)
    setFieldEnabled(rfsuite.app.formFields[becFields.enable], true)
    setFieldEnabled(rfsuite.app.formFields[fuelFields.enable], true)

    local batteryProfileEnabled = config.battery_profile == true
    local batteryPanel = form.addExpansionPanel("Battery")
    batteryPanel:open(batteryProfileEnabled)
    local batteryLine = batteryPanel:addLine("Battery capacity")
    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(batteryLine, nil, function() return config.battery_profile end, function(val)
        config.battery_profile = val
    end)

    local otherEnabled = config.otherSoundCfg == true
    local otherPanel = form.addExpansionPanel("Other")
    otherPanel:open(otherEnabled)

    local w = rfsuite.app.lcdWidth
    local otherModelAnnouncement = otherPanel:addLine("Model announcement")

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(otherModelAnnouncement, nil, function() return config.otherModelAnnounce == true end, function(val) config.otherModelAnnounce = val end)
    if rfsuite.app.formFields[formFieldCount].help then
        rfsuite.app.formFields[formFieldCount]:help("Model announcement requires a .wav file in the 'audio' folder matching the model name (e.g. 'racer.wav' for model 'racer').")
    end

    rfsuite.app.navButtons.save = true
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function onSaveMenu()

    local function doSave()
        local msg = "Save current page to radio?"
        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
        for key, value in pairs(config) do rfsuite.preferences.events[key] = value end
        rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)
        rfsuite.app.triggers.closeSave = true
    end

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        doSave()
        return
    end 

    local buttons = {
        {
            label = "                OK                ",
            action = function()
                doSave()
                return true
            end
        }, {label = "CANCEL", action = function() return true end}
    }

    form.openDialog({width = nil, title = "Save settings", message = "Save current page to radio?", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

local function onHelpMenu()

    local helpPath = "app/modules/settings/tools/help.lua"
    local help = assert(loadfile(helpPath))()

    rfsuite.app.ui.openPageHelp(help.help["audio_events"], "Settings" .. " / " .. "Audio" .. " / " .. "Events")

end

return {event = event, openPage = openPage, onNavMenu = onNavMenu, onSaveMenu = onSaveMenu,  onHelpMenu = onHelpMenu, navButtons = {menu = true, save = true, reload = false, tool = false, help = true}, API = {}}
