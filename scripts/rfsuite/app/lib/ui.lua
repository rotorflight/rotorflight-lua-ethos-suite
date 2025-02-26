--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local ui = {}

local arg = {...}
local config = arg[1]

function ui.progressDisplay(title, message)
    if rfsuite.app.dialogs.progressDisplay then return end

    rfsuite.app.audio.playLoading = true

    title = title or "Loading"
    message = message or "Loading data from flight controller..."

    rfsuite.app.dialogs.progressDisplay = true
    rfsuite.app.dialogs.progressWatchDog = os.clock()
    rfsuite.app.dialogs.progress = form.openProgressDialog(title, message)
    rfsuite.app.dialogs.progressCounter = 0

    local progress = rfsuite.app.dialogs.progress
    if progress then
        progress:value(0)
        progress:closeAllowed(false)
    end
end

function ui.progressNolinkDisplay()
    rfsuite.app.dialogs.nolinkDisplay = true
    rfsuite.app.dialogs.noLink = form.openProgressDialog("Connecting", "Connecting...")
    rfsuite.app.dialogs.noLink:closeAllowed(false)
    rfsuite.app.dialogs.noLink:value(0)
end

function ui.progressDisplaySave()
    rfsuite.app.dialogs.saveDisplay = true
    rfsuite.app.dialogs.saveWatchDog = os.clock()
    rfsuite.app.dialogs.save = form.openProgressDialog("Saving", "Saving data...")
    rfsuite.app.dialogs.save:value(0)
    rfsuite.app.dialogs.save:closeAllowed(false)
end

-- we wrap a simple rate limiter into this to prevent cpu overload when handling msp
function ui.progressDisplayValue(value, message)
    if value >= 100 then
        rfsuite.app.dialogs.progress:value(value)
        if message then rfsuite.app.dialogs.progress:message(message) end
        return
    end

    local now = os.clock()
    if (now - rfsuite.app.dialogs.progressRateLimit) >= rfsuite.app.dialogs.progressRate then
        rfsuite.app.dialogs.progressRateLimit = now
        rfsuite.app.dialogs.progress:value(value)
        if message then rfsuite.app.dialogs.progress:message(message) end
    end
end

-- we wrap a simple rate limiter into this to prevent cpu overload when handling msp
function ui.progressDisplaySaveValue(value, message)
    if value >= 100 then
        rfsuite.app.dialogs.save:value(value)
        if message then rfsuite.app.dialogs.save:message(message) end
        return
    end

    local now = os.clock()
    if (now - rfsuite.app.dialogs.saveRateLimit) >= rfsuite.app.dialogs.saveRate then
        rfsuite.app.dialogs.saveRateLimit = now
        rfsuite.app.dialogs.save:value(value)
        if message then rfsuite.app.dialogs.save:message(message) end
    end
end

function ui.progressDisplayClose()
    local progress = rfsuite.app.dialogs.progress
    if progress then
        progress:close()
        rfsuite.app.dialogs.progressDisplay = false
    end
end

function ui.progressDisplayCloseAllowed(status)
    local progress = rfsuite.app.dialogs.progress
    if progress then
        progress:closeAllowed(status)
    end
end

function ui.progressDisplayMessage(message)
    local progress = rfsuite.app.dialogs.progress
    if progress then
        progress:message(message)
    end
end

function ui.progressDisplaySaveClose()
    local saveDialog = rfsuite.app.dialogs.save
    if saveDialog then saveDialog:close() end
    rfsuite.app.dialogs.saveDisplay = false
end

function ui.progressDisplaySaveMessage(message)
    local saveDialog = rfsuite.app.dialogs.save
    if saveDialog then saveDialog:message(message) end
end

function ui.progressDisplaySaveCloseAllowed(status)
    local saveDialog = rfsuite.app.dialogs.save
    if saveDialog then saveDialog:closeAllowed(status) end
end

function ui.progressNolinkDisplayClose()
    rfsuite.app.dialogs.noLink:close()
end

