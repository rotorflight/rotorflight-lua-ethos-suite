--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local rfutils = rfsuite.utils

local RATE_TABLES = {
    [0] = "app/modules/rates/ratetables/none.lua",
    [1] = "app/modules/rates/ratetables/betaflight.lua",
    [2] = "app/modules/rates/ratetables/raceflight.lua",
    [3] = "app/modules/rates/ratetables/kiss.lua",
    [4] = "app/modules/rates/ratetables/actual.lua",
    [5] = "app/modules/rates/ratetables/quick.lua",
    [6] = "app/modules/rates/ratetables/rotorflight.lua"
}

local page = {
    title = "@i18n(app.modules.rates.name)@",
    reboot = false,
    eepromWrite = true,
    refreshOnRateChange = true,
    API = {}
}

local state = {
    title = "@i18n(app.modules.rates.name)@",
    loading = false,
    loaded = false,
    loadError = nil,
    needsRender = false,
    loadToken = 0
}

local activateWakeup = false

local function cachePolarState(polarEnabled)
    local session = rfsuite.session
    local activeRateProfile = session and session.activeRateProfile
    if activeRateProfile == nil or polarEnabled == nil then return end

    local cache = session.rateProfilePolarState
    if not cache then
        cache = {}
        session.rateProfilePolarState = cache
    end

    cache[activeRateProfile] = (polarEnabled == true)
end

local function rightAlignText(width, text)
    local textWidth, _ = lcd.getTextSize(text)
    local padding = width - textWidth

    if padding > 0 then
        return string.rep(" ", math.floor(padding / lcd.getTextSize(" "))) .. text
    end

    return text
end

local function applyFieldValues(formdata)
    local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values
    local rcTuning = values and values.RC_TUNING
    local fields = formdata and formdata.fields
    if not (rcTuning and fields) then return end

    for i = 1, #fields do
        local field = fields[i]
        local rawValue = field and field.apikey and rcTuning[field.apikey]
        if rawValue ~= nil then
            local scale = field.scale or 1
            field.value = rawValue / scale
        end
    end
end

local function loadRateTable(tableId, polarEnabled)
    local tablePath = RATE_TABLES[tableId]
    if not tablePath then
        tableId = rfsuite.config.defaultRateProfile
        tablePath = RATE_TABLES[tableId]
    end

    rfsuite.utils.log("Loading Rate Table: " .. tostring(tablePath), "debug")

    local session = rfsuite.session
    session.activeRateTable = tableId
    session.applyPolarRateLayout = true
    session.pendingPolarRateLayout = (polarEnabled == true)

    local chunk = assert(loadfile(tablePath))
    local ok, loadedTable = pcall(chunk)

    session.applyPolarRateLayout = false
    session.pendingPolarRateLayout = nil

    assert(ok, loadedTable)
    return loadedTable
end

local function renderLoading()
    form.clear()
    rfsuite.app.ui.fieldHeader(state.title)
    form.addLine("@i18n(app.msg_loading)@")
end

local function renderError()
    form.clear()
    rfsuite.app.ui.fieldHeader(state.title)
    form.addLine(tostring(state.loadError or "@i18n(app.error_timed_out)@"))
end

