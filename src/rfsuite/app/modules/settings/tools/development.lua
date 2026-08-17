--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local settings = {}
local enableWakeup = false
local system = system
local DEVELOPER_MENU_SCRIPT = "developer/developer.lua"
local DEVELOPER_MENU_TITLE = "Developer"

local function openPage(opts)

    local pageIdx = opts.idx
    local title = opts.title
    local script = opts.script
    enableWakeup = true
    rfsuite.app.triggers.closeProgressLoader = true
    form.clear()

    rfsuite.app.lastIdx = pageIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader(DEVELOPER_MENU_TITLE .. " / " .. "Settings")
    rfsuite.app.formLineCnt = 0

    local formFieldCount = 0

    settings = {}
    local saved = rfsuite.preferences.developer or {}
    for k, v in pairs(saved) do settings[k] = v end


    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log level")
    rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, {{"OFF", 0}, {"INFO", 1}, {"DEBUG", 2}}, function()
        if rfsuite.preferences and rfsuite.preferences.developer then
            if settings['loglevel'] == "off" then
                return 0
            elseif settings['loglevel'] == "info" then
                return 1
            else
                return 2
            end
        end
    end, function(newValue)
        if rfsuite.preferences and rfsuite.preferences.developer then
            local value
            if newValue == 0 then
                value = "off"
            elseif newValue == 1 then
                value = "info"
            else
                value = "debug"
            end
            settings['loglevel'] = value
        end
    end)

    if system.getVersion().simulation then
        formFieldCount = formFieldCount + 1
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("SIM API Version")
        rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, rfsuite.utils.msp_version_array_to_indexed(), function() return settings.apiversion end, function(newValue) settings.apiversion = newValue end)

        formFieldCount = formFieldCount + 1
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Tail Mode")
        rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, {
            {"Variable Pitch", 0},
            {"Motorized Tail", 1}
        }, function()
            return settings.tailmode_override or 0
        end, function(newValue)
            settings.tailmode_override = newValue
        end)

        formFieldCount = formFieldCount + 1
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("ESC Telemetry Protocol")
        rfsuite.app.formFields[formFieldCount] = form.addChoiceField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, rfsuite.utils.esc_sensor_protocol_choices(), function()
            return settings.escprotocol_override or 0
        end, function(newValue)
            settings.escprotocol_override = newValue
        end)

    end

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log msp data")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['logmsp'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.logmsp = newValue end end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log MSP read/write")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['logmsprw'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.logmsprw = newValue end end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log MSP queue size")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['logmspQueue'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.logmspQueue = newValue end end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log memory usage")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['memstats'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.memstats = newValue end end)

    if system.getVersion().simulation and simulator and type(simulator.setDebug) == "function" then
        formFieldCount = formFieldCount + 1
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log Memory Allocation")
        rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function()
            if rfsuite.preferences and rfsuite.preferences.developer then return settings['debugmalloc'] end
        end, function(newValue)
            if rfsuite.preferences and rfsuite.preferences.developer then settings.debugmalloc = newValue end
        end)
    end

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log cache stats")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['logcachestats'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.logcachestats = newValue end end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log events")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['logevents'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.logevents = newValue end end)


    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log tasks speed")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['taskprofiler'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.taskprofiler = newValue end end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Log dashboard speed")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['logobjprof'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.logobjprof = newValue end end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Overlay grid in dashboard")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['overlaygrid'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.overlaygrid = newValue end end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Overlay stats in dashboard")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['overlaystats'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.overlaystats = newValue end end)

    formFieldCount = formFieldCount + 1
    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
    rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine("Overlay stats in admin")
    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(rfsuite.app.formLines[rfsuite.app.formLineCnt], nil, function() if rfsuite.preferences and rfsuite.preferences.developer then return settings['overlaystatsadmin'] end end, function(newValue) if rfsuite.preferences and rfsuite.preferences.developer then settings.overlaystatsadmin = newValue end end)

end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function onSaveMenu()

    local function doSave()
        local msg = "Save current page to radio?"
        rfsuite.app.ui.progressDisplaySave(msg:gsub("%?$", "."))
        for key in pairs(rfsuite.preferences.developer) do
            if settings[key] == nil then rfsuite.preferences.developer[key] = nil end
        end
        for key, value in pairs(settings) do rfsuite.preferences.developer[key] = value end
        rfsuite.ini.save_ini_file("SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini", rfsuite.preferences)

        if system.getVersion().simulation and simulator and type(simulator.setDebug) == "function" then
            simulator.setDebug("malloc", rfsuite.preferences.developer.debugmalloc == true)
        end

        rfsuite.app.triggers.closeSave = true
        return true
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

return {event = event, openPage = openPage, wakeup = wakeup, onNavMenu = onNavMenu, onSaveMenu = onSaveMenu, navButtons = {menu = true, save = true, reload = false, tool = false, help = false}, API = {}}
