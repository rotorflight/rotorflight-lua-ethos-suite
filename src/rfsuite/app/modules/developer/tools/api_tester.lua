--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system
local app = rfsuite.app
local tasks = rfsuite.tasks

local T = {
    NAME = "@i18n(app.modules.api_tester.name)@",
    STATUS_IDLE = "@i18n(app.modules.api_tester.status_idle)@",
    LABEL_INFO = "@i18n(app.modules.api_tester.label_info)@",
    LABEL_VALUE = "@i18n(app.modules.api_tester.label_value)@",
    LABEL_ERROR = "@i18n(app.modules.api_tester.label_error)@",
    LABEL_FIELDS = "@i18n(app.modules.api_tester.label_fields)@",
    LABEL_STATUS = "@i18n(app.modules.api_tester.label_status)@",
    LABEL_API = "@i18n(app.modules.api_tester.label_api)@",
    BTN_TEST = "@i18n(app.modules.api_tester.btn_test)@",
    PANEL_READ_RESULT = "@i18n(app.modules.api_tester.panel_read_result)@",
    MSG_CHOOSE_API = "@i18n(app.modules.api_tester.msg_choose_api)@",
    MSG_NO_DATA = "@i18n(app.modules.api_tester.msg_no_data)@",
    MSG_NO_API_SELECTED = "@i18n(app.modules.api_tester.msg_no_api_selected)@",
    MSG_NO_PARSED_RESULT = "@i18n(app.modules.api_tester.msg_no_parsed_result)@",
    MSG_READ_COMPLETED_ZERO = "@i18n(app.modules.api_tester.msg_read_completed_zero)@",
    MSG_UNABLE_TO_LOAD = "@i18n(app.modules.api_tester.msg_unable_to_load)@",
    MSG_WAITING_RESPONSE = "@i18n(app.modules.api_tester.msg_waiting_response)@",
    MSG_READ_FAILED = "@i18n(app.modules.api_tester.msg_read_failed)@",
    STATUS_LOAD_FAILED = "@i18n(app.modules.api_tester.status_load_failed)@",
    STATUS_READING = "@i18n(app.modules.api_tester.status_reading)@",
    STATUS_OK = "@i18n(app.modules.api_tester.status_ok)@",
    CHOICE_NO_API_FILES = "@i18n(app.modules.api_tester.choice_no_api_files)@"
}

local pageTitle = "Developer / " .. T.NAME
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
    status = T.STATUS_IDLE,
    rows = {{label = T.LABEL_INFO, value = T.MSG_CHOOSE_API}},
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
            if not label:match("%S") then label = T.LABEL_VALUE end
            if not value:match("%S") then value = "-" end
            rowsOut[#rowsOut + 1] = {label = label, value = value}
        end
    end
    if #rowsOut == 0 then rowsOut[1] = {label = T.LABEL_INFO, value = T.MSG_NO_DATA} end
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
        state.apiChoices = {{T.CHOICE_NO_API_FILES, 1}}
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
        rowsOut[#rowsOut + 1] = {label = T.LABEL_INFO, value = T.MSG_NO_PARSED_RESULT}
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

    if #rowsOut == 0 then rowsOut[1] = {label = T.LABEL_INFO, value = T.MSG_READ_COMPLETED_ZERO} end
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
        state.rows = {{label = T.LABEL_INFO, value = T.MSG_NO_API_SELECTED}}
        setStatus(T.MSG_NO_API_SELECTED)
        return
    end

    local api = tasks.msp.api.load(apiName)
    if not api then
        state.rows = {{label = T.LABEL_ERROR, value = T.MSG_UNABLE_TO_LOAD .. ": " .. apiName}}
        setStatus(T.STATUS_LOAD_FAILED)
        return
    end

    state.rows = {{label = T.LABEL_STATUS, value = T.MSG_WAITING_RESPONSE}}
    state.fieldCount = 0
    setStatus(T.STATUS_READING .. " " .. apiName .. "...")

    api.setCompleteHandler(function()
        parseReadResult(api)
        setStatus(T.STATUS_OK .. ": " .. tostring(state.fieldCount) .. " " .. T.LABEL_FIELDS)
        state.autoOpenResults = true
        state.pendingRebuild = true
    end)

    api.setErrorHandler(function(_, err)
        state.rows = {
            {label = T.LABEL_STATUS, value = T.MSG_READ_FAILED},
            {label = T.LABEL_ERROR, value = tostring(err or "read_error")}
        }
        state.fieldCount = 0
        setStatus(T.LABEL_ERROR)
        state.autoOpenResults = true
        state.pendingRebuild = true
    end)

    local ok, reason = api.read()
    if ok == false then
        state.rows = {
            {label = T.LABEL_STATUS, value = T.MSG_READ_FAILED},
            {label = T.LABEL_ERROR, value = tostring(reason or "read_not_supported")}
        }
        state.fieldCount = 0
        setStatus(T.LABEL_ERROR)
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

    line.api = form.addLine(T.LABEL_API)
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
        text = T.BTN_TEST,
        icon = nil,
        options = FONT_S,
        press = runTest
    })

    line.status = form.addLine(T.LABEL_STATUS)
    fields.status = form.addStaticText(line.status, nil, state.status)

    resultsPanel = form.addExpansionPanel(T.PANEL_READ_RESULT)
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
    app.ui.openPage({idx = app.lastIdx, title = "Developer", script = "developer/developer.lua"})
end

local function event(widget, category, value)
    if (category == EVT_CLOSE and value == 0) or value == 35 then
        onNavMenu()
        return true
    end
end

local function wakeup()
    if state.pendingRebuild and app.lastScript == "developer/tools/api_tester.lua" and lastOpenOpts then
        state.pendingRebuild = false
        openPage(lastOpenOpts)
    end
end

return {
    openPage = openPage,
    wakeup = wakeup,
    event = event,
    onNavMenu = onNavMenu,
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    API = {}
}