-- we wrap a simple rate limiter into this to prevent cpu overload when handling msp
function ui.progressDisplayNoLinkValue(value, message)
    if value >= 100 then
        rfsuite.app.dialogs.noLink:value(value)
        if message then rfsuite.app.dialogs.noLink:message(message) end
        return
    end

    local now = os.clock()
    if (now - rfsuite.app.dialogs.nolinkRateLimit) >= rfsuite.app.dialogs.nolinkRate then
        rfsuite.app.dialogs.nolinkRateLimit = now
        rfsuite.app.dialogs.noLink:value(value)
        if message then rfsuite.app.dialogs.noLink:message(message) end
    end
end

function ui.disableAllFields()
    for i = 1, #rfsuite.app.formFields do 
        local field = rfsuite.app.formFields[i]
        if type(field) == "userdata" then
            field:enable(false) 
        end
    end
end

function ui.enableAllFields()
    for _, field in ipairs(rfsuite.app.formFields) do 
        if type(field) == "userdata" then
            field:enable(true) 
        end
    end
end

function ui.disableAllNavigationFields()
    for i, v in pairs(rfsuite.app.formNavigationFields) do
        if x ~= v then
            v:enable(false)
        end
    end
end

function ui.enableAllNavigationFields()
    for i, v in pairs(rfsuite.app.formNavigationFields) do
        if x ~= v then
            v:enable(true)
        end
    end
end

function ui.enableNavigationField(x)
    local field = rfsuite.app.formNavigationFields[x]
    if field then field:enable(true) end
end

function ui.disableNavigationField(x)
    local field = rfsuite.app.formNavigationFields[x]
    if field then field:enable(false) end
end


