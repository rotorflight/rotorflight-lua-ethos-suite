--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local tables = {}

local activateWakeup = false

local function resolveScriptPath(script)
    if type(script) ~= "string" then return nil, nil end
    local relativeScript = script
    if relativeScript:sub(1, 12) == "app/modules/" then
        relativeScript = relativeScript:sub(13)
    end
    local modulePath = script
    if modulePath:sub(1, 4) ~= "app/" then
        modulePath = "app/modules/" .. modulePath
    end
    return modulePath, relativeScript
end

tables[0] = "app/modules/rates/ratetables/none.lua"
tables[1] = "app/modules/rates/ratetables/betaflight.lua"
tables[2] = "app/modules/rates/ratetables/raceflight.lua"
tables[3] = "app/modules/rates/ratetables/kiss.lua"
tables[4] = "app/modules/rates/ratetables/actual.lua"
tables[5] = "app/modules/rates/ratetables/quick.lua"
tables[6] = "app/modules/rates/ratetables/rotorflight.lua"

if rfsuite.session.activeRateTable == nil then rfsuite.session.activeRateTable = rfsuite.config.defaultRateProfile end

rfsuite.utils.log("Loading Rate Table: " .. tables[rfsuite.session.activeRateTable], "debug")
local apidata = assert(loadfile(tables[rfsuite.session.activeRateTable]))()
local mytable = apidata.formdata

local function postLoad(self)

    local v = rfsuite.tasks.msp.api.apidata.values[apidata.api[1]].rates_type

    rfsuite.utils.log("Active Rate Table: " .. rfsuite.session.activeRateTable, "debug")

    if v ~= rfsuite.session.activeRateTable then
        rfsuite.utils.log("Switching Rate Table: " .. v, "info")
        rfsuite.app.triggers.reloadFull = true
        rfsuite.session.activeRateTable = v
        return
    end

    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true

end

local function rightAlignText(width, text)
    local textWidth, _ = lcd.getTextSize(text)
    local padding = width - textWidth

    if padding > 0 then
        return string.rep(" ", math.floor(padding / lcd.getTextSize(" "))) .. text
    else
        return text
    end
end

local function openPage(opts)

    local idx = opts.idx
    local title = opts.title
    local script = opts.script

    local modulePath, relativeScript = resolveScriptPath(script)
    rfsuite.app.Page = assert(loadfile(modulePath))()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = relativeScript or script
    rfsuite.session.lastPage = relativeScript or script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    form.clear()

    rfsuite.app.ui.fieldHeader(title)

    local numCols
    if rfsuite.app.Page.apidata.formdata.cols ~= nil then
        numCols = #rfsuite.app.Page.apidata.formdata.cols
    else
        numCols = 3
    end

    local screenWidth, screenHeight = lcd.getWindowSize()

    local padding = 10
    local paddingTop = rfsuite.app.radio.linePaddingTop
    local h = rfsuite.app.radio.navbuttonHeight
    local w = ((screenWidth * 70 / 100) / numCols)
    local paddingRight = 10
    local positions = {}
    local pos

    local line = form.addLine("")
    pos = {x = 0, y = paddingTop, w = 200, h = h}
    rfsuite.app.formFields['col_0'] = form.addStaticText(line, pos, apidata.formdata.name)

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop

    rfsuite.session.colWidth = w - paddingRight

    while loc > 0 do
        local colLabel = rfsuite.app.Page.apidata.formdata.cols[loc]

        positions[loc] = posX - w

        lcd.font(FONT_STD)

        colLabel = rightAlignText(rfsuite.session.colWidth, colLabel)

        local posTxt = positions[loc] + paddingRight

        pos = {x = posTxt, y = posY, w = w, h = h}
        rfsuite.app.formFields['col_' .. tostring(numCols - loc + 1)] = form.addStaticText(line, pos, colLabel)

        posX = math.floor(posX - w)

        loc = loc - 1
    end

    local rateRows = {}
    for ri, rv in ipairs(rfsuite.app.Page.apidata.formdata.rows) do rateRows[ri] = form.addLine(rv) end

    local page = rfsuite.app.Page
    local fields = page.apidata.formdata.fields

    for i = 1, #fields do
        local f = fields[i]

        if f.hidden == nil or f.hidden == false then
            posX = positions[f.col]

            pos = {x = posX + padding, y = posY, w = w - padding, h = h}

            local minValue = f.min * rfsuite.app.utils.decimalInc(f.decimals)
            local maxValue = f.max * rfsuite.app.utils.decimalInc(f.decimals)
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
                        rfsuite.app.ui.enableNavigationField('menu')
                    end
                    return nil
                end
                local value
                if rfsuite.session.activeRateProfile == 0 then
                    value = 0
                else
                    value = rfsuite.app.utils.getFieldValue(fields[i])
                end
                return value
            end, function(value)
                if not fields or not fields[i] then return end
                rfsuite.app.ui.markPageDirty()
                if f.postEdit and page then f.postEdit(page) end
                if f.onChange and page then f.onChange(page) end
                f.value = rfsuite.app.utils.saveFieldValue(fields[i], value)
            end)
            if f.default ~= nil then
                local default = f.default * rfsuite.app.utils.decimalInc(f.decimals)
                if f.mult ~= nil then default = math.floor(default * f.mult) end
                if f.scale ~= nil then default = math.floor(default / f.scale) end
                rfsuite.app.formFields[i]:default(default)
            else
                rfsuite.app.formFields[i]:default(0)
            end
            if f.decimals ~= nil then rfsuite.app.formFields[i]:decimals(f.decimals) end
            if f.unit ~= nil then rfsuite.app.formFields[i]:suffix(f.unit) end
            if f.step ~= nil then rfsuite.app.formFields[i]:step(f.step) end
            if f.help ~= nil then
                if rfsuite.app.fieldHelpTxt[f.help]['t'] ~= nil then
                    local helpTxt = rfsuite.app.fieldHelpTxt[f.help]['t']
                    rfsuite.app.formFields[i]:help(helpTxt)
                end
            end
            if f.disable == true then rfsuite.app.formFields[i]:enable(false) end
        end
    end

    rfsuite.app.ui.setPageDirty(false)
end

local function wakeup()
    if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local activeRateProfile = rfsuite.session and rfsuite.session.activeRateProfile
        if activeRateProfile ~= nil and rfsuite.app.formFields['title'] then
            local baseTitle = rfsuite.app.lastTitle or (rfsuite.app.Page and rfsuite.app.Page.title) or ""
            baseTitle = tostring(baseTitle):gsub("%s+#%d+$", "")
            rfsuite.app.ui.setHeaderTitle(baseTitle .. " #" .. activeRateProfile, nil, rfsuite.app.Page and rfsuite.app.Page.navButtons)
        end
    end
end

local function onHelpMenu()

    local helpPath = "app/modules/rates/help.lua"
    local help = assert(loadfile(helpPath))()
    rfsuite.app.ui.openPageHelp(help.help["table"][rfsuite.session.activeRateTable])

end

local function canSave()
    local pref = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.save_dirty_only
    if pref == false or pref == "false" then return true end
    return rfsuite.app.pageDirty == true
end

return {apidata = apidata, title = "@i18n(app.modules.rates.name)@", reboot = false, eepromWrite = true, refreshOnRateChange = true, rows = mytable.rows, cols = mytable.cols, flagRateChange = flagRateChange, postLoad = postLoad, openPage = openPage, wakeup = wakeup, onHelpMenu = onHelpMenu, canSave = canSave, API = {}}
