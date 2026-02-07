--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local labels = {}
local tables = {}

local activateWakeup = false

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

local function openPage(idx, title, script)

    rfsuite.app.Page = assert(loadfile("app/modules/" .. script))()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script
    rfsuite.session.lastPage = script

    local maxValue
    local minValue

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    local longPage = false

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
    local positions_r = {}
    local pos

    local line = form.addLine("")
    pos = {x = 0, y = paddingTop, w = 200, h = h}
    rfsuite.app.formFields['col_0'] = form.addStaticText(line, pos, apidata.formdata.name)

    local loc = numCols
    local posX = screenWidth - paddingRight
    local posY = paddingTop

    rfsuite.session.colWidth = w - paddingRight

    local c = 1
    while loc > 0 do
        local colLabel = rfsuite.app.Page.apidata.formdata.cols[loc]

        positions[loc] = posX - w
        positions_r[c] = posX - w

        lcd.font(FONT_STD)

        colLabel = rightAlignText(rfsuite.session.colWidth, colLabel)

        local posTxt = positions_r[c] + paddingRight

        pos = {x = posTxt, y = posY, w = w, h = h}
        rfsuite.app.formFields['col_' .. tostring(c)] = form.addStaticText(line, pos, colLabel)

        posX = math.floor(posX - w)

        loc = loc - 1
        c = c + 1
    end

    local rateRows = {}
    for ri, rv in ipairs(rfsuite.app.Page.apidata.formdata.rows) do rateRows[ri] = form.addLine(rv) end

    for i = 1, #rfsuite.app.Page.apidata.formdata.fields do
        local f = rfsuite.app.Page.apidata.formdata.fields[i]
        local l = rfsuite.app.Page.apidata.formdata.labels
        local pageIdx = i
        local currentField = i

        if f.hidden == nil or f.hidden == false then
            posX = positions[f.col]

            pos = {x = posX + padding, y = posY, w = w - padding, h = h}

            minValue = f.min * rfsuite.app.utils.decimalInc(f.decimals)
            maxValue = f.max * rfsuite.app.utils.decimalInc(f.decimals)
            if f.mult ~= nil then
                minValue = minValue * f.mult
                maxValue = maxValue * f.mult
            end
            if f.scale ~= nil then
                minValue = minValue / f.scale
                maxValue = maxValue / f.scale
            end

            rfsuite.app.formFields[i] = form.addNumberField(rateRows[f.row], pos, minValue, maxValue, function()
                local value
                if rfsuite.session.activeRateProfile == 0 then
                    value = 0
                else
                    value = rfsuite.app.utils.getFieldValue(rfsuite.app.Page.apidata.formdata.fields[i])
                end
                return value
            end, function(value) f.value = rfsuite.app.utils.saveFieldValue(rfsuite.app.Page.apidata.formdata.fields[i], value) end)
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

end

local function wakeup() if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then if rfsuite.session.activeRateProfile ~= nil then if rfsuite.app.formFields['title'] then rfsuite.app.formFields['title']:value(rfsuite.app.Page.title .. " #" .. rfsuite.session.activeRateProfile) end end end end

local function onHelpMenu()

    local helpPath = "app/modules/rates/help.lua"
    local help = assert(loadfile(helpPath))()

    rfsuite.app.ui.openPageHelp(help.help["table"][rfsuite.session.activeRateTable], "rates")

end

return {apidata = apidata, title = "@i18n(app.modules.rates.name)@", reboot = false, eepromWrite = true, refreshOnRateChange = true, rows = mytable.rows, cols = mytable.cols, flagRateChange = flagRateChange, postLoad = postLoad, openPage = openPage, wakeup = wakeup, onHelpMenu = onHelpMenu, API = {}}