function ui.openMainMenu()

    -- clear old icons
    for i in pairs(rfsuite.app.gfx_buttons) do
        if i ~= "mainmenu" then
            rfsuite.app.gfx_buttons[i] = nil
        end
    end

    -- hard exit on error
    if not rfsuite.utils.ethosVersionAtLeast(config.ethosVersion) then
        return
    end    

    local MainMenu = assert(loadfile("app/modules/init.lua"))()

    -- Clear all navigation variables
    rfsuite.app.lastIdx = nil
    rfsuite.app.lastTitle = nil
    rfsuite.app.lastScript = nil
    rfsuite.session.lastPage = nil
    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu
    rfsuite.app.triggers.disableRssiTimeout = false

    -- Determine button size based on preferences
    rfsuite.preferences.iconSize = tonumber(rfsuite.preferences.iconSize) or 1

    local buttonW, buttonH, padding, numPerRow

    if rfsuite.preferences.iconSize == 0 then
        -- Text icons
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (config.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    elseif rfsuite.preferences.iconSize == 1 then
        -- Small icons
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    elseif rfsuite.preferences.iconSize == 2 then
        -- Large icons
        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    local sc
    local panel

    form.clear()

    rfsuite.app.gfx_buttons["mainmenu"] = rfsuite.app.gfx_buttons["mainmenu"] or {}
    rfsuite.app.menuLastSelected["mainmenu"] = rfsuite.app.menuLastSelected["mainmenu"] or 1

    for idx, section in ipairs(MainMenu.sections) do
        local hideSection = (section.ethosversion and rfsuite.config.ethosRunningVersion < section.ethosversion) or
                            (section.mspversion and (rfsuite.session.apiVersion or 1) < section.mspversion) or
                            (section.developer and not rfsuite.config.developerMode)

        if not hideSection then
            form.addLine(section.title)
            local lc, y = 0, 0

            for pidx, page in ipairs(MainMenu.pages) do
                if page.section == idx then
                    local hideEntry = (page.ethosversion and not rfsuite.utils.ethosVersionAtLeast(page.ethosversion)) or
                                      (page.mspversion and (rfsuite.session.apiVersion or 1) < page.mspversion) or
                                      (page.developer and not rfsuite.config.developerMode)

                    if not hideEntry then
                        if lc == 0 then
                            y = form.height() + (rfsuite.preferences.iconSize == 2 and rfsuite.app.radio.buttonPadding or rfsuite.app.radio.buttonPaddingSmall)
                        end

                        local x = (buttonW + padding) * lc
                        if rfsuite.preferences.iconSize ~= 0 then
                            rfsuite.app.gfx_buttons["mainmenu"][pidx] = rfsuite.app.gfx_buttons["mainmenu"][pidx] or lcd.loadMask("app/modules/" .. page.folder .. "/" .. page.image)
                        else
                            rfsuite.app.gfx_buttons["mainmenu"][pidx] = nil
                        end

                        rfsuite.app.formFields[pidx] = form.addButton(line, {x = x, y = y, w = buttonW, h = buttonH}, {
                            text = page.title,
                            icon = rfsuite.app.gfx_buttons["mainmenu"][pidx],
                            options = FONT_S,
                            paint = function() end,
                            press = function()
                                rfsuite.app.menuLastSelected["mainmenu"] = pidx
                                rfsuite.app.ui.progressDisplay()
                                rfsuite.app.ui.openPage(pidx, page.title, page.folder .. "/" .. page.script)
                            end
                        })

                        if rfsuite.app.menuLastSelected["mainmenu"] == pidx then
                            rfsuite.app.formFields[pidx]:focus()
                        end

                        lc = (lc + 1) % numPerRow
                    end
                end
            end
        end
    end

    collectgarbage()
end

function ui.progressDisplayIsActive()
    return rfsuite.app.dialogs.progressDisplay or 
           rfsuite.app.dialogs.saveDisplay or 
           rfsuite.app.dialogs.progressDisplayEsc or 
           rfsuite.app.dialogs.nolinkDisplay or 
           rfsuite.app.dialogs.badversionDisplay
end

function ui.getLabel(id, page)
    if id == nil then return nil end
    for i = 1, #page do
        if page[i].label == id then
            return page[i]
        end
    end
    return nil
end

function ui.fieldChoice(i)
    local app      = rfsuite.app
    local page     = app.Page
    local fields   = page.fields
    local f        = fields[i]
    local formLines   = app.formLines
    local formFields  = app.formFields
    local radioText = app.radio.text
    local posText, posField

    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then
            f.t = f.t2
        end
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText  = p.posText
        posField = p.posField
        form.addStaticText(formLines[formLineCnt], posText, f.t)
    else
        if f.t then
            if radioText == 2 and f.t2 then
                f.t = f.t2
            end
            if f.label then
                f.t = "        " .. f.t
            end
        end
        formLineCnt = formLineCnt + 1
        formLines[formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    local tbldata = f.table and rfsuite.app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}
    formFields[i] = form.addChoiceField(formLines[formLineCnt], posField, tbldata,
        function()
            if not fields or not fields[i] then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            return rfsuite.app.utils.getFieldValue(fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page, value) end
            if f.onChange then f.onChange(page, value) end
            f.value = rfsuite.app.utils.saveFieldValue(fields[i], value)
        end
    )

    if f.disable then
        formFields[i]:enable(false)
    end
end

function ui.fieldNumber(i)
    local app    = rfsuite.app
    local page   = app.Page
    local fields = page.fields
    local f      = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields

    -- Apply radio text override once
    if app.radio.text == 2 and f.t2 then
        f.t = f.t2
    end

    local posField, posText

    if f.inline and f.inline >= 1 and f.label then
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText  = p.posText
        posField = p.posField
        form.addStaticText(formLines[formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then
                f.t = "        " .. f.t
            end
        else
            f.t = ""
        end
        formLineCnt = formLineCnt + 1
        formLines[formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = rfsuite.app.utils.scaleValue(f.min, f)
    local maxValue = rfsuite.app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addNumberField(formLines[formLineCnt], posField, minValue, maxValue,
        function()
            if not (page.fields and page.fields[i]) then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            return rfsuite.app.utils.getFieldValue(page.fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = rfsuite.app.utils.saveFieldValue(page.fields[i], value)
        end
    )

    local currentField = formFields[i]

    if f.onFocus then
        currentField:onFocus(function() f.onFocus(page) end)
    end

    if f.default then
        if f.offset then f.default = f.default + f.offset end
        local default = f.default * rfsuite.app.utils.decimalInc(f.decimals)
        if f.mult then default = default * f.mult end
        local str = tostring(default)
        if str:match("%.0$") then default = math.ceil(default) end
        currentField:default(default)
    else
        currentField:default(0)
    end

    if f.decimals then currentField:decimals(f.decimals) end
    if f.unit     then currentField:suffix(f.unit) end
    if f.step     then currentField:step(f.step) end
    if f.disable  then currentField:enable(false) end

    if f.help or f.apikey then
        if not f.help and f.apikey then f.help = f.apikey end
        if app.fieldHelpTxt and app.fieldHelpTxt[f.help] and app.fieldHelpTxt[f.help].t then
            currentField:help(app.fieldHelpTxt[f.help].t)
        end
    end

    if f.instantChange == false then
        currentField:enableInstantChange(false)
    else
        currentField:enableInstantChange(true)
    end
end


function ui.fieldStaticText(i)
    local app       = rfsuite.app
    local page      = app.Page
    local fields    = page.fields
    local f         = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text
    local posText, posField

    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then
            f.t = f.t2
        end
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText  = p.posText
        posField = p.posField
        form.addStaticText(formLines[formLineCnt], posText, f.t)
    else
        if radioText == 2 and f.t2 then
            f.t = f.t2
        end
        if f.t then
            if f.label then
                f.t = "        " .. f.t
            end
        else
            f.t = ""
        end
        formLineCnt = formLineCnt + 1
        formLines[formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if HideMe == true then
        -- posField = {x = 2000, y = 0, w = 20, h = 20}
    end

    formFields[i] = form.addStaticText(formLines[formLineCnt], posField, rfsuite.app.utils.getFieldValue(fields[i]))
    local currentField = formFields[i]

    if f.onFocus then
        currentField:onFocus(function() f.onFocus(page) end)
    end

    if f.decimals then currentField:decimals(f.decimals) end
    if f.unit     then currentField:suffix(f.unit) end
    if f.step     then currentField:step(f.step) end
end


function ui.fieldText(i)
    local app         = rfsuite.app
    local page        = app.Page
    local fields      = page.fields
    local f           = fields[i]
    local formLines   = app.formLines
    local formFields  = app.formFields
    local radioText   = app.radio.text
    local posText, posField

    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then
            f.t = f.t2
        end
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText  = p.posText
        posField = p.posField
        form.addStaticText(formLines[formLineCnt], posText, f.t)
    else
        if radioText == 2 and f.t2 then
            f.t = f.t2
        end

        if f.t then
            if f.label then
                f.t = "        " .. f.t
            end
        else
            f.t = ""
        end

        formLineCnt = formLineCnt + 1
        formLines[formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    formFields[i] = form.addTextField(formLines[formLineCnt], posField,
        function()
            if not fields or not fields[i] then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            return rfsuite.app.utils.getFieldValue(fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end

            f.value = rfsuite.app.utils.saveFieldValue(fields[i], value)
        end
    )

    local currentField = formFields[i]

    if f.onFocus then
        currentField:onFocus(function() f.onFocus(page) end)
    end

    if f.disable then
        currentField:enable(false)
    end

    if f.help and app.fieldHelpTxt and app.fieldHelpTxt[f.help] and app.fieldHelpTxt[f.help].t then
        currentField:help(app.fieldHelpTxt[f.help].t)
    end

    if f.instantChange == false then
        currentField:enableInstantChange(false)
    else
        currentField:enableInstantChange(true)
    end
end


function ui.fieldLabel(f, i, l)
    local app = rfsuite.app

    if f.t then
        if f.t2 then 
            f.t = f.t2 
        end
        if f.label then 
            f.t = "        " .. f.t 
        end
    end

    if f.label then
        local label = app.ui.getLabel(f.label, l)
        local labelValue = label.t
        if label.t2 then 
            labelValue = label.t2 
        end
        local labelName = f.t and labelValue or "unknown"

        if f.label ~= rfsuite.lastLabel then
            label.type = label.type or 0
            formLineCnt = formLineCnt + 1
            app.formLines[formLineCnt] = form.addLine(labelName)
            form.addStaticText(app.formLines[formLineCnt], nil, "")
            rfsuite.lastLabel = f.label
        end
    end
end


function ui.fieldHeader(title)
    local app    = rfsuite.app
    local utils  = rfsuite.utils
    local radio  = app.radio
    local formFields = app.formFields
    local lcdWidth   = config.lcdWidth

    local w, h = utils.getWindowSize()
    local padding = 5
    local colStart = math.floor(w * 59.4 / 100)
    if radio.navButtonOffset then 
        colStart = colStart - radio.navButtonOffset 
    end

    local buttonW = radio.buttonWidth and radio.menuButtonWidth or ((w - colStart) / 3 - padding)
    local buttonH = radio.navbuttonHeight

    formFields['menu'] = form.addLine("")
    formFields['title'] = form.addStaticText(formFields['menu'], {x = 0, y = radio.linePaddingTop, w = lcdWidth, h = radio.navbuttonHeight}, title)

    app.ui.navigationButtons(w - 5, radio.linePaddingTop, buttonW, buttonH)
end


function ui.openPageRefresh(idx, title, script, extra1, extra2, extra3, extra5, extra6)
    rfsuite.app.triggers.isReady = false
end


function ui.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)
    -- Initialize global UI state and clear form data
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false
    rfsuite.app.formFields = {}
    rfsuite.app.formLines = {}

    -- Load the module
    local modulePath = "app/modules/" .. script
    rfsuite.app.Page = assert(loadfile(modulePath))(idx)

    -- Load the help file if it exists
    local section = script:match("([^/]+)")
    local helpPath = "app/modules/" .. section .. "/help.lua"
    if rfsuite.utils.file_exists(helpPath) then
        local helpData = assert(loadfile(helpPath))()
        rfsuite.app.fieldHelpTxt = helpData.fields
    else
        rfsuite.app.fieldHelpTxt = nil
    end

    -- If the Page has its own openPage function, use it and return early
    if rfsuite.app.Page.openPage then
        rfsuite.app.Page.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)
        return
    end

    -- Fallback behavior if no custom openPage exists
    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    form.clear()
    rfsuite.session.lastPage = script

    local pageTitle = rfsuite.app.Page.pageTitle or title
    rfsuite.app.ui.fieldHeader(pageTitle)

    if rfsuite.app.Page.headerLine then
        local headerLine = form.addLine("")
        form.addStaticText(headerLine, {
            x = 0,
            y = rfsuite.app.radio.linePaddingTop,
            w = config.lcdWidth,
            h = rfsuite.app.radio.navbuttonHeight
        }, rfsuite.app.Page.headerLine)
    end

    formLineCnt = 0

    rfsuite.utils.log("Merging form data from mspapi", "debug")
    rfsuite.app.Page.fields = rfsuite.app.Page.mspapi.formdata.fields
    rfsuite.app.Page.labels = rfsuite.app.Page.mspapi.formdata.labels

    if rfsuite.app.Page.fields then
        for i, field in ipairs(rfsuite.app.Page.fields) do
            local label = rfsuite.app.Page.labels
            local version = rfsuite.session.apiVersion
            local valid = (field.apiversion    == nil or field.apiversion    <= version) and
                          (field.apiversionlt  == nil or field.apiversionlt  >  version) and
                          (field.apiversiongt  == nil or field.apiversiongt  <  version) and
                          (field.apiversionlte == nil or field.apiversionlte >= version) and
                          (field.apiversiongte == nil or field.apiversiongte <= version) and
                          (field.enablefunction == nil or field.enablefunction())

            if field.hidden ~= true and valid then
                rfsuite.app.ui.fieldLabel(field, i, label)
                if field.type == 0 then
                    rfsuite.app.ui.fieldStaticText(i)
                elseif field.table or field.type == 1 then
                    rfsuite.app.ui.fieldChoice(i)
                elseif field.type == 2 then
                    rfsuite.app.ui.fieldNumber(i)
                elseif field.type == 3 then
                    rfsuite.app.ui.fieldText(i)
                else
                    rfsuite.app.ui.fieldNumber(i)
                end
            else
                rfsuite.app.formFields[i] = {}
            end
        end
    end
end


function ui.navigationButtons(x, y, w, h)

    local xOffset = 0
    local padding = 5
    local wS = w - (w * 20) / 100
    local helpOffset = 0
    local toolOffset = 0
    local reloadOffset = 0
    local saveOffset = 0
    local menuOffset = 0

    local navButtons
    if rfsuite.app.Page.navButtons == nil then
        navButtons = {menu = true, save = true, reload = true, help = true}
    else
        navButtons = rfsuite.app.Page.navButtons
    end

    -- calc all offsets
    -- these are done 'early' to enable the actual placement of the buttons on
    -- display to be rendered by ethos in the right order - for scrolling via
    -- keypad to work.
    if navButtons.help ~= nil and navButtons.help == true then xOffset = xOffset + wS + padding end
    helpOffset = x - xOffset

    if navButtons.tool ~= nil and navButtons.tool == true then xOffset = xOffset + wS + padding end
    toolOffset = x - xOffset

    if navButtons.reload ~= nil and navButtons.reload == true then xOffset = xOffset + w + padding end
    reloadOffset = x - xOffset

    if navButtons.save ~= nil and navButtons.save == true then xOffset = xOffset + w + padding end
    saveOffset = x - xOffset

    if navButtons.menu ~= nil and navButtons.menu == true then xOffset = xOffset + w + padding end
    menuOffset = x - xOffset

    -- MENU BTN
    if navButtons.menu ~= nil and navButtons.menu == true then

        rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {x = menuOffset, y = y, w = w, h = h}, {
            text = "MENU",
            icon = nil,
            options = FONT_S,
            paint = function()
            end,
            press = function()
                if rfsuite.app.Page and rfsuite.app.Page.onNavMenu then
                    rfsuite.app.Page.onNavMenu(rfsuite.app.Page)
                else
                    rfsuite.app.ui.openMainMenu()
                end
            end
        })
        rfsuite.app.formNavigationFields['menu']:focus()
    end

    -- SAVE BTN
    if navButtons.save ~= nil and navButtons.save == true then

        rfsuite.app.formNavigationFields['save'] = form.addButton(line, {x = saveOffset, y = y, w = w, h = h}, {
            text = "SAVE",
            icon = nil,
            options = FONT_S,
            paint = function()
            end,
            press = function()
                if rfsuite.app.Page and rfsuite.app.Page.onSaveMenu then
                    rfsuite.app.Page.onSaveMenu(rfsuite.app.Page)
                else
                    rfsuite.app.triggers.triggerSave = true
                end
            end
        })
    end

    -- RELOAD BTN
    if navButtons.reload ~= nil and navButtons.reload == true then

        rfsuite.app.formNavigationFields['reload'] = form.addButton(line, {x = reloadOffset, y = y, w = w, h = h}, {
            text = "RELOAD",
            icon = nil,
            options = FONT_S,
            paint = function()
            end,
            press = function()

                if rfsuite.app.Page and rfsuite.app.Page.onReloadMenu then
                    rfsuite.app.Page.onReloadMenu(rfsuite.app.Page)
                else
                        rfsuite.app.triggers.triggerReload = true
                end
                return true
            end
        })
    end

    -- TOOL BUTTON
    if navButtons.tool ~= nil and navButtons.tool == true then
        rfsuite.app.formNavigationFields['tool'] = form.addButton(line, {x = toolOffset, y = y, w = wS, h = h}, {
            text = "*",
            icon = nil,
            options = FONT_S,
            paint = function()
            end,
            press = function()
                rfsuite.app.Page.onToolMenu()
            end
        })
    end

    -- HELP BUTTON
    if navButtons.help ~= nil and navButtons.help == true then
        local section = rfsuite.app.lastScript:match("([^/]+)") -- return just the folder name
        local script = string.match(rfsuite.app.lastScript, "/([^/]+)%.lua$")

        -- Attempt to load the help.lua file
        local helpPath = "app/modules/" .. section .. "/help.lua"

        if rfsuite.utils.file_exists(helpPath) then

            local help = assert(loadfile(helpPath))()

            -- Execution of the file succeeded
            rfsuite.app.formNavigationFields['help'] = form.addButton(line, {x = helpOffset, y = y, w = wS, h = h}, {
                text = "?",
                icon = nil,
                options = FONT_S,
                paint = function()
                end,
                press = function()
                    if rfsuite.app.Page and rfsuite.app.Page.onHelpMenu then
                        rfsuite.app.Page.onHelpMenu(rfsuite.app.Page)
                    else
                        if section == 'rates' then
                            -- rates is an oddball and has an exeption
                            rfsuite.app.ui.openPageHelp(help.help["table"][rfsuite.session.rateProfile], section)
                        else
                            -- choose default or custom
                            if help.help[script] then
                                rfsuite.app.ui.openPageHelp(help.help[script], section)
                            else
                                rfsuite.app.ui.openPageHelp(help.help['default'], section)
                            end
                        end
                    end
                end
            })

        else
            -- File loading failed
            rfsuite.utils.log("Failed to load help.lua: " .. loadError,"debug")
            rfsuite.app.formNavigationFields['help'] = form.addButton(line, {x = helpOffset, y = y, w = wS, h = h}, {
                text = "?",
                icon = nil,
                options = FONT_S,
                paint = function()
                end,
                press = function()
                end
            })
            rfsuite.app.formNavigationFields['help']:enable(false)
        end
    end

end

function ui.openPageHelp(txtData, section)
    local message = table.concat(txtData, "\r\n\r\n")

    form.openDialog({
        width = config.lcdWidth,
        title = "Help - " .. rfsuite.app.lastTitle,
        message = message,
        buttons = {{
            label = "CLOSE",
            action = function() return true end
        }},
        options = TEXT_LEFT
    })
end


-- form target; field from exsting page; field from strucxture
-- v is the structure value
-- f is the field from page value
function ui.injectApiAttributes(formField, f, v)
    local utils = rfsuite.utils
    local log = utils.log

    if v.decimals and not f.decimals then
        if f.type ~= 1 then
            log("Injecting decimals: " .. v.decimals, "debug")
            f.decimals = v.decimals
            formField:decimals(v.decimals)
        end
    end
    if v.scale and not f.scale then 
        log("Injecting scale: " .. v.scale, "debug")
        f.scale = v.scale 
    end
    if v.mult and not f.mult then 
        log("Injecting mult: " .. v.mult, "debug")
        f.mult = v.mult 
    end
    if v.offset and not f.offset then 
        log("Injecting offset: " .. v.offset, "debug")
        f.offset = v.offset 
    end
    if v.unit and not f.unit then 
        if f.type ~= 1 then
            log("Injecting unit: " .. v.unit, "debug")
            formField:suffix(v.unit)
        end    
    end
    if v.step and not f.step then
        if f.type ~= 1 then
            log("Injecting step: " .. v.step, "debug")
            f.step = v.step
            formField:step(v.step)
        end
    end
    if v.min and not f.min then
        f.min = v.min
        if f.offset then 
            f.min = f.min + f.offset 
        end            
        if f.type ~= 1 then
            log("Injecting min: " .. f.min, "debug")
            formField:minimum(f.min)
        end
    end
    if v.max and not f.max then
        f.max = v.max
        if f.offset then 
            f.max = f.max + f.offset 
        end        
        if f.type ~= 1 then
            log("Injecting max: " .. f.max, "debug")
            formField:maximum(f.max)
        end
    end
    if v.default and not f.default then
        f.default = v.default
        
        -- Factor in all possible scaling.
        if f.offset then 
            f.default = f.default + f.offset 
        end
        local default = f.default * rfsuite.app.utils.decimalInc(f.decimals)
        if f.mult then 
            default = default * f.mult 
        end

        -- Work around ethos peculiarity on default boxes if trailing .0.
        local str = tostring(default)
        if str:match("%.0$") then 
            default = math.ceil(default) 
        end                            

        if f.type ~= 1 then 
            log("Injecting default: " .. default, "debug")
            formField:default(default)
        end

    end  
    if v.table and not f.table then 
        f.table = v.table 
        local idxInc = f.tableIdxInc or v.tableIdxInc
        local tbldata = rfsuite.app.utils.convertPageValueTable(v.table, idxInc)       
        if f.type == 1 then   
            log("Injecting table: {}", "debug")                   
            formField:values(tbldata)
        end
    end            
    if v.help then
        f.help = v.help
        log("Injecting help: {}", "debug")
        formField:help(v.help)
    end  

end


return ui
