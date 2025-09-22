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
local preferences = rfsuite.preferences
local utils = rfsuite.utils
local tasks = rfsuite.tasks


--------------------------------------------------------------------------------
-- Progress dialogs
--------------------------------------------------------------------------------

-- Show a progress dialog (defaults: "Loading" / "Loading data from flight controller...").
function ui.progressDisplay(title, message, speed)

    local app = rfsuite.app

    if app.dialogs.progressDisplay then return end

    title   = title   or "@i18n(app.msg_loading)@"
    message = message or "@i18n(app.msg_loading_from_fbl)@"


    if speed then
        app.dialogs.progressSpeed = true
    else
        app.dialogs.progressSpeed = false
    end

    app.dialogs.progressDisplay   = true
    app.dialogs.progressWatchDog  = os.clock()
    app.dialogs.progress = form.openProgressDialog({
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
                if app.dialogs.progressCounter > 50 and rfsuite.session.apiVersion and not utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiV) then
                    print("No API version yet")
                end
            elseif isProcessing then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (3 * mult)
            elseif app.triggers.closeProgressLoader and tasks.msp and tasks.msp.mspQueue:isProcessed() then   -- this is the one we normally catch
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
               and tasks.msp
               and (os.clock() - app.dialogs.progressWatchDog) > tonumber(tasks.msp.protocol.pageReqTimeout) 
               and app.dialogs.progressDisplay == true then
                app.audio.playTimeout = true
                app.dialogs.progress:message("@i18n(app.error_timed_out)@")
                app.dialogs.progress:closeAllowed(true)
                app.dialogs.progress:value(100)
                app.Page   = app.PageTmp
                app.PageTmp = nil
                app.dialogs.progressCounter = 0
                app.dialogs.progressSpeed = false
                app.dialogs.progressDisplay = false
            end

            if not tasks.msp  then
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

    app.dialogs.progressCounter = 0
    app.dialogs.progress:value(0)
    app.dialogs.progress:closeAllowed(false)
end

-- Show a "Saving…" progress dialog.
-- Literal tags for the progress dialog "message" by page state
function ui.progressDisplaySave(message)
    local app = rfsuite.app

    app.dialogs.saveDisplay  = true
    app.dialogs.saveWatchDog = os.clock()


    local SAVE_MESSAGE_TAG = {
        [app.pageStatus.saving]      = "@i18n(app.msg_saving_settings)@",
        [app.pageStatus.eepromWrite] = "@i18n(app.msg_saving_settings)@",
        [app.pageStatus.rebooting]   = "@i18n(app.msg_rebooting)@",
    }

    -- If caller didn’t provide a message, pick the literal tag for the current state.
    -- Fallback defaults to "saving settings".
    local resolvedMessage = message or SAVE_MESSAGE_TAG[app.pageState] or "@i18n(app.msg_saving_settings)@"
    local title = "@i18n(app.msg_saving)@"

    app.dialogs.save = form.openProgressDialog({
        title   = title,
        message = resolvedMessage,
        close   = function() end,
        wakeup  = function()
            local app = rfsuite.app

            app.dialogs.save:value(app.dialogs.saveProgressCounter)

            local isProcessing = (app.Page and app.Page.apidata and app.Page.apidata.apiState and app.Page.apidata.apiState.isProcessing) or false

            -- initialize counter if nil
            if not app.dialogs.saveProgressCounter then
                app.dialogs.saveProgressCounter = 0
            end

            if isProcessing then
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
            elseif tasks.msp.mspQueue:isProcessed() then
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

            local timeout = tonumber(tasks.msp.protocol.saveTimeout + 5)
            if (app.dialogs.saveWatchDog and (os.clock() - app.dialogs.saveWatchDog) > timeout)
               or (app.dialogs.saveProgressCounter > 120 and tasks.msp.mspQueue:isProcessed())
               and app.dialogs.saveDisplay == true then

                app.audio.playTimeout = true
                app.dialogs.save:message("@i18n(app.error_timed_out)@")
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

    app.dialogs.save:value(0)
    app.dialogs.save:closeAllowed(false)
end


-- Is any progress-related dialog showing?
function ui.progressDisplayIsActive()

    local app = rfsuite.app

    return app.dialogs.progressDisplay
        or app.dialogs.saveDisplay
        or app.dialogs.progressDisplayEsc
        or app.dialogs.nolinkDisplay
        or app.dialogs.badversionDisplay
end

--------------------------------------------------------------------------------
-- Enable/disable fields
--------------------------------------------------------------------------------

function ui.disableAllFields()

    local app = rfsuite.app

    for i = 1, #app.formFields do
        local field = app.formFields[i]
        if type(field) == "userdata" then field:enable(false) end
    end
end

function ui.enableAllFields()

    local app = rfsuite.app

    for _, field in ipairs(app.formFields) do
        if type(field) == "userdata" then field:enable(true) end
    end
end

function ui.disableAllNavigationFields()

    local app = rfsuite.app

    for _, v in pairs(app.formNavigationFields) do
        v:enable(false)
    end
end

function ui.enableAllNavigationFields()

    local app = rfsuite.app

    for _, v in pairs(app.formNavigationFields) do
        v:enable(true)
    end
end

function ui.enableNavigationField(x)

    local app = rfsuite.app

    local field = app.formNavigationFields[x]
    if field then field:enable(true) end
end

function ui.disableNavigationField(x)

    local app = rfsuite.app

    local field = app.formNavigationFields[x]
    if field then field:enable(false) end
end

--------------------------------------------------------------------------------
-- Main menu
--------------------------------------------------------------------------------

-- Open main menu.
function ui.openMainMenu()

    local app = rfsuite.app

    utils.reportMemoryUsage("app.openMainMenu", "start")

    app.formFields         = {}
    app.formFieldsOffline  = {}
    app.formFieldsBGTask   = {}
    app.formLines          = {}
    app.lastLabel          = nil
    app.isOfflinePage      = false
    app.Page               = nil
    app.PageTmp            = nil

    if tasks.msp then
        tasks.msp.protocol.mspIntervalOveride = nil
    end

    app.gfx_buttons["mainmenu"] = {}
    app.lastMenu = nil

    -- Clear old icons.
    for k in pairs(app.gfx_buttons) do
        if k ~= "mainmenu" then app.gfx_buttons[k] = nil end
    end

    app.triggers.isReady = false
    app.uiState          = app.uiStatus.mainMenu

    form.clear()

    app.lastIdx   = idx
    app.lastTitle = title
    app.lastScript = script

    -- Icon size
    if preferences.general.iconsize == nil or preferences.general.iconsize == "" then
        preferences.general.iconsize = 1
    else
        preferences.general.iconsize = tonumber(preferences.general.iconsize)
    end

    -- Dimensions
    local w, h = lcd.getWindowSize()
    local windowWidth  = w
    local windowHeight = h

    local buttonW, buttonH, padding, numPerRow

    if preferences.general.iconsize == 0 then
        padding   = app.radio.buttonPaddingSmall
        buttonW   = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH   = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    elseif preferences.general.iconsize == 1 then
        padding   = app.radio.buttonPaddingSmall
        buttonW   = app.radio.buttonWidthSmall
        buttonH   = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    elseif preferences.general.iconsize == 2 then
        padding   = app.radio.buttonPadding
        buttonW   = app.radio.buttonWidth
        buttonH   = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    app.gfx_buttons["mainmenu"] = app.gfx_buttons["mainmenu"] or {}
    preferences.menulastselected["mainmenu"] =
        preferences.menulastselected["mainmenu"] or 1

    local Menu = assert(rfsuite.compiler.loadfile("app/modules/sections.lua"))()

    local lc, bx, y = 0, 0, 0

    local header = form.addLine("Configuration")

    for pidx, pvalue in ipairs(Menu) do
        if not pvalue.developer then
            app.formFieldsOffline[pidx] = pvalue.offline or false
            app.formFieldsBGTask[pidx] = pvalue.bgtask or false

            if pvalue.newline then
                lc = 0
                form.addLine("System")
            end

            if lc == 0 then
                y = form.height() +
                    ((preferences.general.iconsize == 2) and app.radio.buttonPadding
                                                                  or app.radio.buttonPaddingSmall)
            end

            bx = (buttonW + padding) * lc

            if preferences.general.iconsize ~= 0 then
                app.gfx_buttons["mainmenu"][pidx] =
                    app.gfx_buttons["mainmenu"][pidx] or lcd.loadMask(pvalue.image)
            else
                app.gfx_buttons["mainmenu"][pidx] = nil
            end

            app.formFields[pidx] = form.addButton(line, {
                x = bx, y = y, w = buttonW, h = buttonH
            }, {
                text    = pvalue.title,
                icon    = app.gfx_buttons["mainmenu"][pidx],
                options = FONT_S,
                paint   = function() end,
                press   = function()
                    preferences.menulastselected["mainmenu"] = pidx
                    local speed = false
                    if pvalue.loaderspeed then speed = true end
                    app.ui.progressDisplay(nil,nil,speed)
                    if pvalue.module then
                        app.isOfflinePage = true
                        app.ui.openPage(pidx, pvalue.title, pvalue.module .. "/" .. pvalue.script)
                    else
                        app.ui.openMainMenuSub(pvalue.id)
                    end
                end
            })

            if pvalue.disabled then
                app.formFields[pidx]:enable(false)
            end

            if preferences.menulastselected["mainmenu"] == pidx then
                app.formFields[pidx]:focus()
            end

            lc = lc + 1
            if lc == numPerRow then lc = 0 end
        end
    end

    app.triggers.closeProgressLoader = true

    utils.reportMemoryUsage("app.openMainMenu", "end")
end

-- Open a sub-section of the main menu.
function ui.openMainMenuSub(activesection)

    local app = rfsuite.app

    utils.reportMemoryUsage("app.openMainMenuSub", "start")

    app.formFields        = {}
    app.formFieldsOffline = {}
    app.formLines         = {}
    app.lastLabel         = nil
    app.isOfflinePage     = false
    app.gfx_buttons[activesection] = {}
    app.lastMenu = activesection
    app.Page               = nil
    app.PageTmp            = nil

    -- Clear old icons.
    for k in pairs(app.gfx_buttons) do
        if k ~= activesection then app.gfx_buttons[k] = nil end
    end

    -- Hard exit on error.
    if not utils.ethosVersionAtLeast(config.ethosVersion) then return end

    local MainMenu = app.MainMenu

    -- Clear navigation vars.
    app.lastIdx   = nil
    app.lastTitle = nil
    app.lastScript = nil
    rfsuite.session.lastPage = nil
    app.triggers.isReady             = false
    app.uiState                      = app.uiStatus.mainMenu
    app.triggers.disableRssiTimeout  = false

    preferences.general.iconsize = tonumber(preferences.general.iconsize) or 1

    local buttonW, buttonH, padding, numPerRow

    if preferences.general.iconsize == 0 then
        padding   = app.radio.buttonPaddingSmall
        buttonW   = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH   = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    elseif preferences.general.iconsize == 1 then
        padding   = app.radio.buttonPaddingSmall
        buttonW   = app.radio.buttonWidthSmall
        buttonH   = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    elseif preferences.general.iconsize == 2 then
        padding   = app.radio.buttonPadding
        buttonW   = app.radio.buttonWidth
        buttonH   = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    form.clear()

    app.gfx_buttons[activesection] = app.gfx_buttons[activesection] or {}
    preferences.menulastselected[activesection] =
        preferences.menulastselected[activesection] or 1

    for idx, section in ipairs(MainMenu.sections) do
        if section.id == activesection then
            local w, h = lcd.getWindowSize()
            local windowWidth, windowHeight = w, h
            local padding = app.radio.buttonPadding

            form.addLine(section.title)

            local x = windowWidth - 110 -- 100 + 10 padding
            app.formNavigationFields['menu'] = form.addButton(line, {
                x = x, y = app.radio.linePaddingTop, w = 100, h = app.radio.navbuttonHeight
            }, {
                text    = "MENU",
                icon    = nil,
                options = FONT_S,
                paint   = function() end,
                press   = function()
                    app.lastIdx = nil
                    rfsuite.session.lastPage = nil
                    if app.Page and app.Page.onNavMenu then
                        app.Page.onNavMenu(app.Page)
                    end
                    app.ui.openMainMenu()
                end
            })
            app.formNavigationFields['menu']:focus()

            local lc, y = 0, 0

            for pidx, page in ipairs(MainMenu.pages) do
                if page.section == idx then
                local hideEntry =
                    (page.ethosversion and not utils.ethosVersionAtLeast(page.ethosversion))
                    or (page.mspversion and utils.apiVersionCompare("<", page.mspversion))
                    or (page.developer and not preferences.developer.devtools)

                    local offline = page.offline
                    app.formFieldsOffline[pidx] = offline or false

                    if not hideEntry then
                        if lc == 0 then
                            y = form.height() +
                                ((preferences.general.iconsize == 2) and app.radio.buttonPadding
                                                                              or app.radio.buttonPaddingSmall)
                        end

                        local x = (buttonW + padding) * lc

                        if preferences.general.iconsize ~= 0 then
                            app.gfx_buttons[activesection][pidx] =
                                app.gfx_buttons[activesection][pidx]
                                or lcd.loadMask("app/modules/" .. page.folder .. "/" .. page.image)
                        else
                            app.gfx_buttons[activesection][pidx] = nil
                        end

                        app.formFields[pidx] = form.addButton(line, {
                            x = x, y = y, w = buttonW, h = buttonH
                        }, {
                            text    = page.title,
                            icon    = app.gfx_buttons[activesection][pidx],
                            options = FONT_S,
                            paint   = function() end,
                            press   = function()
                                preferences.menulastselected[activesection] = pidx
                                local speed = false
                                if page.loaderspeed or section.loaderspeed then speed = true end
                                app.ui.progressDisplay(nil,nil,speed)
                                app.isOfflinePage = offline
                                app.ui.openPage(pidx, page.title, page.folder .. "/" .. page.script)
                            end
                        })

                        if preferences.menulastselected[activesection] == pidx then
                            app.formFields[pidx]:focus()
                        end

                        lc = (lc + 1) % numPerRow
                    end
                end
            end
        end
    end

    app.triggers.closeProgressLoader = true

    utils.reportMemoryUsage("app.openMainMenuSub", "end")
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
-- Single Boolean field with optional inversion when f.subtype == 1
function ui.fieldBoolean(i)
    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields
    local radioText  = app.radio.text

    -- Defensive guard: field must exist
    if not f then
        ui.disableAllFields()
        ui.disableAllNavigationFields()
        ui.enableNavigationField('menu')
        return
    end

    local invert = (f.subtype == 1)  -- your proposed switch

    local posText, posField

    -- Label / inline handling
    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then f.t = f.t2 end
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if f.t then
            if radioText == 2 and f.t2 then f.t = f.t2 end
            if f.label then f.t = "        " .. f.t end
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    -- Helper: decode stored numeric (0/1) -> UI boolean, honoring inversion
    local function decode()
        if not fields or not fields[i] then
            ui.disableAllFields()
            ui.disableAllNavigationFields()
            ui.enableNavigationField('menu')
            return nil
        end
        local v = (fields[i].value == 1) and 1 or 0
        if invert then v = (v == 1) and 0 or 1 end
        return (v == 1)
    end

    -- Helper: encode UI boolean -> stored numeric (0/1), honoring inversion
    local function encode(b)
        local v = b and 1 or 0
        if invert then v = (v == 1) and 0 or 1 end
        return v
    end

    formFields[i] = form.addBooleanField(
        formLines[app.formLineCnt],
        posField,
        function()
            return decode()
        end,
        function(valueBool)
            local value = encode(valueBool == true)
            if f.postEdit then f.postEdit(page, value) end
            if f.onChange then f.onChange(page, value) end
            f.value = app.utils.saveFieldValue(fields[i], value)
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
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if f.t then
            if radioText == 2 and f.t2 then f.t = f.t2 end
            if f.label then f.t = "        " .. f.t end
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    local tbldata = f.table and app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}

    formFields[i] = form.addChoiceField(
        formLines[app.formLineCnt],
        posField,
        tbldata,
        function()
            if not fields or not fields[i] then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            return app.utils.getFieldValue(fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page, value) end
            if f.onChange then f.onChange(page, value) end
            f.value = app.utils.saveFieldValue(fields[i], value)
        end
    )

    if f.disable then formFields[i]:enable(false) end
end

-- Slider field.
function ui.fieldSlider(i)
    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields

    local posField, posText

    if f.inline and f.inline >= 1 and f.label then
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addSliderField(
        formLines[app.formLineCnt],
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
            return app.utils.getFieldValue(page.fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(page.fields[i], value)
        end
    )

    local currentField = formFields[i]

    if f.onFocus  then currentField:onFocus(function() f.onFocus(page) end) end

    if f.decimals then currentField:decimals(f.decimals) end
    if f.step     then currentField:step(f.step)         end
    if f.disable  then currentField:enable(false)        end

    if f.help or f.apikey then
        if not f.help and f.apikey then f.help = f.apikey end
        if app.fieldHelpTxt and app.fieldHelpTxt[f.help] and app.fieldHelpTxt[f.help].t then
            currentField:help(app.fieldHelpTxt[f.help].t)
        end
    end

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
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addNumberField(
        formLines[app.formLineCnt],
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
            return app.utils.getFieldValue(page.fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(page.fields[i], value)
        end
    )

    local currentField = formFields[i]

    if f.onFocus  then currentField:onFocus(function() f.onFocus(page) end) end

    if f.default then
        if f.offset then f.default = f.default + f.offset end
        local default = f.default * app.utils.decimalInc(f.decimals)
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

-- Source field.
function ui.fieldSource(i)
    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields

    local posField, posText

    if f.inline and f.inline >= 1 and f.label then
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addSourceField(
        formLines[app.formLineCnt],
        posField,
        function()
            if not (page.fields and page.fields[i]) then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            return app.utils.getFieldValue(page.fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(page.fields[i], value)
        end
    )

    local currentField = formFields[i]

    if f.onFocus  then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable  then currentField:enable(false)        end

end

-- Sensor field.
function ui.fieldSensor(i)
    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields

    local posField, posText

    if f.inline and f.inline >= 1 and f.label then
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addSensorField(
        formLines[app.formLineCnt],
        posField,
        function()
            if not (page.fields and page.fields[i]) then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            return app.utils.getFieldValue(page.fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(page.fields[i], value)
        end
    )

    local currentField = formFields[i]

    if f.onFocus  then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable  then currentField:enable(false)        end

end

-- Color field.
function ui.fieldColor(i)
    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields

    local posField, posText

    if f.inline and f.inline >= 1 and f.label then
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addColorField(
        formLines[app.formLineCnt],
        posField,
        function()
            if not (page.fields and page.fields[i]) then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
            end
            local color = page.fields[i]
            if type(color) ~= "number" then
                return COLOR_BLACK
            else 
                return color
            end
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(page.fields[i], value)
        end
    )

    local currentField = formFields[i]

    if f.onFocus  then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable  then currentField:enable(false)        end

end

-- Source field.
function ui.fieldSwitch(i)
    local app        = rfsuite.app
    local page       = app.Page
    local fields     = page.fields
    local f          = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields

    local posField, posText

    if f.inline and f.inline >= 1 and f.label then
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if f.offset then
        if f.min then f.min = f.min + f.offset end
        if f.max then f.max = f.max + f.offset end
    end

    local minValue = app.utils.scaleValue(f.min, f)
    local maxValue = app.utils.scaleValue(f.max, f)

    if f.mult then
        if minValue then minValue = minValue * f.mult end
        if maxValue then maxValue = maxValue * f.mult end
    end

    minValue = minValue or 0
    maxValue = maxValue or 0

    formFields[i] = form.addSwitchField(
        formLines[app.formLineCnt],
        posField,
        function()
            if not (page.fields and page.fields[i]) then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            return app.utils.getFieldValue(page.fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(page.fields[i], value)
        end
    )

    local currentField = formFields[i]

    if f.onFocus  then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable  then currentField:enable(false)        end

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
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if radioText == 2 and f.t2 then f.t = f.t2 end
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    -- if HideMe == true then ... end (kept as comment in original)

    formFields[i] = form.addStaticText(
        formLines[app.formLineCnt],
        posField,
        app.utils.getFieldValue(fields[i])
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
        local p = app.utils.getInlinePositions(f, page)
        posText, posField = p.posText, p.posField
        form.addStaticText(formLines[app.formLineCnt], posText, f.t)
    else
        if radioText == 2 and f.t2 then f.t = f.t2 end
        if f.t then
            if f.label then f.t = "        " .. f.t end
        else
            f.t = ""
        end
        app.formLineCnt = app.formLineCnt + 1
        formLines[app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    formFields[i] = form.addTextField(
        formLines[app.formLineCnt],
        posField,
        function()
            if not fields or not fields[i] then
                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')
                return nil
            end
            return app.utils.getFieldValue(fields[i])
        end,
        function(value)
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(fields[i], value)
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

        if f.label ~= app.lastLabel then
            label.type = label.type or 0
            app.formLineCnt = app.formLineCnt + 1
            app.formLines[app.formLineCnt] = form.addLine(labelName)
            form.addStaticText(app.formLines[app.formLineCnt], nil, "")
            app.lastLabel = f.label
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
    local lcdWidth  = app.lcdWidth

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
    app.triggers.isReady = false
end

--------------------------------------------------------------------------------
-- Help caching
--------------------------------------------------------------------------------

ui._helpCache = ui._helpCache or {}

local function getHelpData(section)
    if ui._helpCache[section] == nil then
        local helpPath = "app/modules/" .. section .. "/help.lua"
        if utils.file_exists(helpPath) then
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

    utils.reportMemoryUsage("ui.openPage: " .. script, "start")

    local app = rfsuite.app

    -- Global UI state; clear form data.
    app.uiState          = app.uiStatus.pages
    app.triggers.isReady = false
    app.formFields       = {}
    app.formLines        = {}
    app.lastLabel        = nil

    -- Load module.
    local modulePath = "app/modules/" .. script
    app.Page = assert(rfsuite.compiler.loadfile(modulePath))(idx)

    -- Load help (if present).
    local section  = script:match("([^/]+)")
    local helpData = getHelpData(section)
    app.fieldHelpTxt = helpData and helpData.fields or nil

    -- Module-specific openPage?
    if app.Page.openPage then

        utils.reportMemoryUsage("app.Page.openPage: " .. script, "start")

        app.Page.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)

        utils.reportMemoryUsage("app.Page.openPage: " .. script, "end")
        return
    end

    -- Fallback rendering.
    app.lastIdx   = idx
    app.lastTitle = title
    app.lastScript = script

    form.clear()
    rfsuite.session.lastPage = script

    local pageTitle = app.Page.pageTitle or title
    app.ui.fieldHeader(pageTitle)

    if app.Page.headerLine then
        local headerLine = form.addLine("")
        form.addStaticText(headerLine, {
            x = 0, y = app.radio.linePaddingTop,
            w = app.lcdWidth, h = app.radio.navbuttonHeight
        }, app.Page.headerLine)
    end

    app.formLineCnt = 0

    utils.log("Merging form data from mspapi", "debug")
    app.Page.fields = app.Page.apidata.formdata.fields
    app.Page.labels = app.Page.apidata.formdata.labels

    if app.Page.fields then
        for i, field in ipairs(app.Page.fields) do
            local label   = app.Page.labels
            if rfsuite.session.apiVersion == nil then return end

            local valid =
                (field.apiversion    == nil or utils.apiVersionCompare(">=", field.apiversion))    and
                (field.apiversionlt  == nil or utils.apiVersionCompare("<",  field.apiversionlt))  and
                (field.apiversiongt  == nil or utils.apiVersionCompare(">",  field.apiversiongt))  and
                (field.apiversionlte == nil or utils.apiVersionCompare("<=", field.apiversionlte)) and
                (field.apiversiongte == nil or utils.apiVersionCompare(">=", field.apiversiongte)) and
                (field.enablefunction == nil or field.enablefunction())

            if field.hidden ~= true and valid then
                app.ui.fieldLabel(field, i, label)
                if     field.type == 0 then app.ui.fieldStaticText(i)
                elseif field.table or field.type == 1 then app.ui.fieldChoice(i)
                elseif field.type == 2 then app.ui.fieldNumber(i)
                elseif field.type == 3 then app.ui.fieldText(i)
                elseif field.type == 4 then app.ui.fieldBoolean(i)
                elseif field.type == 5 then app.ui.fieldBooleanInverted(i)  
                elseif field.type == 6 then app.ui.fieldSlider(i)  
                elseif field.type == 7 then app.ui.fieldSource(i)   
                elseif field.type == 8 then app.ui.fieldSwitch(i) 
                elseif field.type == 9 then app.ui.fieldSensor(i)     
                elseif field.type == 10 then app.ui.fieldColor(i) 
                else                         app.ui.fieldNumber(i)
                end
            else
                app.formFields[i] = {}
            end
        end
    end

    utils.reportMemoryUsage("ui.openPage: " .. script, "end")
end

-- Navigation buttons (Menu / Save / Reload / Tool / Help).
function ui.navigationButtons(x, y, w, h)

    local app = rfsuite.app

    local xOffset    = 0
    local padding    = 5
    local wS         = w - (w * 20) / 100
    local helpOffset = 0
    local toolOffset = 0
    local reloadOffset = 0
    local saveOffset   = 0
    local menuOffset   = 0

    local navButtons
    if app.Page.navButtons == nil then
        navButtons = { menu = true, save = true, reload = true, help = true }
    else
        navButtons = app.Page.navButtons
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
        app.formNavigationFields['menu'] = form.addButton(line, {
            x = menuOffset, y = y, w = w, h = h
        }, {
            text    = "@i18n(app.navigation_menu)@",
            icon    = nil,
            options = FONT_S,
            paint   = function() end,
            press   = function()
                if app.Page and app.Page.onNavMenu then
                    app.Page.onNavMenu(app.Page)
                elseif app.lastMenu ~= nil then
                    app.ui.openMainMenuSub(app.lastMenu)
                else
                    app.ui.openMainMenu()
                end
            end
        })
        app.formNavigationFields['menu']:focus()
    end

    -- SAVE
    if navButtons.save == true then
        app.formNavigationFields['save'] = form.addButton(line, {
            x = saveOffset, y = y, w = w, h = h
        }, {
            text    = "@i18n(app.navigation_save)@",
            icon    = nil,
            options = FONT_S,
            paint   = function() end,
            press   = function()
                if app.Page and app.Page.onSaveMenu then
                    app.Page.onSaveMenu(app.Page)
                else
                    app.triggers.triggerSave = true
                end
            end
        })
    end

    -- RELOAD
    if navButtons.reload == true then
        app.formNavigationFields['reload'] = form.addButton(line, {
            x = reloadOffset, y = y, w = w, h = h
        }, {
            text    = "@i18n(app.navigation_reload)@",
            icon    = nil,
            options = FONT_S,
            paint   = function() end,
            press   = function()
                if app.Page and app.Page.onReloadMenu then
                    app.Page.onReloadMenu(app.Page)
                else
                    app.triggers.triggerReload = true
                end
                return true
            end
        })
    end

    -- TOOL
    if navButtons.tool == true then
        app.formNavigationFields['tool'] = form.addButton(line, {
            x = toolOffset, y = y, w = wS, h = h
        }, {
            text    = "@i18n(app.navigation_tools)@",
            icon    = nil,
            options = FONT_S,
            paint   = function() end,
            press   = function()
                app.Page.onToolMenu()
            end
        })
    end

    -- HELP
    if navButtons.help == true then
        local section = app.lastScript:match("([^/]+)")
        local script  = app.lastScript:match("/([^/]+)%.lua$")

        local help = getHelpData(section)
        if help then
            app.formNavigationFields['help'] = form.addButton(line, {
                x = helpOffset, y = y, w = wS, h = h
            }, {
                text    = "@i18n(app.navigation_help)@",
                icon    = nil,
                options = FONT_S,
                paint   = function() end,
                press   = function()
                    if app.Page and app.Page.onHelpMenu then
                        app.Page.onHelpMenu(app.Page)
                    else
                        if help.help[script] then
                            app.ui.openPageHelp(help.help[script], section)
                        else
                            app.ui.openPageHelp(help.help['default'], section)
                        end
                    end
                end
            })
        else
            app.formNavigationFields['help'] = form.addButton(line, {
                x = helpOffset, y = y, w = wS, h = h
            }, {
                text    = "@i18n(app.navigation_help)@",
                icon    = nil,
                options = FONT_S,
                paint   = function() end,
                press   = function() end
            })
            app.formNavigationFields['help']:enable(false)
        end
    end
end

-- Open a help dialog with given text data.
function ui.openPageHelp(txtData, section)

    local app = rfsuite.app

    local message = table.concat(txtData, "\r\n\r\n")
    form.openDialog({
        width   = app.lcdWidth,
        title   = "Help - " .. app.lastTitle,
        message = message,
        buttons = { { label = "@i18n(app.btn_close)@", action = function() return true end } },
        options = TEXT_LEFT
    })
end

--------------------------------------------------------------------------------
-- API attribute injection
--------------------------------------------------------------------------------

function ui.injectApiAttributes(formField, f, v)
    local utils = rfsuite.utils
    local app = rfsuite.app
    local log   = utils.log

    if v.decimals and not f.decimals then
        if f.type ~= 1 then
            log("Injecting decimals: " .. v.decimals, "debug")
            f.decimals = v.decimals
            if formField.decimals then
                formField:decimals(v.decimals)
            end
        end
    end

    if v.scale  and not f.scale  then log("Injecting scale: " .. v.scale,   "debug"); f.scale  = v.scale  end
    if v.mult   and not f.mult   then log("Injecting mult: " .. v.mult,     "debug"); f.mult   = v.mult   end
    if v.offset and not f.offset then log("Injecting offset: " .. v.offset, "debug"); f.offset = v.offset end

    if v.unit and not f.unit then
        if f.type ~= 1 then
            log("Injecting unit: " .. v.unit, "debug")
            if formField.suffix then
                formField:suffix(v.unit)
            end
        end
    end

    if v.step and not f.step then
        if f.type ~= 1 then
            log("Injecting step: " .. v.step, "debug")
            f.step = v.step
            if formField.step then
                formField:step(v.step)
            end
        end
    end

    if v.min and not f.min then
        f.min = v.min
        if f.offset then f.min = f.min + f.offset end
        if f.type ~= 1 then
            log("Injecting min: " .. f.min, "debug")
            if formField.minimum then
                formField:minimum(f.min)
            end
        end
    end

    if v.max and not f.max then
        f.max = v.max
        if f.offset then f.max = f.max + f.offset end
        if f.type ~= 1 then
            log("Injecting max: " .. f.max, "debug")
            if formField.maximum then
                formField:maximum(f.max)
            end
        end
    end

    if v.default and not f.default then
        f.default = v.default
        if f.offset then f.default = f.default + f.offset end
        local default = f.default * app.utils.decimalInc(f.decimals)
        if f.mult then default = default * f.mult end
        local str = tostring(default)
        if str:match("%.0$") then default = math.ceil(default) end
        if f.type ~= 1 then
            log("Injecting default: " .. default, "debug")
            if formField.default then
                formField:default(default)
            end
        end
    end

    if v.table and not f.table then
        f.table = v.table
        local idxInc = f.tableIdxInc or v.tableIdxInc
        local tbldata = app.utils.convertPageValueTable(v.table, idxInc)
        if f.type == 1 then
            log("Injecting table: {}", "debug")
            if formField.values then
                formField:values(tbldata)
            end
        end
    end

    if v.help then
        f.help = v.help
        log("Injecting help: {}", "debug")
        if formField.help then
            formField:help(v.help)
        end
    end

    -- Force focus to ensure field updates.
    if formField.focus then
        formField:focus(true)
    end
end

-- Update form fields with MSP API values/attributes
function ui.mspApiUpdateFormAttributes(values, structure)

  local app   = rfsuite.app
  local utils   = rfsuite.utils
  local log     = utils.log

  if not (app.Page.apidata.formdata and app.Page.apidata.api and app.Page.fields) then
    log("app.Page.apidata.formdata or its components are nil", "debug")
    return
  end

  local function combined_api_parts(s)
    local part1, part2 = s:match("^([^:]+):([^:]+)$")
    if part1 and part2 then
      local num = tonumber(part1)
      if num then
        part1 = num
      else
        part1 = app.Page.apidata.api_reversed[part1] or nil
      end
      if part1 then return { part1, part2 } end
    end
    return nil
  end

  local fields = app.Page.apidata.formdata.fields
  local api    = app.Page.apidata.api

  if not app.Page.apidata.api_reversed then
    app.Page.apidata.api_reversed = {}
    for index, value in pairs(app.Page.apidata.api) do
      app.Page.apidata.api_reversed[value] = index
    end
  end

  for i, f in ipairs(fields) do
    local formField = app.formFields[i]
    if type(formField) == 'userdata' then
      if f.api then
        log("API field found: " .. f.api, "debug")
        local parts = combined_api_parts(f.api)
        if parts then f.mspapi = parts[1]; f.apikey = parts[2] end
      end

      local apikey      = f.apikey
      local mspapiID    = f.mspapi
      local mspapiNAME  = api[mspapiID]
      local target      = structure[mspapiNAME]

      if mspapiID == nil or mspapiID == nil then
        log("API field missing mspapi or apikey", "debug")
      else
        for _, v in ipairs(target) do
          if not v.bitmap then
            if v.field == apikey and mspapiID == f.mspapi then

              if v.help and (v.help == "" or v.help:match("^@i18n%b()@$")) then
                v.help = nil
              end

              app.ui.injectApiAttributes(formField, f, v)

              local scale = f.scale or 1
              if values and values[mspapiNAME] and values[mspapiNAME][apikey] then
                app.Page.fields[i].value = values[mspapiNAME][apikey] / scale
              end

              if values[mspapiNAME][apikey] == nil then
                log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                formField:enable(false)
              end
              break
            end
          else
            -- bitmap fields
            for bidx, b in ipairs(v.bitmap) do
              local bitmapField = v.field .. "->" .. b.field
              if bitmapField == apikey and mspapiID == f.mspapi then
                if v.help and (v.help == "" or v.help:match("^@i18n%b()@$")) then
                  v.help = nil
                end

                app.ui.injectApiAttributes(formField, f, b)

                local scale = f.scale or 1
                if values and values[mspapiNAME] and values[mspapiNAME][v.field] then
                  local raw_value = values[mspapiNAME][v.field]
                  local bit_value = (raw_value >> bidx - 1) & 1
                  app.Page.fields[i].value = bit_value / scale
                end

                if values[mspapiNAME][v.field] == nil then
                  log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                  formField:enable(false)
                end

                app.Page.fields[i].bitmap = bidx - 1
              end
            end
          end
        end
      end
    else
      log("Form field skipped; not valid for this api version?", "debug")
    end
  end

  app.formNavigationFields['menu']:focus(true)
end

-- Request page data via the API form system
function ui.requestPage()
  local app = rfsuite.app
  local log = utils.log


  if not app.Page.apidata then return end
  if not app.Page.apidata.api and not app.Page.apidata.formdata then
    log("app.Page.apidata.api did not pass consistancy checks", "debug")
    return
  end

  if not app.Page.apidata.apiState then
    app.Page.apidata.apiState = { currentIndex = 1, isProcessing = false }
  end

  local apiList = app.Page.apidata.api
  local state   = app.Page.apidata.apiState

  if state.isProcessing then
    log("requestPage is already running, skipping duplicate call.", "debug")
    return
  end
  state.isProcessing = true

  if not app.Page.apidata.values then
    log("requestPage Initialize values on first run", "debug")
    app.Page.apidata.values             = {}
    app.Page.apidata.structure          = {}
    app.Page.apidata.receivedBytesCount = {}
    app.Page.apidata.receivedBytes      = {}
    app.Page.apidata.positionmap        = {}
    app.Page.apidata.other              = {}
  end

  if state.currentIndex == nil then state.currentIndex = 1 end

  local function checkForUnresolvedTimeouts()
    if not app or not app.Page or not app.Page.apidata then return end
    local hasUnresolvedTimeouts = false
    for apiKey, retries in pairs(app.Page.apidata.retryCount or {}) do
      if retries >= 3 then
        hasUnresolvedTimeouts = true
        log("[ALERT] API " .. apiKey .. " failed after 3 timeouts.", "info")
      end
    end
    if hasUnresolvedTimeouts then
      app.ui.disableAllFields()
      app.ui.disableAllNavigationFields()
      app.ui.enableNavigationField('menu')
      app.triggers.closeProgressLoader = true
    end
  end

  local function processNextAPI()
    if not app or not app.Page or not app.Page.apidata then
      log("App is closing. Stopping processNextAPI.", "debug")
      return
    end

    if state.currentIndex > #apiList or #apiList == 0 then
      if state.isProcessing then
        state.isProcessing = false
        state.currentIndex = 1
        app.triggers.isReady = true
        if app.Page.postRead then app.Page.postRead(app.Page) end
        app.ui.mspApiUpdateFormAttributes(app.Page.apidata.values, app.Page.apidata.structure)
        if app.Page.postLoad then app.Page.postLoad(app.Page) else app.triggers.closeProgressLoader = true end
        checkForUnresolvedTimeouts()
      end
      return
    end

    local v      = apiList[state.currentIndex]
    local apiKey = type(v) == "string" and v or v.name
    if not apiKey then
      log("API key is missing for index " .. tostring(state.currentIndex), "warning")
      state.currentIndex = state.currentIndex + 1
      local base = 0.25
      local backoff = math.min(2.0, base * (2 ^ retryCount))
      local jitter = math.random() * 0.2
      tasks.callback.inSeconds(backoff + jitter, processNextAPI)
      return
    end

    local API = tasks.msp.api.load(v)

    if app and app.Page and app.Page.apidata then app.Page.apidata.retryCount = app.Page.apidata.retryCount or {} end

    local retryCount = app.Page.apidata.retryCount[apiKey] or 0
    local handled = false

    log("[PROCESS] API: " .. apiKey .. " (Attempt " .. (retryCount + 1) .. ")", "debug")

    local function handleTimeout()
      if handled then return end
      handled = true
      if not app or not app.Page or not app.Page.apidata then
        log("App is closing. Timeout handling skipped.", "debug")
        return
      end
      retryCount = retryCount + 1
      app.Page.apidata.retryCount[apiKey] = retryCount
      if retryCount < 3 then
        log("[TIMEOUT] API: " .. apiKey .. " (Retry " .. retryCount .. ")", "warning")
        tasks.callback.inSeconds(0.25, processNextAPI)
      else
        log("[TIMEOUT FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
        state.currentIndex = state.currentIndex + 1
        tasks.callback.inSeconds(0.25, processNextAPI)
      end
    end

    tasks.callback.inSeconds(2, handleTimeout)

    API.setCompleteHandler(function(self, buf)
      if handled then return end
      handled = true
      if not app or not app.Page or not app.Page.apidata then
        log("App is closing. Skipping API success handling.", "debug")
        return
      end
      log("[SUCCESS] API: " .. apiKey .. " completed successfully.", "debug")
      app.Page.apidata.values[apiKey]             = API.data().parsed
      app.Page.apidata.structure[apiKey]          = API.data().structure
      app.Page.apidata.receivedBytes[apiKey]      = API.data().buffer
      app.Page.apidata.receivedBytesCount[apiKey] = API.data().receivedBytesCount
      app.Page.apidata.positionmap[apiKey]        = API.data().positionmap
      app.Page.apidata.other[apiKey]              = API.data().other or {}
      app.Page.apidata.retryCount[apiKey]         = 0
      state.currentIndex = state.currentIndex + 1
      tasks.callback.inSeconds(0.5, processNextAPI)
    end)

    API.setErrorHandler(function(self, err)
      if handled then return end
      handled = true
      if not app or not app.Page or not app.Page.apidata then
        log("App is closing. Skipping API error handling.", "debug")
        return
      end
      retryCount = retryCount + 1
      app.Page.apidata.retryCount[apiKey] = retryCount
      if retryCount < 3 then
        log("[ERROR] API: " .. apiKey .. " failed (Retry " .. retryCount .. "): " .. tostring(err), "warning")
        tasks.callback.inSeconds(0.5, processNextAPI)
      else
        log("[ERROR FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
        state.currentIndex = state.currentIndex + 1
        tasks.callback.inSeconds(0.5, processNextAPI)
      end
    end)

    API.read()
  end

  processNextAPI()
end

-- Save current page's settings via MSP API(s)
function ui.saveSettings()

 local app = rfsuite.app
 local log = utils.log

  if app.pageState == app.pageStatus.saving then return end

  app.pageState = app.pageStatus.saving
  app.saveTS    = os.clock()

  log("Saving data", "debug")

  local mspapi  = app.Page.apidata
  local apiList = mspapi.api
  local values  = mspapi.values

  local totalRequests    = #apiList
  local completedRequests= 0

  app.Page.apidata.apiState.isProcessing = true

  if app.Page.preSave then app.Page.preSave(app.Page) end

  for apiID, apiNAME in ipairs(apiList) do

    utils.reportMemoryUsage("ui.saveSettings " .. apiNAME, "start")

    local payloadData      = values[apiNAME]
    local payloadStructure = mspapi.structure[apiNAME]

    local API = tasks.msp.api.load(apiNAME)
    API.setErrorHandler(function(self, buf)
      app.triggers.saveFailed = true
    end)
    API.setCompleteHandler(function(self, buf)
      completedRequests = completedRequests + 1
      log("API " .. apiNAME .. " write complete", "debug")
      if completedRequests == totalRequests then
        log("All API requests have been completed!", "debug")
        if app.Page.postSave then app.Page.postSave(app.Page) end
           app.Page.apidata.apiState.isProcessing = false
          app.utils.settingsSaved()
      end
    end)

    -- Build lookup maps (normal + bitmap)
    local fieldMap       = {}
    local fieldMapBitmap = {}
    for fidx, f in ipairs(app.Page.apidata.formdata.fields) do
      if not f.bitmap then
        if f.mspapi == apiID then fieldMap[f.apikey] = fidx end
      else
        local p1, p2 = string.match(f.apikey, "([^%-]+)%-%>(.+)")
        if not fieldMapBitmap[p1] then fieldMapBitmap[p1] = {} end
        fieldMapBitmap[p1][f.bitmap] = fidx
      end
    end

    -- Inject values into payload
    for k, v in pairs(payloadData) do
      local fieldIndex = fieldMap[k]
      if fieldIndex then
        payloadData[k] = app.Page.fields[fieldIndex].value
      elseif fieldMapBitmap[k] then
        local originalValue = tonumber(v) or 0
        local newValue = originalValue
        for bit, idx in pairs(fieldMapBitmap[k]) do
          local fieldVal = math.floor(tonumber(app.Page.fields[idx].value) or 0)
          local mask = 1 << (bit)
          if fieldVal ~= 0 then newValue = newValue | mask else newValue = newValue & (~mask) end
        end
        payloadData[k] = newValue
      end
    end

    -- Send payload
    for k, v in pairs(payloadData) do
      log("Set value for " .. k .. " to " .. v, "debug")
      API.setValue(k, v)
    end

    API.write()

    utils.reportMemoryUsage("ui.saveSettings " .. apiNAME, "end")

  end


end

-- Reboot FC (MSP)
function ui.rebootFc()
  local app   = rfsuite.app
  local utils = rfsuite.utils

  app.pageState = app.pageStatus.rebooting
  tasks.msp.mspQueue:add({
    command = 68, -- MSP_REBOOT
    processReply = function(self, buf)
      app.utils.invalidatePages()
      utils.onReboot()
    end,
    simulatorResponse = {}
  })
end

function ui.adminStatsOverlay()
  if rfsuite.preferences
    and preferences.developer
    and preferences.developer.overlaystatsadmin
  then
      -- font & color
      lcd.font(FONT_XXS)
      lcd.color(lcd.RGB(255,255,255))

      -- fresh values each draw
      local cpuUsage = (rfsuite.performance and rfsuite.performance.cpuload) or 0
      local ramUsed  = (rfsuite.performance and rfsuite.performance.usedram) or 0
      local luaRamKB = (rfsuite.performance and rfsuite.performance.luaRamKB) or 0

      -- layout config: fixed block columns
      local cfg = {
        startY = app.radio.navbuttonHeight + 3,
        decimalsKB = 0,
        labelGap = 4, -- space between label and value
        -- Each block: left x for label, and right edge where value+unit are right-aligned
        blocks = {
          LOAD = { x = 0,   valueRight = 50 },
          USED = { x = 70, valueRight = 130 },
          FREE = { x = 160, valueRight = 230 },
        }
      }

      local function fmtInt(n) return utils.round(n or 0, 0) end
      local function fmtKB(n)  return string.format("%." .. tostring(cfg.decimalsKB) .. "f", n or 0) end

      -- rows: key, label, valueWithUnit
      local rows = {
        { "LOAD", "LOAD:", tostring(fmtInt(cpuUsage)) .. "%" },
        { "USED", "USED",  tostring(fmtInt(ramUsed))  .. "kB" },
        { "FREE", "FREE",  tostring(fmtKB(luaRamKB))  .. "KB" },
      }

      local y = cfg.startY

      local function drawBlock(key, label, valueWithUnit)
        local b = cfg.blocks[key]; if not b then return end

        -- draw label at fixed left
        lcd.drawText(b.x, y, label)

        -- value+unit right-aligned to valueRight
        local vx = b.x + lcd.getTextSize(label) + cfg.labelGap
        local vWidth = lcd.getTextSize(valueWithUnit)
        lcd.drawText(math.max(vx, b.valueRight - vWidth), y, valueWithUnit)
      end

      -- single-row, three fixed columns
      for i = 1, #rows do
        local key, label, v = rows[i][1], rows[i][2], rows[i][3]
        drawBlock(key, label, v)
      end
  end
end


return ui
