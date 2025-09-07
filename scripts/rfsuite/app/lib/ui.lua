--[[
  Copyright (C) Rotorflight Project

  License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License version 3 as published by the Free
  Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  Note: Some icons sourced from https://www.flaticon.com/
]]--

local ui = {}

local arg   = { ... }
local config = arg[1]
local i18n  = rfsuite.i18n.get

--------------------------------------------------------------------------------
-- Progress dialogs
--------------------------------------------------------------------------------

-- Show a progress dialog (defaults: "Loading" / "Loading data from flight controller...").
function ui.progressDisplay(title, message, speed)
    if rfsuite.app.dialogs.progressDisplay then return end

    title   = title   or i18n("app.msg_loading")
    message = message or i18n("app.msg_loading_from_fbl")


    if speed then
        rfsuite.app.dialogs.progressSpeed = true
    else
        rfsuite.app.dialogs.progressSpeed = false
    end

    rfsuite.app.dialogs.progressDisplay   = true
    rfsuite.app.dialogs.progressWatchDog  = os.clock()
    rfsuite.app.dialogs.progress = form.openProgressDialog({
        title   = title,
        message = message,
        close   = function() end,
        wakeup  = function()
            local app = rfsuite.app

            app.dialogs.progress:value(app.dialogs.progressCounter)

            local mult = 1
            if app.dialogs.progressSpeed then
                mult = 2
            end

            local isProcessing = (app.Page and app.Page.apidata and app.Page.apidata.apiState and app.Page.apidata.apiState.isProcessing) or false
            local apiV = tostring(rfsuite.session.apiVersion)

            if not app.triggers.closeProgressLoader then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (2 * mult)
                if app.dialogs.progressCounter > 50 and rfsuite.session.apiVersion and not rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiV) then
                    print("No API version yet")
                end
            elseif isProcessing then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (3 * mult)
            elseif app.triggers.closeProgressLoader and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue:isProcessed() then   -- this is the one we normally catch
                app.dialogs.progressCounter = app.dialogs.progressCounter + (15 * mult)
                if app.dialogs.progressCounter >= 100 then
                    app.dialogs.progress:close()
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                end
            elseif app.triggers.closeProgressLoader and  app.triggers.closeProgressLoaderNoisProcessed then   -- an oddball for things where we dont want to check against isProcessed
                app.dialogs.progressCounter = app.dialogs.progressCounter + (15 * mult)
                if app.dialogs.progressCounter >= 100 then
                    app.dialogs.progress:close()
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = false
                    app.triggers.closeProgressLoaderNoisProcessed= false
                end
            end

            -- Timeout (hard timeout)
            if app.dialogs.progressWatchDog
               and rfsuite.tasks.msp
               and (os.clock() - app.dialogs.progressWatchDog) > tonumber(rfsuite.tasks.msp.protocol.pageReqTimeout) 
               and app.dialogs.progressDisplay == true then
                app.audio.playTimeout = true
                app.dialogs.progress:message(i18n("app.error_timed_out"))
                app.dialogs.progress:closeAllowed(true)
                app.dialogs.progress:value(100)
                app.Page   = app.PageTmp
                app.PageTmp = nil
                app.dialogs.progressCounter = 0
                app.dialogs.progressSpeed = false
                app.dialogs.progressDisplay = false
            end

            if not rfsuite.tasks.msp  then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (2 * mult)
                if app.dialogs.progressCounter >= 100 then
                    app.dialogs.progress:close()
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.dialogs.progressSpeed = false
                end
            end

        end
    })

    rfsuite.app.dialogs.progressCounter = 0
    rfsuite.app.dialogs.progress:value(0)
    rfsuite.app.dialogs.progress:closeAllowed(false)
end

