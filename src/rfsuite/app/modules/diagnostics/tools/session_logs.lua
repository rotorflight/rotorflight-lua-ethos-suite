--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local os_clock = os.clock
local app = rfsuite.app
local tasks = rfsuite.tasks

local PAGE_TITLE = "@i18n(app.modules.diagnostics.name)@ / Session Logs"
local EMPTY_TEXT = "No session log entries"
local MAX_LINES = 80
local REFRESH_INTERVAL = 0.25
local DISPLAY_MAX_CHARS = 120

local logLines = {}
local displayedLines = {}
local lineFields = {}
local lastSeq = -1
local lastRefresh = 0
local enableWakeup = false

local function trimDisplayText(text)
    text = tostring(text or "")
    if #text <= DISPLAY_MAX_CHARS then return text end
    return text:sub(1, DISPLAY_MAX_CHARS - 3) .. "..."
end

local function getLogger()
    return tasks and tasks.logger or nil
end

local function refreshLines(force)
    local logger = getLogger()
    local seq = logger and logger.getSessionSeq and logger.getSessionSeq() or 0
    if not force and seq == lastSeq then return end

    lastSeq = seq

    if logger and logger.getSessionLines then
        logger.getSessionLines(MAX_LINES, nil, logLines)
    else
        for i = #logLines, 1, -1 do logLines[i] = nil end
    end

    if #logLines == 0 then
        logLines[1] = EMPTY_TEXT
    end

    for i = 1, MAX_LINES do
        local value = trimDisplayText(logLines[i] or "")
        if displayedLines[i] ~= value then
            displayedLines[i] = value
            local field = lineFields[i]
            if field and field.value then field:value(value) end
        end
    end
end

local function openPage(opts)
    enableWakeup = false
    if app.triggers then app.triggers.closeProgressLoader = true end

    form.clear()

    app.lastIdx = opts.idx
    app.lastTitle = opts.title
    app.lastScript = opts.script

    app.ui.fieldHeader(PAGE_TITLE)

    app.formLineCnt = 0

    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end
    for i = #displayedLines, 1, -1 do displayedLines[i] = nil end
    for i = #lineFields, 1, -1 do lineFields[i] = nil end

    local posText = {
        x = 0,
        y = app.radio.linePaddingTop,
        w = app.lcdWidth,
        h = app.radio.navbuttonHeight
    }

    for i = 1, MAX_LINES do
        app.formLineCnt = app.formLineCnt + 1
        app.formLines[app.formLineCnt] = form.addLine("", nil, false)
        lineFields[i] = form.addStaticText(app.formLines[app.formLineCnt], posText, "")
    end

    refreshLines(true)
    enableWakeup = true
end

local function wakeup()
    if not enableWakeup then return end

    local now = os_clock()
    if now - lastRefresh < REFRESH_INTERVAL then return end
    lastRefresh = now

    refreshLines(false)
end

local function close()
    enableWakeup = false
    for i = #logLines, 1, -1 do logLines[i] = nil end
    for i = #displayedLines, 1, -1 do displayedLines[i] = nil end
    for i = #lineFields, 1, -1 do lineFields[i] = nil end
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

return {
    apidata = {api = {}, formdata = {labels = {}, fields = {}}},
    reboot = false,
    eepromWrite = false,
    minBytes = 0,
    wakeup = wakeup,
    refreshswitch = false,
    simulatorResponse = {},
    openPage = openPage,
    close = close,
    onNavMenu = onNavMenu,
    event = event,
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    API = {}
}
