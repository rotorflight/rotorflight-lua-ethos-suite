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

    if rfsuite.app.dialogs.progressDisplay == true then return end

    rfsuite.app.audio.playLoading = true

    if title == nil then title = "Loading" end
    if message == nil then message = "Loading data from flight controller..." end

    rfsuite.app.dialogs.progressDisplay = true
    rfsuite.app.dialogs.progressWatchDog = os.clock()
    rfsuite.app.dialogs.progress = form.openProgressDialog(title, message)
    rfsuite.app.dialogs.progressDisplay = true
    rfsuite.app.dialogs.progressCounter = 0
    if rfsuite.app.dialogs.progress ~= nil then
        rfsuite.app.dialogs.progress:value(0)
        rfsuite.app.dialogs.progress:closeAllowed(false)
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

    -- if rfsuite.app.triggers.mspBusy == true then return end

    if value >= 100 then
        rfsuite.app.dialogs.progress:value(value)
        if message ~= nil then rfsuite.app.dialogs.progress:message(message) end
        return
    end

    local now = os.clock()
    if (now - rfsuite.app.dialogs.progressRateLimit) >= rfsuite.app.dialogs.progressRate then
        rfsuite.app.dialogs.progressRateLimit = now
        rfsuite.app.dialogs.progress:value(value)
        if message ~= nil then rfsuite.app.dialogs.progress:message(message) end
    end

end

-- we wrap a simple rate limiter into this to prevent cpu overload when handling msp
function ui.progressDisplaySaveValue(value, message)

    -- if rfsuite.app.triggers.mspBusy == true then return end

    if value >= 100 then
        rfsuite.app.dialogs.save:value(value)
        if message ~= nil then rfsuite.app.dialogs.save:message(message) end
        return
    end

    local now = os.clock()
    if (now - rfsuite.app.dialogs.saveRateLimit) >= rfsuite.app.dialogs.saveRate then
        rfsuite.app.dialogs.saveRateLimit = now
        rfsuite.app.dialogs.save:value(value)
        if message ~= nil then rfsuite.app.dialogs.save:message(message) end
    end

end

function ui.progressDisplayClose()
    if rfsuite.app.dialogs.progress ~= nil then rfsuite.app.dialogs.progress:close() end
    rfsuite.app.dialogs.progressDisplay = false
end

function ui.progressDisplayCloseAllowed(status)
    if rfsuite.app.dialogs.progress ~= nil then rfsuite.app.dialogs.progress:closeAllowed(status) end
end

function ui.progressDisplayMessage(message)
    if rfsuite.app.dialogs.progress ~= nil then rfsuite.app.dialogs.progress:message(message) end
end

function ui.progressDisplaySaveClose()
    if rfsuite.app.dialogs.progress ~= nil then rfsuite.app.dialogs.save:close() end
    rfsuite.app.dialogs.saveDisplay = false
end

function ui.progressDisplaySaveMessage(message)
    if rfsuite.app.dialogs.save ~= nil then rfsuite.app.dialogs.save:message(message) end
end

function ui.progressDisplaySaveCloseAllowed(status)
    if rfsuite.app.dialogs.save ~= nil then rfsuite.app.dialogs.save:closeAllowed(status) end
end

function ui.progressNolinkDisplayClose()
    rfsuite.app.dialogs.noLink:close()
end

-- we wrap a simple rate limiter into this to prevent cpu overload when handling msp
function ui.progressDisplayNoLinkValue(value, message)

    -- if rfsuite.app.triggers.mspBusy == true then return end

    if value >= 100 then
        rfsuite.app.dialogs.noLink:value(value)
        if message ~= nil then rfsuite.app.dialogs.noLink:message(message) end
        return
    end

    local now = os.clock()
    if (now - rfsuite.app.dialogs.nolinkRateLimit) >= rfsuite.app.dialogs.nolinkRate then
        rfsuite.app.dialogs.nolinkRateLimit = now
        rfsuite.app.dialogs.noLink:value(value)
        if message ~= nil then rfsuite.app.dialogs.noLink:message(message) end
    end

end

function ui.disableAllFields()
    for i in ipairs(rfsuite.app.formFields) do rfsuite.app.formFields[i]:enable(false) end
end

function ui.enableAllFields()
    for i in ipairs(rfsuite.app.formFields) do rfsuite.app.formFields[i]:enable(true) end