-- Show a "Saving…" progress dialog.
function ui.progressDisplaySave(message)
    local app = rfsuite.app

    rfsuite.app.dialogs.saveDisplay  = true
    rfsuite.app.dialogs.saveWatchDog = os.clock()

    local msg = ({
        [app.pageStatus.saving]      = "app.msg_saving_settings",
        [app.pageStatus.eepromWrite] = "app.msg_saving_settings",
        [app.pageStatus.rebooting]   = "app.msg_rebooting"
    })[app.pageState]

    if not message then message = i18n(msg) end
    local title = i18n("app.msg_saving")

    rfsuite.app.dialogs.save = form.openProgressDialog({
        title   = title,
        message = message,
        close   = function() end,
        wakeup  = function()
            local app = rfsuite.app

            app.dialogs.save:value(app.dialogs.saveProgressCounter)

            local isProcessing = (app.Page and app.Page.apidata and app.Page.apidata.apiState and app.Page.apidata.apiState.isProcessing) or false

            if not app.dialogs.saveProgressCounter then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 1
            elseif isProcessing then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 3                     
            elseif app.triggers.closeSaveFake then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5
                if app.dialogs.saveProgressCounter >= 100 then
                    app.triggers.closeSaveFake      = false
                    app.dialogs.saveProgressCounter = 0
                    app.dialogs.saveDisplay         = false
                    app.dialogs.saveWatchDog        = nil
                    app.dialogs.save:close()
                end           
            elseif rfsuite.tasks.msp.mspQueue:isProcessed() then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 15
                if app.dialogs.saveProgressCounter >= 100 then
                    app.dialogs.save:close()
                    app.dialogs.saveDisplay         = false
                    app.dialogs.saveProgressCounter = 0
                    app.triggers.closeSave          = false
                    app.triggers.isSaving           = false
                end
            else
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 2
            end

            local timeout = tonumber(rfsuite.tasks.msp.protocol.saveTimeout + 5)
            if (app.dialogs.saveWatchDog and (os.clock() - app.dialogs.saveWatchDog) > timeout)
               or (app.dialogs.saveProgressCounter > 120 and rfsuite.tasks.msp.mspQueue:isProcessed()) 
               and app.dialogs.saveDisplay == true then

                app.audio.playTimeout = true
                app.dialogs.save:message(i18n("app.error_timed_out"))
                app.dialogs.save:closeAllowed(true)
                app.dialogs.save:value(100)
                app.dialogs.saveProgressCounter = 0
                app.dialogs.saveDisplay         = false
                app.triggers.isSaving           = false
                app.Page   = app.PageTmp
                app.PageTmp = nil
            end
        end
    })

    rfsuite.app.dialogs.save:value(0)
    rfsuite.app.dialogs.save:closeAllowed(false)
end

-- Is any progress-related dialog showing?
function ui.progressDisplayIsActive()
    return rfsuite.app.dialogs.progressDisplay
        or rfsuite.app.dialogs.saveDisplay
        or rfsuite.app.dialogs.progressDisplayEsc
        or rfsuite.app.dialogs.nolinkDisplay
        or rfsuite.app.dialogs.badversionDisplay
end

--------------------------------------------------------------------------------
-- Enable/disable fields
--------------------------------------------------------------------------------

function ui.disableAllFields()
    for i = 1, #rfsuite.app.formFields do
        local field = rfsuite.app.formFields[i]
        if type(field) == "userdata" then field:enable(false) end
    end
end

function ui.enableAllFields()
    for _, field in ipairs(rfsuite.app.formFields) do
        if type(field) == "userdata" then field:enable(true) end
    end
end

function ui.disableAllNavigationFields()
    for _, v in pairs(rfsuite.app.formNavigationFields) do
        v:enable(false)
    end
end

function ui.enableAllNavigationFields()
    for _, v in pairs(rfsuite.app.formNavigationFields) do
        v:enable(true)
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

--------------------------------------------------------------------------------
-- Main menu
--------------------------------------------------------------------------------

