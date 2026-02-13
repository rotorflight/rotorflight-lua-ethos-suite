--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system
local app = rfsuite.app
local tasks = rfsuite.tasks

local pageTitle = "@i18n(app.modules.diagnostics.name)@ / API Tester"
local apiDir = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/"
local MAX_LINE_CHARS = 90
local lastOpenOpts = nil
local excludedApis = {
    EEPROM_WRITE = true
}

local state = {
    apiNames = {},
    apiChoices = {},
    selected = 1,
    status = "Idle",
    rows = {{label = "Info", value = "Choose an API and press Test"}},
    fieldCount = 0,
    pendingRebuild = false,
    autoOpenResults = false
}

local line = {}
local fields = {}
local resultsPanel = nil

local function sortAsc(a, b) return a < b end

local function truncateText(text)
    text = tostring(text or ""):gsub("[%c]+", " ")
    if #text > MAX_LINE_CHARS then return text:sub(1, MAX_LINE_CHARS - 3) .. "..." end
    return text
end

local function getDisplayRows()
    local rowsOut = {}
    for i = 1, #state.rows do
        local row = state.rows[i] or {}
        local label = truncateText(row.label or "")
        local value = truncateText(row.value or "")
        if label:match("%S") or value:match("%S") then
            if not label:match("%S") then label = "Value" end
            if not value:match("%S") then value = "-" end
            rowsOut[#rowsOut + 1] = {label = label, value = value}
        end
    end
    if #rowsOut == 0 then rowsOut[1] = {label = "Info", value = "No data"} end
    return rowsOut
end

local function setStatus(text)
    state.status = text
    if fields.status and fields.status.value then fields.status:value(text) end
    lcd.invalidate()
end

local function fileToApiName(filename)
    if type(filename) ~= "string" then return nil end
    if not filename:match("%.lua$") then return nil end
    local name = filename:gsub("%.lua$", "")
    if name == "" or name == "api_template" then return nil end
    if excludedApis[name] then return nil end
    return name
end

local function buildApiList()
    local names = {}
    local files = system.listFiles(apiDir) or {}
    for _, filename in ipairs(files) do
        local name = fileToApiName(filename)
        if name then names[#names + 1] = name end
    end
    table.sort(names, sortAsc)

    state.apiNames = names
    state.apiChoices = {}
    for i, name in ipairs(names) do
        state.apiChoices[#state.apiChoices + 1] = {name, i}
    end

    if #state.apiChoices == 0 then
        state.apiChoices = {{"<no api files found>", 1}}
        state.selected = 1
    elseif state.selected < 1 or state.selected > #state.apiChoices then
        state.selected = 1
    end
end

local function toValueString(v)
    local t = type(v)
    if t == "nil" then return "nil" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "table" then return "<table>" end
    return tostring(v)
end

local function parseReadResult(api)
    local result = api and api.data and api.data() or nil
    local parsed = result and result.parsed or nil
    local rowsOut = {}

    if not parsed then
        rowsOut[#rowsOut + 1] = {label = "Info", value = "No parsed result"}
        state.rows = rowsOut
        state.fieldCount = 0
        return
    end

    local keys = {}
    for k in pairs(parsed) do keys[#keys + 1] = k end
    table.sort(keys, sortAsc)

    for _, key in ipairs(keys) do
        rowsOut[#rowsOut + 1] = {label = key, value = toValueString(parsed[key])}
    end

    if #rowsOut == 0 then rowsOut[1] = {label = "Info", value = "Read completed (0 fields)"} end
    state.rows = rowsOut
    state.fieldCount = #keys
end

local function selectedApiName()
    local idx = tonumber(state.selected) or 1
    return state.apiNames[idx]
end

local function runTest()
    local apiName = selectedApiName()
    if not apiName then
        state.rows = {{label = "Info", value = "No API selected"}}
        setStatus("No API selected")
        return
    end

    local api = tasks.msp.api.load(apiName)
    if not api then
        state.rows = {{label = "Error", value = "Unable to load API: " .. apiName}}
        setStatus("Load failed")
        return
    end

    state.rows = {{label = "Status", value = "Waiting for response..."}}
    state.fieldCount = 0
    setStatus("Reading " .. apiName .. "...")

    api.setCompleteHandler(function()
        parseReadResult(api)
        setStatus("OK: " .. tostring(state.fieldCount) .. " fields")
        state.autoOpenResults = true
        state.pendingRebuild = true
    end)

    api.setErrorHandler(function(_, err)
        state.rows = {
            {label = "Status", value = "Read failed"},
            {label = "Error", value = tostring(err or "read_error")}
        }
        state.fieldCount = 0
        setStatus("Error")
        state.autoOpenResults = true
        state.pendingRebuild = true
    end)

    local ok, reason = api.read()
    if ok == false then
        state.rows = {
            {label = "Status", value = "Read failed"},
            {label = "Error", value = tostring(reason or "read_not_supported")}
        }
        state.fieldCount = 0
        setStatus("Error")
        state.autoOpenResults = true
        state.pendingRebuild = true
    end
end

local function openPage(opts)
    lastOpenOpts = opts
    app.lastIdx = opts.idx
    app.lastTitle = opts.title
    app.lastScript = opts.script

    buildApiList()

    form.clear()
    app.ui.fieldHeader(pageTitle)

    local w = lcd.getWindowSize()

    line.api = form.addLine("API")
    local rowY = app.radio.linePaddingTop
    local testW = 80
    local gap = 6
    local choiceW = w - 20 - testW - gap
    if choiceW < 100 then choiceW = 100 end

    fields.api = form.addChoiceField(line.api, {x = 0, y = rowY, w = choiceW, h = app.radio.navbuttonHeight}, state.apiChoices, function()
        return state.selected
    end, function(newValue)
        state.selected = newValue
    end)

    fields.test = form.addButton(line.api, {x = choiceW + gap, y = rowY, w = testW, h = app.radio.navbuttonHeight}, {
        text = "Test",
        icon = nil,
        options = FONT_S,
        press = runTest
    })

    line.status = form.addLine("Status")
    fields.status = form.addStaticText(line.status, nil, state.status)

    resultsPanel = form.addExpansionPanel("Read Result")
    resultsPanel:open(state.autoOpenResults)
    state.autoOpenResults = false

    local displayRows = getDisplayRows()
    for i = 1, #displayRows do
        local l = resultsPanel:addLine(displayRows[i].label)
        form.addStaticText(l, nil, displayRows[i].value)
    end

    app.triggers.closeProgressLoader = true
end

local function onNavMenu()
    app.ui.openPage({idx = app.lastIdx, title = "@i18n(app.modules.diagnostics.name)@", script = "diagnostics/diagnostics.lua"})
end

local function event(widget, category, value)
    if (category == EVT_CLOSE and value == 0) or value == 35 then
        onNavMenu()
        return true
    end
end

local function wakeup()
    if state.pendingRebuild and app.lastScript == "diagnostics/tools/api_tester.lua" and lastOpenOpts then
        state.pendingRebuild = false
        openPage(lastOpenOpts)
    end
end

return {
    openPage = openPage,
    wakeup = wakeup,
    event = event,
    onNavMenu = onNavMenu,
    navButtons = {menu = true, save = true, reload = false, tool = false, help = true},
    API = {}
}