end

function ui.disableAllNavigationFields()
    for i, v in pairs(rfsuite.app.formNavigationFields) do if x ~= v then rfsuite.app.formNavigationFields[i]:enable(false) end end
end

function ui.enableAllNavigationFields()
    for i, v in pairs(rfsuite.app.formNavigationFields) do if x ~= v then rfsuite.app.formNavigationFields[i]:enable(true) end end
end

function ui.enableNavigationField(x)
    if rfsuite.app.formNavigationFields[x] ~= nil then rfsuite.app.formNavigationFields[x]:enable(true) end
end

function ui.disableNavigationField(x)
    if rfsuite.app.formNavigationFields[x] ~= nil then rfsuite.app.formNavigationFields[x]:enable(false) end
end

function ui.openMainMenu()

    -- clear old icons
    for i,v in pairs(rfsuite.app.gfx_buttons) do
        if i ~= "mainmenu" then
            rfsuite.app.gfx_buttons[i] = nil
        end
    end

    -- hard exit on error
    if not rfsuite.utils.ethosVersionAtLeast(config.ethosVersion) then
        return
    end    

    local MainMenu = assert(loadfile("app/modules/init.lua"))()

    -- clear all nav vars
    rfsuite.app.lastIdx = nil
    rfsuite.app.lastTitle = nil
    rfsuite.app.lastScript = nil
    rfsuite.lastPage = nil

    -- rfsuite.bg.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu
    rfsuite.app.triggers.disableRssiTimeout = false

    -- size of buttons
    if config.iconSize == nil or config.iconSize == "" then
        config.iconSize = 1
    else
        config.iconSize = tonumber(config.iconSize)
    end

    local buttonW
    local buttonH
    local padding
    local numPerRow

    -- TEXT ICONS
    if config.iconSize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (config.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end
    -- SMALL ICONS
    if config.iconSize == 1 then

        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end
    -- LARGE ICONS
    if config.iconSize == 2 then

        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    local sc
    local panel

    form.clear()

    if rfsuite.app.gfx_buttons["mainmenu"] == nil then rfsuite.app.gfx_buttons["mainmenu"] = {} end
    if rfsuite.app.menuLastSelected["mainmenu"] == nil then rfsuite.app.menuLastSelected["mainmenu"] = 1 end

    for idx, value in ipairs(MainMenu.sections) do

        local hideSection = false

        if (value.ethosversion ~= nil and rfsuite.config.ethosRunningVersion < value.ethosversion) then hideSection = true end

        if (value.mspversion ~= nil and rfsuite.config.apiVersion < value.mspversion) then hideSection = true end

        if (value.developer ~= nil and rfsuite.config.developerMode == false) then hideSection = true end

        if hideSection == false then

            local sc = idx

            form.addLine(value.title)

            lc = 0

            for pidx, pvalue in ipairs(MainMenu.pages) do
                if pvalue.section == idx then
                    -- do not show icon if not supported by ethos version
                    local hideEntry = false

                    if (pvalue.ethosversion ~= nil and not rfsuite.utils.ethosVersionAtLeast(pvalue.ethosversion)) then hideEntry = true end

                    if (rfsuite.config.apiVersion) and (pvalue.mspversion ~= nil and rfsuite.config.apiVersion < pvalue.mspversion) then hideEntry = true end

                    if (pvalue.developer ~= nil and rfsuite.config.developerMode == false) then hideEntry = true end

                    if hideEntry == false then

                        if lc == 0 then
                            if config.iconSize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                            if config.iconSize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                            if config.iconSize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
                        end

                        if lc >= 0 then x = (buttonW + padding) * lc end

                        if config.iconSize ~= 0 then
                            if rfsuite.app.gfx_buttons["mainmenu"][pidx] == nil then rfsuite.app.gfx_buttons["mainmenu"][pidx] = lcd.loadMask("app/modules/" .. pvalue.folder .. "/" .. pvalue.image) end
                        else
                            rfsuite.app.gfx_buttons["mainmenu"][pidx] = nil
                        end

                        rfsuite.app.formFields[pidx] = form.addButton(line, {x = x, y = y, w = buttonW, h = buttonH}, {
                            text = pvalue.title,
                            icon = rfsuite.app.gfx_buttons["mainmenu"][pidx],
                            options = FONT_S,
                            paint = function()
                            end,
                            press = function()
                                rfsuite.app.menuLastSelected["mainmenu"] = pidx
                                rfsuite.app.ui.progressDisplay()
                                rfsuite.app.ui.openPage(pidx, pvalue.title, pvalue.folder .. "/" .. pvalue.script)
                            end
                        })

                        -- if pvalue.ethosversion ~= nil and rfsuite.config.ethosRunningVersion < pvalue.ethos then rfsuite.app.formFields[pidx]:enable(false) end

                        if rfsuite.app.menuLastSelected["mainmenu"] == pidx then rfsuite.app.formFields[pidx]:focus() end

                        lc = lc + 1

                        if lc == numPerRow then lc = 0 end

                    end

                end
            end

        end

    end

end

function ui.progressDisplayIsActive()

    if rfsuite.app.dialogs.progressDisplay == true then return true end
    if rfsuite.app.dialogs.saveDisplay == true then return true end
    if rfsuite.app.dialogs.progressDisplayEsc == true then return true end
    if rfsuite.app.dialogs.nolinkDisplay == true then return true end
    if rfsuite.app.dialogs.badversionDisplay == true then return true end

    return false
end

function ui.getLabel(id, page)
    for i, v in ipairs(page) do if id ~= nil then if v.label == id then return v end end end
end

function ui.fieldChoice(i)

    local f = rfsuite.app.Page.fields[i]

    if f.inline ~= nil and f.inline >= 1 and f.label ~= nil then

        if rfsuite.app.radio.text == 2 then if f.t2 ~= nil then f.t = f.t2 end end

        local p = rfsuite.utils.getInlinePositions(f, rfsuite.app.Page)
        posText = p.posText
        posField = p.posField

        field = form.addStaticText(rfsuite.app.formLines[formLineCnt], posText, f.t)
    else
        if f.t ~= nil then
            if f.t2 ~= nil then f.t = f.t2 end

            if f.label ~= nil then f.t = "        " .. f.t end
        end
        formLineCnt = formLineCnt + 1
        rfsuite.app.formLines[formLineCnt] = form.addLine(f.t)
        if f.position ~= nil then
            posField = f.position
        else
            posField = nil
        end
        postText = nil
    end

    local tbldata
    if f.table == nil then
        tbldata = {}
    else
        tbldata = rfsuite.utils.convertPageValueTable(f.table, f.tableIdxInc)
    end
    rfsuite.app.formFields[i] = form.addChoiceField(rfsuite.app.formLines[formLineCnt], posField, tbldata, function()
        if rfsuite.app.Page.fields == nil or rfsuite.app.Page.fields[i] == nil then
            ui.disableAllFields()
            ui.disableAllNavigationFields()
            ui.enableNavigationField('menu')
            return nil
        end
        return rfsuite.utils.getFieldValue(rfsuite.app.Page.fields[i])
    end, function(value)
        -- we do this hook to allow rates to be reset
        if f.postEdit then f.postEdit(rfsuite.app.Page, value) end
        if f.onChange then f.onChange(rfsuite.app.Page, value) end
        f.value = rfsuite.utils.saveFieldValue(rfsuite.app.Page.fields[i], value)
        rfsuite.app.saveValue(i)
    end)

    if f.disable == true then rfsuite.app.formFields[i]:enable(false) end

end

function ui.fieldNumber(i)

    local f = rfsuite.app.Page.fields[i]

    if f.inline ~= nil and f.inline >= 1 and f.label ~= nil then
        if rfsuite.app.radio.text == 2 then if f.t2 ~= nil then f.t = f.t2 end end

        local p = rfsuite.utils.getInlinePositions(f, rfsuite.app.Page)
        posText = p.posText
        posField = p.posField

        field = form.addStaticText(rfsuite.app.formLines[formLineCnt], posText, f.t)
    else
        if rfsuite.app.radio.text == 2 then if f.t2 ~= nil then f.t = f.t2 end end

        if f.t ~= nil then

            if f.label ~= nil then f.t = "        " .. f.t end
        else
            f.t = ""
        end

        formLineCnt = formLineCnt + 1

        rfsuite.app.formLines[formLineCnt] = form.addLine(f.t)

        if f.position ~= nil then
            posField = f.position
        else
            posField = nil
        end
        postText = nil
    end

    if f.offset ~= nil then
        if f.min ~= nil then f.min = f.min + f.offset end
        if f.max ~= nil then f.max = f.max + f.offset end
    end

    minValue = rfsuite.utils.scaleValue(f.min, f)
    maxValue = rfsuite.utils.scaleValue(f.max, f)

    if f.mult ~= nil then
        if minValue ~= nil then minValue = minValue * f.mult end
        if maxValue ~= nil then maxValue = maxValue * f.mult end
    end

    if minValue == nil then minValue = 0 end
    if maxValue == nil then maxValue = 0 end
    rfsuite.app.formFields[i] = form.addNumberField(rfsuite.app.formLines[formLineCnt], posField, minValue, maxValue, function()
        if rfsuite.app.Page.fields == nil or rfsuite.app.Page.fields[i] == nil then
            ui.disableAllFields()
            ui.disableAllNavigationFields()
            ui.enableNavigationField('menu')
            return nil
        end
        return rfsuite.utils.getFieldValue(rfsuite.app.Page.fields[i])
    end, function(value)
        if f.postEdit then f.postEdit(rfsuite.app.Page) end
        if f.onChange then f.onChange(rfsuite.app.Page) end

        f.value = rfsuite.utils.saveFieldValue(rfsuite.app.Page.fields[i], value)
        rfsuite.app.saveValue(i)
    end)


    if f.onFocus ~= nil then
        rfsuite.app.formFields[i]:onFocus(function()
            f.onFocus(rfsuite.app.Page)
        end)
    end


    if f.default ~= nil then
        if f.offset ~= nil then f.default = f.default + f.offset end
        local default = f.default * rfsuite.utils.decimalInc(f.decimals)
        if f.mult ~= nil then default = default * f.mult end

        -- if for some reason we have a .0 we need to work around an ethos pecularity on default boxes!
        local str = tostring(default)
        if str:match("%.0$") then default = math.ceil(default) end

        rfsuite.app.formFields[i]:default(default)
    else
        rfsuite.app.formFields[i]:default(0)
    end

    if f.decimals ~= nil then rfsuite.app.formFields[i]:decimals(f.decimals) end
    if f.unit ~= nil then rfsuite.app.formFields[i]:suffix(f.unit) end
    if f.step ~= nil then rfsuite.app.formFields[i]:step(f.step) end
    if f.disable == true then rfsuite.app.formFields[i]:enable(false) end

    if f.help ~= nil or f.apikey ~= nil then

        if f.help == nil and f.apikey ~= nul then f.help = f.apikey end

        if rfsuite.app.fieldHelpTxt and rfsuite.app.fieldHelpTxt[f.help] and rfsuite.app.fieldHelpTxt[f.help]['t'] ~= nil then
            local helpTxt = rfsuite.app.fieldHelpTxt[f.help]['t']
            rfsuite.app.formFields[i]:help(helpTxt)
        end
    end
    if f.instantChange and f.instantChange == true then
        rfsuite.app.formFields[i]:enableInstantChange(true)
    elseif f.instantChange and f.instantChange == false then
        rfsuite.app.formFields[i]:enableInstantChange(false)    
    else
        rfsuite.app.formFields[i]:enableInstantChange(true)
    end
end

function ui.fieldStaticText(i)

    local f = rfsuite.app.Page.fields[i]

    if f.inline ~= nil and f.inline >= 1 and f.label ~= nil then
        if rfsuite.app.radio.text == 2 then if f.t2 ~= nil then f.t = f.t2 end end

        local p = rfsuite.utils.getInlinePositions(f, rfsuite.app.Page)
        posText = p.posText
        posField = p.posField

        field = form.addStaticText(rfsuite.app.formLines[formLineCnt], posText, f.t)
    else
        if rfsuite.app.radio.text == 2 then if f.t2 ~= nil then f.t = f.t2 end end

        if f.t ~= nil then

            if f.label ~= nil then f.t = "        " .. f.t end
        else
            f.t = ""
        end

        formLineCnt = formLineCnt + 1

        rfsuite.app.formLines[formLineCnt] = form.addLine(f.t)

        if f.position ~= nil then
            posField = f.position
        else
            posField = nil
        end
        postText = nil
    end

    if HideMe == true then
        -- posField = {x = 2000, y = 0, w = 20, h = 20}
    end

    rfsuite.app.formFields[i] = form.addStaticText(rfsuite.app.formLines[formLineCnt], posField, rfsuite.utils.getFieldValue(rfsuite.app.Page.fields[i]))

    if f.onFocus ~= nil then
        rfsuite.app.formFields[i]:onFocus(function()
            f.onFocus(rfsuite.app.Page)
        end)
    end


    if f.decimals ~= nil then rfsuite.app.formFields[i]:decimals(f.decimals) end
    if f.unit ~= nil then rfsuite.app.formFields[i]:suffix(f.unit) end
    if f.step ~= nil then rfsuite.app.formFields[i]:step(f.step) end

end

function ui.fieldText(i)

    local f = rfsuite.app.Page.fields[i]

    if f.inline ~= nil and f.inline >= 1 and f.label ~= nil then
        if rfsuite.app.radio.text == 2 then if f.t2 ~= nil then f.t = f.t2 end end

        local p = rfsuite.utils.getInlinePositions(f, rfsuite.app.Page)
        posText = p.posText
        posField = p.posField

        field = form.addStaticText(rfsuite.app.formLines[formLineCnt], posText, f.t)
    else
        if rfsuite.app.radio.text == 2 then if f.t2 ~= nil then f.t = f.t2 end end

        if f.t ~= nil then

            if f.label ~= nil then f.t = "        " .. f.t end
        else
            f.t = ""
        end

        formLineCnt = formLineCnt + 1

        rfsuite.app.formLines[formLineCnt] = form.addLine(f.t)

        if f.position ~= nil then
            posField = f.position
        else
            posField = nil
        end
        postText = nil
    end

    if HideMe == true then
        -- posField = {x = 2000, y = 0, w = 20, h = 20}
    end

    rfsuite.app.formFields[i] = form.addTextField(rfsuite.app.formLines[formLineCnt], posField, function()
        if rfsuite.app.Page.fields == nil or rfsuite.app.Page.fields[i] == nil then
            ui.disableAllFields()
            ui.disableAllNavigationFields()
            ui.enableNavigationField('menu')
            return nil
        end
        return rfsuite.utils.getFieldValue(rfsuite.app.Page.fields[i])
    end, function(value)
        if f.postEdit then f.postEdit(rfsuite.app.Page) end
        if f.onChange then f.onChange(rfsuite.app.Page) end

        f.value = rfsuite.utils.saveFieldValue(rfsuite.app.Page.fields[i], value)
        rfsuite.app.saveValue(i)
    end)

    if config.ethosRunningVersion >= 1514 then
        if f.onFocus ~= nil then
            rfsuite.app.formFields[i]:onFocus(function()
                f.onFocus(rfsuite.app.Page)
            end)
        end
    end

    if f.disable == true then rfsuite.app.formFields[i]:enable(false) end

    if f.help ~= nil then
        if rfsuite.app.fieldHelpTxt and rfsuite.app.fieldHelpTxt[f.help] and rfsuite.app.fieldHelpTxt[f.help]['t'] ~= nil then
            local helpTxt = rfsuite.app.fieldHelpTxt[f.help]['t']
            rfsuite.app.formFields[i]:help(helpTxt)
        end
    end
    if f.instantChange and f.instantChange == true then
        rfsuite.app.formFields[i]:enableInstantChange(true)
    elseif f.instantChange and f.instantChange == false then
        rfsuite.app.formFields[i]:enableInstantChange(false)    
    else
        rfsuite.app.formFields[i]:enableInstantChange(true)
    end

end

function ui.fieldLabel(f, i, l)

    if f.t ~= nil then
        if f.t2 ~= nil then f.t = f.t2 end

        if f.label ~= nil then f.t = "        " .. f.t end
    end

    if f.label ~= nil then
        local label = rfsuite.app.ui.getLabel(f.label, l)

        local labelValue = label.t
        local labelID = label.label

        if label.t2 ~= nil then labelValue = label.t2 end
        if f.t ~= nil then
            labelName = labelValue
        else
            labelName = "unknown"
        end

        if f.label ~= rfsuite.lastLabel then
            if label.type == nil then label.type = 0 end

            formLineCnt = formLineCnt + 1
            rfsuite.app.formLines[formLineCnt] = form.addLine(labelName)
            form.addStaticText(rfsuite.app.formLines[formLineCnt], nil, "")

            rfsuite.lastLabel = f.label
        end
    else
        labelID = nil
    end
end

function ui.fieldHeader(title)
    local w, h = rfsuite.utils.getWindowSize()
    -- column starts at 59.4% of w
    padding = 5
    colStart = math.floor(((w) * 59.4) / 100)
    if rfsuite.app.radio.navButtonOffset ~= nil then colStart = colStart - rfsuite.app.radio.navButtonOffset end

    if rfsuite.app.radio.buttonWidth == nil then
        buttonW = (w - colStart) / 3 - padding
    else
        buttonW = rfsuite.app.radio.menuButtonWidth
    end
    buttonH = rfsuite.app.radio.navbuttonHeight

    rfsuite.app.formFields['menu'] = form.addLine("")

    rfsuite.app.formFields['title'] = form.addStaticText(rfsuite.app.formFields['menu'], {x = 0, y = rfsuite.app.radio.linePaddingTop, w = config.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, title)

    rfsuite.app.ui.navigationButtons(w - 5, rfsuite.app.radio.linePaddingTop, buttonW, buttonH)
end

function ui.openPageRefresh(idx, title, script, extra1, extra2, extra3, extra5, extra6)

    rfsuite.app.triggers.isReady = false
    if script ~= nil then rfsuite.app.Page = assert(loadfile("app/modules/" .. script))() end

end

function ui.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false
    rfsuite.app.formFields = {}
    rfsuite.app.formLines = {}

    rfsuite.app.Page = assert(loadfile("app/modules/" .. script))(idx)

    -- load the help file
    local section = script:match("([^/]+)") -- return just the folder name
    local helpPath = "app/modules/" .. section .. "/help.lua"
    if rfsuite.utils.file_exists(helpPath) then
        local helpData = assert(loadfile(helpPath))()
        rfsuite.app.fieldHelpTxt = helpData.fields
    else
        rfsuite.app.fieldHelpTxt = nil
    end

    if rfsuite.app.Page.openPage then
        rfsuite.app.Page.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)
    else

        rfsuite.app.lastIdx = idx
        rfsuite.app.lastTitle = title
        rfsuite.app.lastScript = script

        local fieldAR = {}

        rfsuite.app.uiState = rfsuite.app.uiStatus.pages
        rfsuite.app.triggers.isReady = false

        longPage = false

        form.clear()

        rfsuite.lastPage = script

        if rfsuite.app.Page.pageTitle ~= nil then
            rfsuite.app.ui.fieldHeader(rfsuite.app.Page.pageTitle)
        else
            rfsuite.app.ui.fieldHeader(title)
        end

        if rfsuite.app.Page.headerLine ~= nil then
            local headerLine = form.addLine("")
            local headerLineText = form.addStaticText(headerLine, {x = 0, y = rfsuite.app.radio.linePaddingTop, w = config.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}, rfsuite.app.Page.headerLine)
        end

        formLineCnt = 0

        for i = 1, #rfsuite.app.Page.fields do
            local f = rfsuite.app.Page.fields[i]
            local l = rfsuite.app.Page.labels
            local pageValue = f
            local pageIdx = i
            local currentField = i

            rfsuite.app.ui.fieldLabel(f, i, l)

            if f.hidden ~= true then

                if f.type == 0 then
                    rfsuite.app.ui.fieldStaticText(i)
                elseif f.table or f.type == 1 then
                    rfsuite.app.ui.fieldChoice(i)
                elseif f.type == 2 then
                    rfsuite.app.ui.fieldNumber(i)
                elseif f.type == 3 then
                    rfsuite.app.ui.fieldText(i)
                else
                    rfsuite.app.ui.fieldNumber(i)
                end

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
                            rfsuite.app.ui.openPageHelp(help.help["table"][rfsuite.rateProfile], section)
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

    local qr

    local message = ""

    -- wrap text because of image on right
    for k, v in ipairs(txtData) do message = message .. v .. "\r\n\r\n" end

    local buttons = {{
        label = "CLOSE",
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = config.lcdWidth,
        title = "Help - " .. rfsuite.app.lastTitle,
        message = message,
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()

            local w = config.lcdWidth
            local h = config.lcdHeight
            local left = w * 0.75

        end,
        options = TEXT_LEFT
    })

end


return ui