-- Open main menu.
function ui.openMainMenu()
    rfsuite.app.formFields         = {}
    rfsuite.app.formFieldsOffline  = {}
    rfsuite.app.formFieldsBGTask   = {}
    rfsuite.app.formLines          = {}
    rfsuite.app.lastLabel          = nil
    rfsuite.app.isOfflinePage      = false

    if rfsuite.tasks.msp then
        rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    end

    rfsuite.app.gfx_buttons["mainmenu"] = {}
    rfsuite.app.lastMenu = nil

    -- Clear old icons.
    for k in pairs(rfsuite.app.gfx_buttons) do
        if k ~= "mainmenu" then rfsuite.app.gfx_buttons[k] = nil end
    end

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState          = rfsuite.app.uiStatus.mainMenu

    form.clear()

    rfsuite.app.lastIdx   = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    ESC = {}

    -- Icon size
    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    -- Dimensions
    local w, h = lcd.getWindowSize()
    local windowWidth  = w
    local windowHeight = h

    local buttonW, buttonH, padding, numPerRow

    if rfsuite.preferences.general.iconsize == 0 then
        padding   = rfsuite.app.radio.buttonPaddingSmall
        buttonW   = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH   = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    elseif rfsuite.preferences.general.iconsize == 1 then
        padding   = rfsuite.app.radio.buttonPaddingSmall
        buttonW   = rfsuite.app.radio.buttonWidthSmall
        buttonH   = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    elseif rfsuite.preferences.general.iconsize == 2 then
        padding   = rfsuite.app.radio.buttonPadding
        buttonW   = rfsuite.app.radio.buttonWidth
        buttonH   = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    rfsuite.app.gfx_buttons["mainmenu"] = rfsuite.app.gfx_buttons["mainmenu"] or {}
    rfsuite.preferences.menulastselected["mainmenu"] =
        rfsuite.preferences.menulastselected["mainmenu"] or 1

    local Menu = assert(rfsuite.compiler.loadfile("app/modules/sections.lua"))()

    local lc, bx, y = 0, 0, 0

    local header = form.addLine("Configuration")

    for pidx, pvalue in ipairs(Menu) do
        if not pvalue.developer then
            rfsuite.app.formFieldsOffline[pidx] = pvalue.offline or false
            rfsuite.app.formFieldsBGTask[pidx] = pvalue.bgtask or false

            if pvalue.newline then
                lc = 0
                form.addLine("System")
            end

            if lc == 0 then
                y = form.height() +
                    ((rfsuite.preferences.general.iconsize == 2) and rfsuite.app.radio.buttonPadding
                                                                  or rfsuite.app.radio.buttonPaddingSmall)
            end

            bx = (buttonW + padding) * lc

            if rfsuite.preferences.general.iconsize ~= 0 then
                rfsuite.app.gfx_buttons["mainmenu"][pidx] =
                    rfsuite.app.gfx_buttons["mainmenu"][pidx] or lcd.loadMask(pvalue.image)
            else
                rfsuite.app.gfx_buttons["mainmenu"][pidx] = nil
            end

            rfsuite.app.formFields[pidx] = form.addButton(line, {
                x = bx, y = y, w = buttonW, h = buttonH
            }, {
                text    = pvalue.title,
                icon    = rfsuite.app.gfx_buttons["mainmenu"][pidx],
                options = FONT_S,
                paint   = function() end,
                press   = function()
                    rfsuite.preferences.menulastselected["mainmenu"] = pidx
                    local speed = false
                    if pvalue.loaderspeed then speed = true end
                    rfsuite.app.ui.progressDisplay(nil,nil,speed)
                    if pvalue.module then
                        rfsuite.app.isOfflinePage = true
                        rfsuite.app.ui.openPage(pidx, pvalue.title, pvalue.module .. "/" .. pvalue.script)
                    else
                        rfsuite.app.ui.openMainMenuSub(pvalue.id)
                    end
                end
            })

            if pvalue.disabled then
                rfsuite.app.formFields[pidx]:enable(false)
            end

            if rfsuite.preferences.menulastselected["mainmenu"] == pidx then
                rfsuite.app.formFields[pidx]:focus()
            end

            lc = lc + 1
            if lc == numPerRow then lc = 0 end
        end
    end

    rfsuite.app.triggers.closeProgressLoader = true
    collectgarbage()
    rfsuite.utils.reportMemoryUsage("MainMenuSub")
end

