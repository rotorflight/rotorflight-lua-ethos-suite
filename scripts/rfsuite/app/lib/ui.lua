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
local i18n = rfsuite.i18n.get

-- Displays a progress dialog with a title and message.
-- @param title The title of the progress dialog (optional, default is "Loading").
-- @param message The message of the progress dialog (optional, default is "Loading data from flight controller...").
function ui.progressDisplay(title, message)
    if rfsuite.app.dialogs.progressDisplay then return end

    title = title or i18n("app.msg_loading")
    message = message or i18n("app.msg_loading_from_fbl")

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

--[[
    Function: ui.progressNolinkDisplay
    Description: Displays a progress dialog indicating a connection attempt.
    Sets the nolinkDisplay flag to true and opens a progress dialog with the title "Connecting" and message "Connecting...".
    The dialog is configured to disallow closing and initializes the progress value to 0.
]]
function ui.progressNolinkDisplay()
    rfsuite.app.dialogs.nolinkDisplay = true
    rfsuite.app.dialogs.noLink = form.openProgressDialog(i18n("app.msg_connecting"), i18n("app.msg_connecting_to_fbl"))
    rfsuite.app.dialogs.noLink:closeAllowed(false)
    rfsuite.app.dialogs.noLink:value(0)
end

--[[
    Function: ui.progressDisplaySave
    Description: Opens a progress dialog indicating that data is being saved. 
                 Sets the save display flag, initializes the save watchdog timer, 
                 and configures the progress dialog with initial values.
]]
function ui.progressDisplaySave(msg)
    rfsuite.app.dialogs.saveDisplay = true
    rfsuite.app.dialogs.saveWatchDog = os.clock()
    if msg then
                 rfsuite.app.dialogs.save = form.openProgressDialog(i18n("app.msg_saving"),msg)   
    else
         rfsuite.app.dialogs.save = form.openProgressDialog(i18n("app.msg_saving"), i18n("app.msg_saving_to_fbl"))       
    end
    rfsuite.app.dialogs.save:value(0)
    rfsuite.app.dialogs.save:closeAllowed(false)
end


--[[
    Updates the progress display with the given value and optional message.
    
    @param value (number) - The progress value to display. If the value is 100 or more, the progress is updated immediately.
    @param message (string, optional) - An optional message to display along with the progress value.
    
    The function ensures that the progress display is updated at a rate limited by `rfsuite.app.dialogs.progressRate`.
]]
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


--[[
    Updates the progress display with a given value and optional message.
    
    @param value number: The progress value to display. If the value is 100 or more, the display is updated immediately.
    @param message string (optional): An optional message to display along with the progress value.
]]
function ui.progressDisplaySaveValue(value, message)
    if value >= 100 then
        if rfsuite.app.dialogs.save then
            rfsuite.app.dialogs.save:value(value)
        end    
        if message then rfsuite.app.dialogs.save:message(message) end
        return
    end

    local now = os.clock()
    if (now - rfsuite.app.dialogs.saveRateLimit) >= rfsuite.app.dialogs.saveRate then
        rfsuite.app.dialogs.saveRateLimit = now
        if rfsuite.app.dialogs.save then
            rfsuite.app.dialogs.save:value(value)
        end    
        if message then rfsuite.app.dialogs.save:message(message) end
    end
end

-- Closes the progress display dialog if it is currently open.
-- This function checks if the progress dialog exists, closes it, 
-- and updates the progress display status to false.
function ui.progressDisplayClose()
    local progress = rfsuite.app.dialogs.progress
    if progress then
        progress:close()
        rfsuite.app.dialogs.progressDisplay = false
    end
end

-- Closes the progress display if allowed by the given status.
-- @param status A boolean indicating whether closing the progress display is allowed.
function ui.progressDisplayCloseAllowed(status)
    local progress = rfsuite.app.dialogs.progress
    if progress then
        progress:closeAllowed(status)
    end
end

-- Displays a progress message in the UI.
-- @param message The message to be displayed in the progress dialog.
function ui.progressDisplayMessage(message)
    local progress = rfsuite.app.dialogs.progress
    if progress then
        progress:message(message)
    end
end