local function renderForm()
    local formdata = page.apidata and page.apidata.formdata
    if not formdata then
        renderError()
        return
    end

    form.clear()
    rfsuite.app.ui.fieldHeader(state.title)

    local numCols = (formdata.cols and #formdata.cols) or 3
    local screenWidth = lcd.getWindowSize()
    local padding = 10
    local paddingTop = rfsuite.app.radio.linePaddingTop
    local h = rfsuite.app.radio.navbuttonHeight
    local w = ((screenWidth * 70 / 100) / numCols)
    local paddingRight = 10
    local positions = {}
    local pos

    local line = form.addLine("")
    pos = {x = 0, y = paddingTop, w = 200, h = h}
    rfsuite.app.formFields["col_0"] = form.addStaticText(line, pos, formdata.name)

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop

    rfsuite.session.colWidth = w - paddingRight

    while loc > 0 do
        local colLabel = formdata.cols[loc]

        positions[loc] = posX - w
        lcd.font(FONT_STD)
        colLabel = rightAlignText(rfsuite.session.colWidth, colLabel)

        local posTxt = positions[loc] + paddingRight
        pos = {x = posTxt, y = posY, w = w, h = h}
        rfsuite.app.formFields["col_" .. tostring(numCols - loc + 1)] = form.addStaticText(line, pos, colLabel)

        posX = math.floor(posX - w)
        loc = loc - 1
    end

    local rateRows = {}
    for ri, rv in ipairs(formdata.rows) do
        rateRows[ri] = form.addLine(rv)
    end

    local fields = formdata.fields
    local fieldHelpTxt = rfsuite.app.ui.getFieldHelpTxt()

    for i = 1, #fields do
        local f = fields[i]
        if f.hidden ~= true then
            posX = positions[f.col]
            pos = {x = posX + padding, y = posY, w = w - padding, h = h}

            local minValue = f.min * rfutils.decimalInc(f.decimals)
            local maxValue = f.max * rfutils.decimalInc(f.decimals)
            if f.mult ~= nil then
                minValue = minValue * f.mult
                maxValue = maxValue * f.mult
            end
            if f.scale ~= nil then
                minValue = minValue / f.scale
                maxValue = maxValue / f.scale
            end

            rfsuite.app.formFields[i] = form.addNumberField(rateRows[f.row], pos, minValue, maxValue, function()
                if not fields or not fields[i] then
                    if rfsuite.app.ui then
                        rfsuite.app.ui.disableAllFields()
                        rfsuite.app.ui.disableAllNavigationFields()
                        rfsuite.app.ui.enableNavigationField("menu")
                    end
                    return nil
                end

                if rfsuite.session.activeRateProfile == 0 then
                    return 0
                end

                return rfsuite.app.utils.getFieldValue(fields[i])
            end, function(value)
                if not fields or not fields[i] then return end
                rfsuite.app.ui.markPageDirty()
                if f.postEdit then f.postEdit(page) end
                if f.onChange then f.onChange(page) end
                f.value = rfsuite.app.utils.saveFieldValue(fields[i], value)
            end)

            if f.default ~= nil then
                local default = f.default * rfutils.decimalInc(f.decimals)
                if f.mult ~= nil then default = math.floor(default * f.mult) end
                if f.scale ~= nil then default = math.floor(default / f.scale) end
                rfsuite.app.formFields[i]:default(default)
            else
                rfsuite.app.formFields[i]:default(0)
            end

            if f.decimals ~= nil then rfsuite.app.formFields[i]:decimals(f.decimals) end
            if f.unit ~= nil then rfsuite.app.formFields[i]:suffix(f.unit) end
            if f.step ~= nil then rfsuite.app.formFields[i]:step(f.step) end
            if f.help ~= nil and fieldHelpTxt and fieldHelpTxt[f.help] and fieldHelpTxt[f.help].t ~= nil then
                rfsuite.app.formFields[i]:help(fieldHelpTxt[f.help].t)
            end
            if f.disable == true then rfsuite.app.formFields[i]:enable(false) end
        end
    end

    rfsuite.app.ui.setPageDirty(false)
end

local function startLoad()
    state.loading = true
    state.loaded = false
    state.loadError = nil
    state.needsRender = true
    state.loadToken = state.loadToken + 1
    local token = state.loadToken

    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.load and rfsuite.tasks.msp.api.load("RC_TUNING")
    if not api then
        state.loading = false
        state.loadError = "@i18n(app.error_timed_out)@"
        state.needsRender = true
        rfsuite.app.triggers.closeProgressLoader = true
        return
    end

    api.setCompleteHandler(function()
        if token ~= state.loadToken then return end

        local rateType = tonumber(api.readValue("rates_type") or rfsuite.config.defaultRateProfile) or rfsuite.config.defaultRateProfile
        local polarEnabled = tonumber(api.readValue("cyclic_polarity") or 0) == 1

        cachePolarState(polarEnabled)

        page.apidata = loadRateTable(rateType, polarEnabled)
        applyFieldValues(page.apidata.formdata)

        state.loading = false
        state.loaded = true
        state.loadError = nil
        state.needsRender = true
        activateWakeup = true
        rfsuite.app.triggers.closeProgressLoader = true
    end)

    api.setErrorHandler(function()
        if token ~= state.loadToken then return end

        state.loading = false
        state.loaded = false
        state.loadError = "@i18n(app.error_timed_out)@"
        state.needsRender = true
        rfsuite.app.triggers.closeProgressLoader = true
    end)

    local ok, reason = api.read()
    if not ok then
        if token ~= state.loadToken then return end

        state.loading = false
        state.loaded = false
        state.loadError = tostring(reason or "@i18n(app.error_timed_out)@")
        state.needsRender = true
        rfsuite.app.triggers.closeProgressLoader = true
    end
end

local function openPage(opts)
    local relativeScript = opts.script
    if type(relativeScript) == "string" and relativeScript:sub(1, 12) == "app/modules/" then
        relativeScript = relativeScript:sub(13)
    end

    activateWakeup = false
    page.apidata = nil
    state.title = opts.title or page.title

    rfsuite.app.lastIdx = opts.idx
    rfsuite.app.lastTitle = state.title
    rfsuite.app.lastScript = relativeScript or opts.script
    rfsuite.session.lastPage = relativeScript or opts.script
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = true

    renderLoading()
    startLoad()
end

local function wakeup()
    if state.needsRender then
        if state.loading then
            renderLoading()
        elseif state.loadError then
            renderError()
        else
            renderForm()
        end
        state.needsRender = false
    end

    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local activeRateProfile = rfsuite.session and rfsuite.session.activeRateProfile
        if activeRateProfile ~= nil and rfsuite.app.formFields["title"] then
            local baseTitle = state.title or page.title or ""
            baseTitle = tostring(baseTitle):gsub("%s+#%d+$", "")
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeRateProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end
        activateWakeup = false
    end
end

local function onHelpMenu()
    local helpPath = "app/modules/rates/help.lua"
    local help = assert(loadfile(helpPath))()
    local activeRateTable = rfsuite.session and rfsuite.session.activeRateTable
    if activeRateTable ~= nil and help.help and help.help.table and help.help.table[activeRateTable] then
        rfsuite.app.ui.openPageHelp(help.help.table[activeRateTable])
    end
end

local function canSave()
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    if pref == false or pref == "false" then return true end
    return rfsuite.app.pageDirty == true
end

local function close()
    activateWakeup = false
    state.loadToken = state.loadToken + 1
    state.loading = false
    state.loaded = false
    state.loadError = nil
    state.needsRender = false
    page.apidata = nil
end

page.openPage = openPage
page.wakeup = wakeup
page.onHelpMenu = onHelpMenu
page.canSave = canSave
page.close = close

return page