-- Open a sub-section of the main menu.
function ui.openMainMenuSub(activesection)
    rfsuite.app.formFields        = {}
    rfsuite.app.formFieldsOffline = {}
    rfsuite.app.formLines         = {}
    rfsuite.app.lastLabel         = nil
    rfsuite.app.isOfflinePage     = false
    rfsuite.app.gfx_buttons[activesection] = {}
    rfsuite.app.lastMenu = activesection

    -- Clear old icons.
    for k in pairs(rfsuite.app.gfx_buttons) do
        if k ~= activesection then rfsuite.app.gfx_buttons[k] = nil end
    end

    -- Hard exit on error.
    if not rfsuite.utils.ethosVersionAtLeast(config.ethosVersion) then return end

    local MainMenu = rfsuite.app.MainMenu

    -- Clear navigation vars.
    rfsuite.app.lastIdx   = nil
    rfsuite.app.lastTitle = nil
    rfsuite.app.lastScript = nil
    rfsuite.session.lastPage = nil
    rfsuite.app.triggers.isReady             = false
    rfsuite.app.uiState                      = rfsuite.app.uiStatus.mainMenu
    rfsuite.app.triggers.disableRssiTimeout  = false

    rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize) or 1

    local buttonW, buttonH, padding, numPerRow

    if rfsuite.preferences.general.iconsize == 0 then
        padding   = rfsuite.app.radio.buttonPaddingSmall
        buttonW   = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH   = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    elseif rfsuite.preferences.general.iconsize == 1 then
        padding   = rfsuite.app.radio.buttonPaddingSmall
        buttonW   = rfsuite.app.radio.buttonWidthSmall
        buttonH   = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    elseif rfsuite.preferences.general.iconsize == 2 then
        padding   = rfsuite.app.radio.buttonPadding
        buttonW   = rfsuite.app.radio.buttonWidth
        buttonH   = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    form.clear()

    rfsuite.app.gfx_buttons[activesection] = rfsuite.app.gfx_buttons[activesection] or {}
    rfsuite.preferences.menulastselected[activesection] =
        rfsuite.preferences.menulastselected[activesection] or 1

    for idx, section in ipairs(MainMenu.sections) do
        if section.id == activesection then
            local w, h = lcd.getWindowSize()
            local windowWidth, windowHeight = w, h
            local padding = rfsuite.app.radio.buttonPadding

            form.addLine(section.title)

            local x = windowWidth - 110 -- 100 + 10 padding
            rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {
                x = x, y = rfsuite.app.radio.linePaddingTop, w = 100, h = rfsuite.app.radio.navbuttonHeight
            }, {
                text    = "MENU",
                icon    = nil,
                options = FONT_S,
                paint   = function() end,
                press   = function()
                    rfsuite.app.lastIdx = nil
                    rfsuite.session.lastPage = nil
                    if rfsuite.app.Page and rfsuite.app.Page.onNavMenu then
                        rfsuite.app.Page.onNavMenu(rfsuite.app.Page)
                    end
                    rfsuite.app.ui.openMainMenu()
                end
            })
            rfsuite.app.formNavigationFields['menu']:focus()

            local lc, y = 0, 0

            for pidx, page in ipairs(MainMenu.pages) do
                if page.section == idx then
                local hideEntry =
                    (page.ethosversion and not rfsuite.utils.ethosVersionAtLeast(page.ethosversion))
                    or (page.mspversion and rfsuite.utils.apiVersionCompare("<", page.mspversion))
                    or (page.developer and not rfsuite.preferences.developer.devtools)

                    local offline = page.offline
                    rfsuite.app.formFieldsOffline[pidx] = offline or false

                    if not hideEntry then
                        if lc == 0 then
                            y = form.height() +
                                ((rfsuite.preferences.general.iconsize == 2) and rfsuite.app.radio.buttonPadding
                                                                              or rfsuite.app.radio.buttonPaddingSmall)
                        end

                        local x = (buttonW + padding) * lc

                        if rfsuite.preferences.general.iconsize ~= 0 then
                            rfsuite.app.gfx_buttons[activesection][pidx] =
                                rfsuite.app.gfx_buttons[activesection][pidx]
                                or lcd.loadMask("app/modules/" .. page.folder .. "/" .. page.image)
                        else
                            rfsuite.app.gfx_buttons[activesection][pidx] = nil
                        end

                        rfsuite.app.formFields[pidx] = form.addButton(line, {
                            x = x, y = y, w = buttonW, h = buttonH
                        }, {
                            text    = page.title,
                            icon    = rfsuite.app.gfx_buttons[activesection][pidx],
                            options = FONT_S,
                            paint   = function() end,
                            press   = function()
                                rfsuite.preferences.menulastselected[activesection] = pidx
                                local speed = false
                                if page.loaderspeed or section.loaderspeed then speed = true end
                                rfsuite.app.ui.progressDisplay(nil,nil,speed)
                                rfsuite.app.isOfflinePage = offline
                                rfsuite.app.ui.openPage(pidx, page.title, page.folder .. "/" .. page.script)
                            end
                        })

                        if rfsuite.preferences.menulastselected[activesection] == pidx then
                            rfsuite.app.formFields[pidx]:focus()
                        end

                        lc = (lc + 1) % numPerRow
                    end
                end
            end
        end
    end

    rfsuite.app.triggers.closeProgressLoader = true
    collectgarbage()
    rfsuite.utils.reportMemoryUsage("MainMenuSub")