-- Closes the save dialog if it is open and updates the save display status.
-- This function checks if the save dialog exists, closes it if it does,
-- and then sets the save display status to false.
function ui.progressDisplaySaveClose()
    local saveDialog = rfsuite.app.dialogs.save
    if saveDialog then saveDialog:close() end
    rfsuite.app.dialogs.saveDisplay = false
end

--- Displays a save message in the progress dialog.
-- @param message The message to be displayed in the save dialog.
function ui.progressDisplaySaveMessage(message)
    local saveDialog = rfsuite.app.dialogs.save
    if saveDialog then saveDialog:message(message) end
end

--[[
    Function: ui.progressDisplaySaveCloseAllowed

    Description:
    This function updates the closeAllowed status of the save dialog in the rfsuite application.

    Parameters:
    status (boolean) - The status to set for allowing the save dialog to close.

    Usage:
    ui.progressDisplaySaveCloseAllowed(true) -- Allows the save dialog to close.
    ui.progressDisplaySaveCloseAllowed(false) -- Prevents the save dialog from closing.
]]
function ui.progressDisplaySaveCloseAllowed(status)
    local saveDialog = rfsuite.app.dialogs.save
    if saveDialog then saveDialog:closeAllowed(status) end
end

-- Closes the "no link" dialog in the rfsuite application.
-- This function is used to close the dialog that indicates there is no link.
function ui.progressNolinkDisplayClose()
    rfsuite.app.dialogs.noLink:close()
end

--[[
    Function: ui.progressDisplayNoLinkValue

    Updates the progress display for a "no link" scenario.

    Parameters:
    - value (number): The progress value to display. If the value is 100 or more, the display is updated immediately.
    - message (string, optional): An optional message to display along with the progress value.

    Behavior:
    - If the value is 100 or more, the progress display is updated immediately with the provided value and message.
    - If the value is less than 100, the progress display is updated only if a certain rate limit has been exceeded.
    - The rate limit is controlled by `rfsuite.app.dialogs.nolinkRate` and `rfsuite.app.dialogs.nolinkRateLimit`.
]]
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

-- Disables all form fields in the rfsuite application.
-- Iterates through the formFields array and disables each field if it is of type "userdata".
function ui.disableAllFields()
    for i = 1, #rfsuite.app.formFields do 
        local field = rfsuite.app.formFields[i]
        if type(field) == "userdata" then
            field:enable(false) 
        end
    end
end

-- Enables all form fields in the rfsuite application.
-- Iterates through the formFields table and enables each field if it is of type "userdata".
function ui.enableAllFields()
    for _, field in ipairs(rfsuite.app.formFields) do 
        if type(field) == "userdata" then
            field:enable(true) 
        end
    end
end

-- Disables all navigation fields in the form except the currently active one.
-- Iterates through the `formNavigationFields` table in the `rfsuite.app` namespace
-- and disables each field by calling its `enable` method with `false` as the argument.
function ui.disableAllNavigationFields()
    for i, v in pairs(rfsuite.app.formNavigationFields) do
        if x ~= v then
            v:enable(false)
        end
    end
end

-- Enables all navigation fields in the form except the one specified by 'x'.
-- Iterates through 'rfsuite.app.formNavigationFields' and calls 'enable(true)' on each field.
function ui.enableAllNavigationFields()
    for i, v in pairs(rfsuite.app.formNavigationFields) do
        if x ~= v then
            v:enable(true)
        end
    end
end

-- Enables a navigation field based on the given index.
-- @param x The index of the navigation field to enable.
function ui.enableNavigationField(x)
    local field = rfsuite.app.formNavigationFields[x]
    if field then field:enable(true) end
end

-- Disables the navigation field at the specified index.
-- @param x The index of the navigation field to disable.
function ui.disableNavigationField(x)
    local field = rfsuite.app.formNavigationFields[x]
    if field then field:enable(false) end
end

--[[
    Checks if any progress-related display is active.
    
    @return boolean True if any of the progress, save, no link, or bad version displays are active; otherwise, false.
]]
function ui.progressDisplayIsActive()
    return rfsuite.app.dialogs.progressDisplay or 
           rfsuite.app.dialogs.saveDisplay or 
           rfsuite.app.dialogs.progressDisplayEsc or 
           rfsuite.app.dialogs.nolinkDisplay or 
           rfsuite.app.dialogs.badversionDisplay
end