end

--------------------------------------------------------------------------------
-- Labels / fields
--------------------------------------------------------------------------------

-- Find a label by id on a page table.
function ui.getLabel(id, page)
    if id == nil then return nil end
    for i = 1, #page do
        if page[i].label == id then return page[i] end
    end
    return nil
end

-- Boolean field.
function ui.fieldBoolean(i)

    -- we dont have boolean fields in ethos 1.70 and below because they candidate
    -- have dynamic values
    if utils.ethosVersionAtLeast(1,7,0) then
        ui.fieldChoice(i)
        return
    end

    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields
    local radioText  = app.radio.text

    local posText, posField

    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then f.t = f.t2 end
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
    else
        if f.t then
            if radioText == 2 and f.t2 then f.t = f.t2 end
            if f.label then f.t = "        " .. f.t end
        end
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        formLines[rfsuite.app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    local tbldata = f.table and rfsuite.app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}

    formFields[i] = form.addBooleanField(
        formLines[rfsuite.app.formLineCnt],
        posField,
        function()
            if not fields or not fields[i] then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            if fields[i].value == 0 then
                return false
            else
                return true    
            end
        end,
        function(value)
            if value == false then value = 0 else value = 1 end
            if f.postEdit then f.postEdit(page, value) end
            if f.onChange then f.onChange(page, value) end
            f.value = rfsuite.app.utils.saveFieldValue(fields[i], value)
        end
    )

    if f.disable then formFields[i]:enable(false) end
end

-- Choice field.
function ui.fieldChoice(i)
    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields
    local radioText  = app.radio.text

    local posText, posField

    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then f.t = f.t2 end
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
    else
        if f.t then
            if radioText == 2 and f.t2 then f.t = f.t2 end
            if f.label then f.t = "        " .. f.t end
        end
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        formLines[rfsuite.app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    local tbldata = f.table and rfsuite.app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}

    formFields[i] = form.addChoiceField(
        formLines[rfsuite.app.formLineCnt],
        posField,
        tbldata,
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

    if f.disable then formFields[i]:enable(false) end
end

-- Number field.
function ui.fieldNumber(i)
    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields

    local posField, posText

    if f.inline and f.inline >= 1 and f.label then
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        formLines[rfsuite.app.formLineCnt] = form.addLine(f.t)
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

    formFields[i] = form.addNumberField(
        formLines[rfsuite.app.formLineCnt],
        posField,
        minValue,
        maxValue,
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

    if f.onFocus  then currentField:onFocus(function() f.onFocus(page) end) end

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
    if f.unit     then currentField:suffix(f.unit)       end
    if f.step     then currentField:step(f.step)         end
    if f.disable  then currentField:enable(false)        end

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

-- Static text field.
function ui.fieldStaticText(i)
    local app         = rfsuite.app
    local page        = app.Page
    local fields      = page.fields
    local f           = fields[i]
    local formLines   = app.formLines
    local formFields  = app.formFields
    local radioText   = app.radio.text

    local posText, posField

    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then f.t = f.t2 end
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
    else
        if radioText == 2 and f.t2 then f.t = f.t2 end
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        formLines[rfsuite.app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    -- if HideMe == true then ... end (kept as comment in original)

    formFields[i] = form.addStaticText(
        formLines[rfsuite.app.formLineCnt],
        posField,
        rfsuite.app.utils.getFieldValue(fields[i])
    )

    local currentField = formFields[i]
    if f.onFocus  then currentField:onFocus(function() f.onFocus(page) end) end
    if f.decimals then currentField:decimals(f.decimals) end
    if f.unit     then currentField:suffix(f.unit)       end
    if f.step     then currentField:step(f.step)         end
end

-- Text field.
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
        if radioText == 2 and f.t2 then f.t = f.t2 end
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
    else
        if radioText == 2 and f.t2 then f.t = f.t2 end
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        formLines[rfsuite.app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    formFields[i] = form.addTextField(
        formLines[rfsuite.app.formLineCnt],
        posField,
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
    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end
    if f.disable then currentField:enable(false) end

    if f.help and app.fieldHelpTxt and app.fieldHelpTxt[f.help] and app.fieldHelpTxt[f.help].t then
        currentField:help(app.fieldHelpTxt[f.help].t)
    end

    if f.instantChange == false then
        currentField:enableInstantChange(false)
    else
        currentField:enableInstantChange(true)
    end
end

-- Label/header helper.
function ui.fieldLabel(f, i, l)
    local app = rfsuite.app

    if f.t then
        if f.t2    then f.t = f.t2 end
        if f.label then f.t = "        " .. f.t end
    end

    if f.label then
        local label      = app.ui.getLabel(f.label, l)
        local labelValue = label.t
        if label.t2 then labelValue = label.t2 end
        local labelName = f.t and labelValue or "unknown"

        if f.label ~= rfsuite.app.lastLabel then
            label.type = label.type or 0
            rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
            app.formLines[rfsuite.app.formLineCnt] = form.addLine(labelName)
            form.addStaticText(app.formLines[rfsuite.app.formLineCnt], nil, "")
            rfsuite.app.lastLabel = f.label
        end
    end
end

--------------------------------------------------------------------------------
-- Page header & navigation
--------------------------------------------------------------------------------

function ui.fieldHeader(title)
    local app       = rfsuite.app
    local radio     = app.radio
    local formFields = app.formFields
    local lcdWidth  = rfsuite.app.lcdWidth

    if not title then title = "No Title" end

    local w, _ = lcd.getWindowSize()
    local padding  = 5
    local colStart = math.floor(w * 59.4 / 100)
    if radio.navButtonOffset then colStart = colStart - radio.navButtonOffset end

    local buttonW = radio.buttonWidth and radio.menuButtonWidth or ((w - colStart) / 3 - padding)
    local buttonH = radio.navbuttonHeight

    formFields['menu'] =
        form.addLine("")

    formFields['title'] = form.addStaticText(
        formFields['menu'],
        { x = 0, y = radio.linePaddingTop, w = lcdWidth, h = radio.navbuttonHeight },
        title
    )

    app.ui.navigationButtons(w - 5, radio.linePaddingTop, buttonW, buttonH)
end

function ui.openPageRefresh(idx, title, script, extra1, extra2, extra3, extra5, extra6)
    rfsuite.app.triggers.isReady = false
end

--------------------------------------------------------------------------------
-- Help caching
--------------------------------------------------------------------------------

ui._helpCache = ui._helpCache or {}

local function getHelpData(section)
    if ui._helpCache[section] == nil then
        local helpPath = "app/modules/" .. section .. "/help.lua"
        if rfsuite.utils.file_exists(helpPath) then
            local ok, helpData = pcall(function()
                return assert(rfsuite.compiler.loadfile(helpPath))()
            end)
            ui._helpCache[section] = (ok and type(helpData) == "table") and helpData or false
        else
            ui._helpCache[section] = false
        end
    end
    return ui._helpCache[section] or nil
end

--------------------------------------------------------------------------------
-- Page opening
--------------------------------------------------------------------------------

function ui.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)
    -- Global UI state; clear form data.
    rfsuite.app.uiState          = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false
    rfsuite.app.formFields       = {}
    rfsuite.app.formLines        = {}
    rfsuite.app.lastLabel        = nil

    -- Load module.
    local modulePath = "app/modules/" .. script
    rfsuite.app.Page = assert(rfsuite.compiler.loadfile(modulePath))(idx)

    -- Load help (if present).
    local section  = script:match("([^/]+)")
    local helpData = getHelpData(section)
    rfsuite.app.fieldHelpTxt = helpData and helpData.fields or nil

    -- Module-specific openPage?
    if rfsuite.app.Page.openPage then
        rfsuite.app.Page.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)
        rfsuite.utils.reportMemoryUsage(title)
        return
    end

    -- Fallback rendering.
    rfsuite.app.lastIdx   = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    form.clear()
    rfsuite.session.lastPage = script

    local pageTitle = rfsuite.app.Page.pageTitle or title
    rfsuite.app.ui.fieldHeader(pageTitle)

    if rfsuite.app.Page.headerLine then
        local headerLine = form.addLine("")
        form.addStaticText(headerLine, {
            x = 0, y = rfsuite.app.radio.linePaddingTop,
            w = rfsuite.app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight
        }, rfsuite.app.Page.headerLine)
    end

    rfsuite.app.formLineCnt = 0

    rfsuite.utils.log("Merging form data from mspapi", "debug")
    rfsuite.app.Page.fields = rfsuite.app.Page.apidata.formdata.fields
    rfsuite.app.Page.labels = rfsuite.app.Page.apidata.formdata.labels

    if rfsuite.app.Page.fields then
        for i, field in ipairs(rfsuite.app.Page.fields) do
            local label   = rfsuite.app.Page.labels
            if rfsuite.session.apiVersion == nil then return end

            local valid =
                (field.apiversion    == nil or rfsuite.utils.apiVersionCompare(">=", field.apiversion))    and
                (field.apiversionlt  == nil or rfsuite.utils.apiVersionCompare("<",  field.apiversionlt))  and
                (field.apiversiongt  == nil or rfsuite.utils.apiVersionCompare(">",  field.apiversiongt))  and
                (field.apiversionlte == nil or rfsuite.utils.apiVersionCompare("<=", field.apiversionlte)) and
                (field.apiversiongte == nil or rfsuite.utils.apiVersionCompare(">=", field.apiversiongte)) and
                (field.enablefunction == nil or field.enablefunction())

            if field.hidden ~= true and valid then
                rfsuite.app.ui.fieldLabel(field, i, label)
                if     field.type == 0 then rfsuite.app.ui.fieldStaticText(i)
                elseif field.table or field.type == 1 then rfsuite.app.ui.fieldChoice(i)
                elseif field.type == 2 then rfsuite.app.ui.fieldNumber(i)
                elseif field.type == 3 then rfsuite.app.ui.fieldText(i)
                elseif field.type == 5 then rfsuite.app.ui.fieldBoolean(i)
                else                         rfsuite.app.ui.fieldNumber(i)
                end
            else
                rfsuite.app.formFields[i] = {}
            end
        end
    end

    rfsuite.utils.reportMemoryUsage(title)
end

-- Navigation buttons (Menu / Save / Reload / Tool / Help).
function ui.navigationButtons(x, y, w, h)
    local xOffset    = 0
    local padding    = 5
    local wS         = w - (w * 20) / 100
    local helpOffset = 0
    local toolOffset = 0
    local reloadOffset = 0
    local saveOffset   = 0
    local menuOffset   = 0

    local navButtons
    if rfsuite.app.Page.navButtons == nil then
        navButtons = { menu = true, save = true, reload = true, help = true }
    else
        navButtons = rfsuite.app.Page.navButtons
    end

    -- Precompute offsets to keep focus order correct in Ethos.
    if navButtons.help   ~= nil and navButtons.help   == true then xOffset = xOffset + wS + padding end
    helpOffset = x - xOffset

    if navButtons.tool   ~= nil and navButtons.tool   == true then xOffset = xOffset + wS + padding end
    toolOffset = x - xOffset

    if navButtons.reload ~= nil and navButtons.reload == true then xOffset = xOffset + w + padding  end
    reloadOffset = x - xOffset

    if navButtons.save   ~= nil and navButtons.save   == true then xOffset = xOffset + w + padding  end
    saveOffset = x - xOffset

    if navButtons.menu   ~= nil and navButtons.menu   == true then xOffset = xOffset + w + padding  end
    menuOffset = x - xOffset

    -- MENU
    if navButtons.menu == true then
        rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {
            x = menuOffset, y = y, w = w, h = h
        }, {
            text    = i18n("app.navigation_menu"),
            icon    = nil,
            options = FONT_S,
            paint   = function() end,
            press   = function()
                if rfsuite.app.Page and rfsuite.app.Page.onNavMenu then
                    rfsuite.app.Page.onNavMenu(rfsuite.app.Page)
                elseif rfsuite.app.lastMenu ~= nil then
                    rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)
                else
                    rfsuite.app.ui.openMainMenu()
                end
            end
        })
        rfsuite.app.formNavigationFields['menu']:focus()
    end

    -- SAVE
    if navButtons.save == true then
        rfsuite.app.formNavigationFields['save'] = form.addButton(line, {
            x = saveOffset, y = y, w = w, h = h
        }, {
            text    = i18n("app.navigation_save"),
            icon    = nil,
            options = FONT_S,
            paint   = function() end,
            press   = function()
                if rfsuite.app.Page and rfsuite.app.Page.onSaveMenu then
                    rfsuite.app.Page.onSaveMenu(rfsuite.app.Page)
                else
                    rfsuite.app.triggers.triggerSave = true
                end
            end
        })
    end

    -- RELOAD
    if navButtons.reload == true then
        rfsuite.app.formNavigationFields['reload'] = form.addButton(line, {
            x = reloadOffset, y = y, w = w, h = h
        }, {
            text    = i18n("app.navigation_reload"),
            icon    = nil,
            options = FONT_S,
            paint   = function() end,
            press   = function()
                if rfsuite.app.Page and rfsuite.app.Page.onReloadMenu then
                    rfsuite.app.Page.onReloadMenu(rfsuite.app.Page)
                else
                    rfsuite.app.triggers.triggerReload = true
                end
                return true
            end
        })
    end

    -- TOOL
    if navButtons.tool == true then
        rfsuite.app.formNavigationFields['tool'] = form.addButton(line, {
            x = toolOffset, y = y, w = wS, h = h
        }, {
            text    = i18n("app.navigation_tools"),
            icon    = nil,
            options = FONT_S,
            paint   = function() end,
            press   = function()
                rfsuite.app.Page.onToolMenu()
            end
        })
    end

    -- HELP
    if navButtons.help == true then
        local section = rfsuite.app.lastScript:match("([^/]+)")
        local script  = rfsuite.app.lastScript:match("/([^/]+)%.lua$")

        local help = getHelpData(section)
        if help then
            rfsuite.app.formNavigationFields['help'] = form.addButton(line, {
                x = helpOffset, y = y, w = wS, h = h
            }, {
                text    = i18n("app.navigation_help"),
                icon    = nil,
                options = FONT_S,
                paint   = function() end,
                press   = function()
                    if rfsuite.app.Page and rfsuite.app.Page.onHelpMenu then
                        rfsuite.app.Page.onHelpMenu(rfsuite.app.Page)
                    else
                        if help.help[script] then
                            rfsuite.app.ui.openPageHelp(help.help[script], section)
                        else
                            rfsuite.app.ui.openPageHelp(help.help['default'], section)
                        end
                    end
                end
            })
        else
            rfsuite.app.formNavigationFields['help'] = form.addButton(line, {
                x = helpOffset, y = y, w = wS, h = h
            }, {
                text    = i18n("app.navigation_help"),
                icon    = nil,
                options = FONT_S,
                paint   = function() end,
                press   = function() end
            })
            rfsuite.app.formNavigationFields['help']:enable(false)
        end
    end
end

-- Open a help dialog with given text data.
function ui.openPageHelp(txtData, section)
    local message = table.concat(txtData, "\r\n\r\n")
    form.openDialog({
        width   = rfsuite.app.lcdWidth,
        title   = "Help - " .. rfsuite.app.lastTitle,
        message = message,
        buttons = { { label = i18n("app.btn_close"), action = function() return true end } },
        options = TEXT_LEFT
    })
end

--------------------------------------------------------------------------------
-- API attribute injection
--------------------------------------------------------------------------------

function ui.injectApiAttributes(formField, f, v)
    local utils = rfsuite.utils
    local log   = utils.log

    if v.decimals and not f.decimals then
        if f.type ~= 1 then
            log("Injecting decimals: " .. v.decimals, "debug")
            f.decimals = v.decimals
            formField:decimals(v.decimals)
        end
    end

    if v.scale  and not f.scale  then log("Injecting scale: " .. v.scale,   "debug"); f.scale  = v.scale  end
    if v.mult   and not f.mult   then log("Injecting mult: " .. v.mult,     "debug"); f.mult   = v.mult   end
    if v.offset and not f.offset then log("Injecting offset: " .. v.offset, "debug"); f.offset = v.offset end

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
        if f.offset then f.min = f.min + f.offset end
        if f.type ~= 1 then
            log("Injecting min: " .. f.min, "debug")
            formField:minimum(f.min)
        end
    end

    if v.max and not f.max then
        f.max = v.max
        if f.offset then f.max = f.max + f.offset end
        if f.type ~= 1 then
            log("Injecting max: " .. f.max, "debug")
            formField:maximum(f.max)
        end
    end

    if v.default and not f.default then
        f.default = v.default
        if f.offset then f.default = f.default + f.offset end
        local default = f.default * rfsuite.app.utils.decimalInc(f.decimals)
        if f.mult then default = default * f.mult end
        local str = tostring(default)
        if str:match("%.0$") then default = math.ceil(default) end
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

    -- Force focus to ensure field updates.
    formField:focus(true)
end

return ui