--- Opens and initializes the main menu UI.
-- This function resets various UI and application state variables, prepares the button layout
-- according to user preferences (such as icon size), and dynamically generates the main menu
-- buttons based on the configuration defined in "app/modules/sections.lua".
-- Each button is configured with its title, icon, and associated action, which may open a subpage
-- or another menu section. The function also manages focus, disables buttons as needed, and
-- ensures proper memory management.
--
-- Steps performed:
-- 1. Resets form fields, menu state, and UI triggers.
-- 2. Validates and sets the icon size preference.
-- 3. Calculates button dimensions and layout based on icon size.
-- 4. Loads menu configuration and iterates through menu items:
--    - Adds buttons for each menu item, sets icons, and assigns press actions.
--    - Handles new lines and system section headers.
--    - Disables buttons if specified.
--    - Sets focus to the last selected menu item.
-- 5. Cleans up and reports memory usage.
--
-- Dependencies:
-- - rfsuite.app, rfsuite.preferences, rfsuite.utils, rfsuite.compiler, lcd, form
--
-- No parameters.
-- No return value.
function ui.openMainMenu()
    rfsuite.app.formFields = {}
    rfsuite.app.formFieldsOffline = {}
    rfsuite.app.formLines = {}
    rfsuite.app.lastLabel = nil
    rfsuite.app.isOfflinePage = false
    if rfsuite.tasks.msp then
        rfsuite.tasks.msp.protocol.mspIntervalOveride = nil
    end
    rfsuite.app.gfx_buttons["mainmenu"] = {}
    rfsuite.app.lastMenu = nil

    -- Clear old icons
    for i in pairs(rfsuite.app.gfx_buttons) do
        if i ~= "mainmenu" then
            rfsuite.app.gfx_buttons[i] = nil
        end
    end

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu

    form.clear()

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    ESC = {}

    -- Ensure icon size preference is valid
    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    -- Determine dimensions
    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h

    local buttonW, buttonH, padding, numPerRow

    if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    elseif rfsuite.preferences.general.iconsize == 1 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    elseif rfsuite.preferences.general.iconsize == 2 then
        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    rfsuite.app.gfx_buttons["mainmenu"] = rfsuite.app.gfx_buttons["mainmenu"] or {}
    rfsuite.preferences.menulastselected["mainmenu"] = rfsuite.preferences.menulastselected["mainmenu"] or 1

    local Menu = assert(rfsuite.compiler.loadfile("app/modules/sections.lua"))()
    local lc, bx, y = 0, 0, 0

    local header = form.addLine("Configuration")

    for pidx, pvalue in ipairs(Menu) do
        if not pvalue.developer then
            rfsuite.app.formFieldsOffline[pidx] = pvalue.offline or false

            if pvalue.newline then
                lc = 0
                form.addLine("System")
            end

            if lc == 0 then
                y = form.height() + (rfsuite.preferences.general.iconsize == 2 and
                    rfsuite.app.radio.buttonPadding or rfsuite.app.radio.buttonPaddingSmall)
            end

            bx = (buttonW + padding) * lc

            if rfsuite.preferences.general.iconsize ~= 0 then
                rfsuite.app.gfx_buttons["mainmenu"][pidx] = rfsuite.app.gfx_buttons["mainmenu"][pidx]
                    or lcd.loadMask(pvalue.image)
            else
                rfsuite.app.gfx_buttons["mainmenu"][pidx] = nil
            end

            rfsuite.app.formFields[pidx] = form.addButton(line, {
                x = bx,
                y = y,
                w = buttonW,
                h = buttonH
            }, {
                text = pvalue.title,
                icon = rfsuite.app.gfx_buttons["mainmenu"][pidx],
                options = FONT_S,
                paint = function() end,
                press = function()
                    rfsuite.preferences.menulastselected["mainmenu"] = pidx
                    rfsuite.app.ui.progressDisplay()
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


--[[
    Opens the main menu sub-section based on the active section.
    
    This function initializes various application states, clears old icons, and sets up the main menu layout.
    It also handles button sizes based on user preferences and populates the menu with sections and pages.
    
    @param activesection The ID of the active section to display in the main menu.
]]
function ui.openMainMenuSub(activesection)
    rfsuite.app.formFields = {}
    rfsuite.app.formFieldsOffline = {}
    rfsuite.app.formLines = {}
    rfsuite.app.lastLabel = nil
    rfsuite.app.isOfflinePage = false
    rfsuite.app.gfx_buttons[activesection] = {}
    rfsuite.app.lastMenu = activesection

    -- Clear old icons
    for i in pairs(rfsuite.app.gfx_buttons) do
        if i ~= activesection then
            rfsuite.app.gfx_buttons[i] = nil
        end
    end

    -- Hard exit on error
    if not rfsuite.utils.ethosVersionAtLeast(config.ethosVersion) then return end

    local MainMenu = rfsuite.app.MainMenu

    -- Clear all navigation variables
    rfsuite.app.lastIdx = nil
    rfsuite.app.lastTitle = nil
    rfsuite.app.lastScript = nil
    rfsuite.session.lastPage = nil
    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu
    rfsuite.app.triggers.disableRssiTimeout = false

    -- Determine button size based on preferences
    rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize) or 1

    local buttonW, buttonH, padding, numPerRow

    if rfsuite.preferences.general.iconsize == 0 then
        -- Text icons
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    elseif rfsuite.preferences.general.iconsize == 1 then
        -- Small icons
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    elseif rfsuite.preferences.general.iconsize == 2 then
        -- Large icons
        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    form.clear()

    rfsuite.app.gfx_buttons[activesection] = rfsuite.app.gfx_buttons[activesection] or {}
    rfsuite.preferences.menulastselected[activesection] = rfsuite.preferences.menulastselected[activesection] or 1

    for idx, section in ipairs(MainMenu.sections) do
        if section.id == activesection then
            local w, h = lcd.getWindowSize()
            local windowWidth, windowHeight = w, h
            local padding = rfsuite.app.radio.buttonPadding

            form.addLine(section.title)

            local x = windowWidth - 110 -- 100 + 10 padding
            rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {
                x = x,
                y = rfsuite.app.radio.linePaddingTop,
                w = 100,
                h = rfsuite.app.radio.navbuttonHeight
            }, {
                text = "MENU",
                icon = nil,
                options = FONT_S,
                paint = function() end,
                press = function()
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
                    local hideEntry = (page.ethosversion and not rfsuite.utils.ethosVersionAtLeast(page.ethosversion)) or
                                      (page.mspversion and (rfsuite.session.apiVersion or 1) < page.mspversion) or
                                      (page.developer and not rfsuite.preferences.developer.devtools)

                    local offline = page.offline
                    rfsuite.app.formFieldsOffline[pidx] = offline or false

                    if not hideEntry then
                        if lc == 0 then
                            y = form.height() + ((rfsuite.preferences.general.iconsize == 2) and rfsuite.app.radio.buttonPadding or rfsuite.app.radio.buttonPaddingSmall)
                        end

                        local x = (buttonW + padding) * lc

                        if rfsuite.preferences.general.iconsize ~= 0 then
                            rfsuite.app.gfx_buttons[activesection][pidx] = rfsuite.app.gfx_buttons[activesection][pidx]
                                or lcd.loadMask("app/modules/" .. page.folder .. "/" .. page.image)
                        else
                            rfsuite.app.gfx_buttons[activesection][pidx] = nil
                        end

                        rfsuite.app.formFields[pidx] = form.addButton(line, {
                            x = x,
                            y = y,
                            w = buttonW,
                            h = buttonH
                        }, {
                            text = page.title,
                            icon = rfsuite.app.gfx_buttons[activesection][pidx],
                            options = FONT_S,
                            paint = function() end,
                            press = function()
                                rfsuite.preferences.menulastselected[activesection] = pidx
                                rfsuite.app.ui.progressDisplay()
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



--[[
    Retrieves a label from a given page by its ID.

    @param id The ID of the label to retrieve.
    @param page The page containing the labels.
    @return The label with the specified ID, or nil if not found.
]]
function ui.getLabel(id, page)
    if id == nil then return nil end
    for i = 1, #page do
        if page[i].label == id then
            return page[i]
        end
    end
    return nil
end

--[[
    ui.fieldChoice(i)
    
    This function creates a choice field in the UI form based on the provided index `i`.
    
    Parameters:
    - i: The index of the field in the `fields` table.
    
    The function performs the following steps:
    1. Retrieves the application, page, fields, form lines, form fields, and radio text.
    2. Determines the position of the text and field based on whether the field is inline.
    3. Adds static text or a new form line based on the field's properties.
    4. Converts the field's table data if available.
    5. Adds a choice field to the form and sets up its get and set value functions.
    6. Disables the field if specified.
]]
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
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
    else
        if f.t then
            if radioText == 2 and f.t2 then
                f.t = f.t2
            end
            if f.label then
                f.t = "        " .. f.t
            end
        end
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        formLines[rfsuite.app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    local tbldata = f.table and rfsuite.app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}
    formFields[i] = form.addChoiceField(formLines[rfsuite.app.formLineCnt], posField, tbldata,
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

--[[
    Function: ui.fieldNumber

    Description:
    This function creates and configures a number input field in the form. It handles various configurations 
    such as inline positioning, text overrides, value scaling, and field-specific behaviors like focus, 
    default values, and help text.

    Parameters:
    - i (number): The index of the field in the fields table.

    Behavior:
    - Applies radio text override if applicable.
    - Determines the position of the field and text based on inline settings.
    - Adjusts min and max values based on offset and scaling factors.
    - Adds the number field to the form with specified configurations.
    - Sets up callbacks for getting and setting the field value.
    - Configures additional properties like focus behavior, default value, decimals, unit, step, and help text.
    - Enables or disables instant change based on the field configuration.
]]
function ui.fieldNumber(i)
    local app    = rfsuite.app
    local page   = app.Page
    local fields = page.fields
    local f      = fields[i]
    local formLines  = app.formLines
    local formFields = app.formFields

    local posField, posText

    if f.inline and f.inline >= 1 and f.label then
        local p = rfsuite.app.utils.getInlinePositions(f, page)
        posText  = p.posText
        posField = p.posField
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
    else
        if f.t then
            if f.label then
                f.t = "        " .. f.t
            end
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

    formFields[i] = form.addNumberField(formLines[rfsuite.app.formLineCnt], posField, minValue, maxValue,
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


--[[
    Function: ui.fieldStaticText

    This function adds a static text field to the form based on the provided index.

    Parameters:
        i (number) - The index of the field in the fields table.

    Behavior:
        - Retrieves the application, page, fields, form lines, form fields, and radio text.
        - Determines the position and text for the static text field based on the field's properties.
        - Adds the static text to the form.
        - Increments the form line counter.
        - Optionally hides the field if `HideMe` is true.
        - Adds the static text field to the form fields table.
        - Sets up focus, decimals, unit, and step properties if they are defined for the field.
--]]
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
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
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
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        formLines[rfsuite.app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    if HideMe == true then
        -- posField = {x = 2000, y = 0, w = 20, h = 20}
    end

    formFields[i] = form.addStaticText(formLines[rfsuite.app.formLineCnt], posField, rfsuite.app.utils.getFieldValue(fields[i]))
    local currentField = formFields[i]

    if f.onFocus then
        currentField:onFocus(function() f.onFocus(page) end)
    end

    if f.decimals then currentField:decimals(f.decimals) end
    if f.unit     then currentField:suffix(f.unit) end
    if f.step     then currentField:step(f.step) end
end


--[[
    Function: ui.fieldText

    Description:
    This function is responsible for creating and configuring a text field in the UI. It handles the display of static text, 
    inline text positioning, and the creation of text fields with various properties such as focus, disable, help text, 
    and instant change behavior.

    Parameters:
    - i (number): The index of the field in the fields table.

    Returns:
    None
]]
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
        form.addStaticText(formLines[rfsuite.app.formLineCnt], posText, f.t)
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

        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        formLines[rfsuite.app.formLineCnt] = form.addLine(f.t)
        posField = f.position or nil
    end

    formFields[i] = form.addTextField(formLines[rfsuite.app.formLineCnt], posField,
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


--[[
    Function: ui.fieldLabel

    Parameters:
    - f (table): A table containing field properties.
        - t (string, optional): A text value.
        - t2 (string, optional): A secondary text value.
        - label (string, optional): A label identifier.
    - i (number): An index value (not used in the function).
    - l (number): A length value (not used in the function).

    Description:
    This function handles the creation and management of field labels within the UI. 
    It updates the text value based on the presence of secondary text and label properties. 
    If a label is provided and it is different from the last processed label, 
    it adds a new line to the form and updates the session's lastLabel and formLineCnt.
]]
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

        if f.label ~= rfsuite.app.lastLabel then
            label.type = label.type or 0
            rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
            app.formLines[rfsuite.app.formLineCnt] = form.addLine(labelName)
            form.addStaticText(app.formLines[rfsuite.app.formLineCnt], nil, "")
            rfsuite.app.lastLabel = f.label
        end
    end
end


--[[
    Function: ui.fieldHeader
    Description: Creates a header field in the UI with a title and navigation buttons.
    Parameters:
        title (string) - The title text to be displayed in the header.
    Returns: None
]]
function ui.fieldHeader(title)
    local app    = rfsuite.app
    local utils  = rfsuite.utils
    local radio  = app.radio
    local formFields = app.formFields
    local lcdWidth   = rfsuite.app.lcdWidth

    local w, h = lcd.getWindowSize()
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


--- Opens a page and refreshes the UI.
-- @param idx The index of the page.
-- @param title The title of the page.
-- @param script The script associated with the page.
-- @param extra1 Additional parameter 1.
-- @param extra2 Additional parameter 2.
-- @param extra3 Additional parameter 3.
-- @param extra5 Additional parameter 5.
-- @param extra6 Additional parameter 6.
function ui.openPageRefresh(idx, title, script, extra1, extra2, extra3, extra5, extra6)
    rfsuite.app.triggers.isReady = false
end

-- Cache for help modules to avoid repeated file_exists and loadfile
ui._helpCache = ui._helpCache or {}
local function getHelpData(section)
  if ui._helpCache[section] == nil then
    local helpPath = "app/modules/" .. section .. "/help.lua"
    if rfsuite.utils.file_exists(helpPath) then
      local ok, helpData = pcall(function()
        return assert(rfsuite.compiler.loadfile(helpPath))()
      end)
      ui._helpCache[section] = (ok and type(helpData)=="table") and helpData or false
    else
      ui._helpCache[section] = false
    end
  end
  return ui._helpCache[section] or nil
end


--[[
    Function: ui.openPage

    Description:
    Opens a new page in the UI, initializing the global UI state, loading the specified module, 
    and setting up form data and help text if available. If the loaded module has its own 
    openPage function, it will be called with the provided arguments.

    Parameters:
    - idx (number): Index of the page to open.
    - title (string): Title of the page.
    - script (string): Script name of the module to load.
    - extra1 (any): Additional parameter 1.
    - extra2 (any): Additional parameter 2.
    - extra3 (any): Additional parameter 3.
    - extra5 (any): Additional parameter 5.
    - extra6 (any): Additional parameter 6.

    Returns:
    None
]]
function ui.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)

    -- Initialize global UI state and clear form data
    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false
    rfsuite.app.formFields = {}
    rfsuite.app.formLines = {}
    rfsuite.app.lastLabel = nil

    -- Load the module
    local modulePath = "app/modules/" .. script

    rfsuite.app.Page = assert(rfsuite.compiler.loadfile(modulePath))(idx)

    -- Load the help file if it exists
    local section = script:match("([^/]+)")
    local helpData = getHelpData(section)
    rfsuite.app.fieldHelpTxt = helpData and helpData.fields or nil

   -- rfsuite.app.Page = assert(rfsuite.compiler.loadfile(modulePath))(idx)

    -- If the Page has its own openPage function, use it and return early
    if rfsuite.app.Page.openPage then
        rfsuite.app.Page.openPage(idx, title, script, extra1, extra2, extra3, extra5, extra6)
        rfsuite.utils.reportMemoryUsage(title)
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
            w = rfsuite.app.lcdWidth,
            h = rfsuite.app.radio.navbuttonHeight
        }, rfsuite.app.Page.headerLine)
    end

    rfsuite.app.formLineCnt = 0

    rfsuite.utils.log("Merging form data from mspapi", "debug")
    rfsuite.app.Page.fields = rfsuite.app.Page.apidata.formdata.fields
    rfsuite.app.Page.labels = rfsuite.app.Page.apidata.formdata.labels

    if rfsuite.app.Page.fields then
        for i, field in ipairs(rfsuite.app.Page.fields) do

            local label = rfsuite.app.Page.labels
            local version = rfsuite.utils.round(rfsuite.session.apiVersion,2)
            if version == nil then return end
            local valid = (field.apiversion    == nil or rfsuite.utils.round(field.apiversion,2)    <= version) and
                          (field.apiversionlt  == nil or rfsuite.utils.round(field.apiversionlt,2)  >  version) and
                          (field.apiversiongt  == nil or rfsuite.utils.round(field.apiversiongt,2)  <  version) and
                          (field.apiversionlte == nil or rfsuite.utils.round(field.apiversionlte,2) >= version) and
                          (field.apiversiongte == nil or rfsuite.utils.round(field.apiversiongte,2) <= version) and
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
    rfsuite.utils.reportMemoryUsage(title)
end


--[[
    Function: ui.navigationButtons

    Description:
    This function creates and positions navigation buttons (Menu, Save, Reload, Tool, Help) on the UI. 
    It calculates the offsets for each button based on their visibility and positions them accordingly.

    Parameters:
    - x (number): The x-coordinate for the button placement.
    - y (number): The y-coordinate for the button placement.
    - w (number): The width of the buttons.
    - h (number): The height of the buttons.

    Notes:
    - The function checks the visibility of each button from `rfsuite.app.Page.navButtons`.
    - If a button is visible, it calculates its offset and adds it to the form.
    - Each button has a specific action defined in its `press` function.
    - The Help button attempts to load a help file and displays relevant help content.
--]]
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
            text = i18n("app.navigation_menu"),
            icon = nil,
            options = FONT_S,
            paint = function()
            end,
            press = function()
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

    -- SAVE BTN
    if navButtons.save ~= nil and navButtons.save == true then

        rfsuite.app.formNavigationFields['save'] = form.addButton(line, {x = saveOffset, y = y, w = w, h = h}, {
            text = i18n("app.navigation_save"),
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
            text = i18n("app.navigation_reload"),
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
            text = i18n("app.navigation_tools"),
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
        local section = rfsuite.app.lastScript:match("([^/]+)")
        local script = rfsuite.app.lastScript:match("/([^/]+)%.lua$")
        -- Load help module with caching
        local help = getHelpData(section)
        if help then

            -- Execution of the file succeeded
            rfsuite.app.formNavigationFields['help'] = form.addButton(line, {x = helpOffset, y = y, w = wS, h = h}, {
                text = i18n("app.navigation_help"),
                icon = nil,
                options = FONT_S,
                paint = function()
                end,
                press = function()
                    if rfsuite.app.Page and rfsuite.app.Page.onHelpMenu then
                        rfsuite.app.Page.onHelpMenu(rfsuite.app.Page)
                    else
                        -- choose default or custom
                        if help.help[script] then
                            rfsuite.app.ui.openPageHelp(help.help[script], section)
                        else
                            rfsuite.app.ui.openPageHelp(help.help['default'], section)
                        end
                    end
                end
            })

        else
            -- No help available
            rfsuite.app.formNavigationFields['help'] = form.addButton(line, {x = helpOffset, y = y, w = wS, h = h}, {
                text = i18n("app.navigation_help"),
                icon = nil, options = FONT_S, paint = function() end, press = function() end
            })
            rfsuite.app.formNavigationFields['help']:enable(false)
        end
    end

end

--[[
    Opens a help dialog with the provided text data and section.

    @param txtData (table) - A table containing lines of text to be displayed in the help dialog.
    @param section (string) - The section of the help content to be displayed (currently unused).

    @return (boolean) - Always returns true when the close button is pressed.
]]
function ui.openPageHelp(txtData, section)
    local message = table.concat(txtData, "\r\n\r\n")

    form.openDialog({
        width = rfsuite.app.lcdWidth,
        title = "Help - " .. rfsuite.app.lastTitle,
        message = message,
        buttons = {{
            label = i18n("app.btn_close"),
            action = function() return true end
        }},
        options = TEXT_LEFT
    })
end


--[[
    Injects API attributes into a form field.

    @param formField (table) - The form field to inject attributes into.
    @param f (table) - The form field's current attributes.
    @param v (table) - The new attributes to inject.

    Attributes injected:
    - decimals: Number of decimal places.
    - scale: Scale factor.
    - mult: Multiplication factor.
    - offset: Offset value.
    - unit: Unit suffix.
    - step: Step value.
    - min: Minimum value.
    - max: Maximum value.
    - default: Default value.
    - table: Table of values.
    - help: Help text.
]]
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

    -- force focus to ensure field updates
    formField:focus(true)

end


return ui
