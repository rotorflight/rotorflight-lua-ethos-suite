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
local app = {}

local arg = {...}

local config = arg[1]

--[[
triggers table:
    - exitAPP: boolean, indicates if the app should exit.
    - noRFMsg: boolean, indicates if there is no RF message.
    - triggerSave: boolean, indicates if a save operation should be triggered.
    - triggerSaveNoProgress: boolean, indicates if a save operation without progress should be triggered.
    - triggerReload: boolean, indicates if a reload operation should be triggered.
    - triggerReloadFull: boolean, indicates if a full reload operation should be triggered.
    - triggerReloadNoPrompt: boolean, indicates if a reload without prompt should be triggered.
    - reloadFull: boolean, indicates if a full reload is in progress.
    - isReady: boolean, indicates if the app is ready.
    - isSaving: boolean, indicates if a save operation is in progress.
    - isSavingFake: boolean, indicates if a fake save operation is in progress.
    - saveFailed: boolean, indicates if a save operation has failed.
    - telemetryState: unknown, stores the state of telemetry.
    - profileswitchLast: unknown, stores the last profile switch state.
    - rateswitchLast: unknown, stores the last rate switch state.
    - closeSave: boolean, indicates if the save operation should be closed.
    - closeSaveFake: boolean, indicates if the fake save operation should be closed.
    - badMspVersion: boolean, indicates if there is a bad MSP version.
    - badMspVersionDisplay: boolean, indicates if the bad MSP version should be displayed.
    - closeProgressLoader: boolean, indicates if the progress loader should be closed.
    - mspBusy: boolean, indicates if MSP is busy.
    - disableRssiTimeout: boolean, indicates if RSSI timeout should be disabled.
    - timeIsSet: boolean, indicates if the time is set.
    - invalidConnectionSetup: boolean, indicates if the connection setup is invalid.
    - wasConnected: boolean, indicates if there was a previous connection.
    - isArmed: boolean, indicates if the system is armed.
    - showSaveArmedWarning: boolean, indicates if a warning should be shown when saving while armed.
]]
local triggers = {}
triggers.exitAPP = false
triggers.noRFMsg = false
triggers.triggerSave = false
triggers.triggerSaveNoProgress = false
triggers.triggerReload = false
triggers.triggerReloadFull = false
triggers.triggerReloadNoPrompt = false
triggers.reloadFull = false
triggers.isReady = false
triggers.isSaving = false
triggers.isSavingFake = false
triggers.saveFailed = false
triggers.telemetryState = nil
triggers.profileswitchLast = nil
triggers.rateswitchLast = nil
triggers.closeSave = false
triggers.closeSaveFake = false
triggers.badMspVersion = false
triggers.badMspVersionDisplay = false
triggers.closeProgressLoader = false
triggers.mspBusy = false
triggers.disableRssiTimeout = false
triggers.timeIsSet = false
triggers.invalidConnectionSetup = false
triggers.wasConnected = false
triggers.isArmed = false
triggers.showSaveArmedWarning = false

--[[
    Initializes the app.triggers table and assigns it to the triggers table.
    This is used to set up the triggers for the application.
]]
app.triggers = {}
app.triggers = triggers


--[[
    Initializes the app.ui table and loads the UI library.

    The app.ui table is first initialized as an empty table.
    Then, the UI library is loaded from "app/lib/ui.lua" using the rfsuite.compiler.loadfile function,
    and the result is assigned to app.ui. The config parameter is passed to the loaded file.

]]
app.ui = {}
app.ui = assert(rfsuite.compiler.loadfile("app/lib/ui.lua"))(config)


--[[
    Initializes the app.utils table and loads utility functions from the specified file.
    The utility functions are loaded from "app/lib/utils.lua" and are passed the 'config' parameter.
    If the file cannot be loaded, an error will be thrown.
]]
app.utils = {}
app.utils = assert(rfsuite.compiler.loadfile("app/lib/utils.lua"))(config)


--[[
app.sensors: Table to store sensor data.
app.formFields: Table to store form fields.
app.formNavigationFields: Table to store form navigation fields.
app.PageTmp: Temporary storage for page data.
app.Page: Table to store page data.
app.saveTS: Timestamp for the last save operation.
app.lastPage: Stores the last accessed page.
app.lastSection: Stores the last accessed section.
app.lastIdx: Stores the last accessed index.
app.lastTitle: Stores the last accessed title.
app.lastScript: Stores the last executed script.
app.gfx_buttons: Table to store graphical buttons.
app.uiStatus: Table to store UI status constants.
app.pageStatus: Table to store page status constants.
app.telemetryStatus: Table to store telemetry status constants.
app.uiState: Current state of the UI.
app.pageState: Current state of the page.
app.lastLabel: Stores the last accessed label.
app.NewRateTable: Table to store new rate data.
app.RateTable: Table to store rate data.
app.fieldHelpTxt: Stores help text for fields.
app.protocol: Table to store protocol data.
app.protocolTransports: Table to store protocol transport data.
app.radio: Table to store radio data.
app.sensor: Table to store sensor data.
app.init: Initialization function.
app.guiIsRunning: Boolean indicating if the GUI is running.
app.menuLastSelected: Table to store the last selected menu item.
app.adjfunctions: Table to store adjustment functions.
app.profileCheckScheduler: Scheduler for profile checks using os.clock().
app.offLineMode : Boolean indicating if the app is in offline mode.
]]
app.sensors = {}
app.formFields = {}
app.formNavigationFields = {}
app.PageTmp = {}
app.Page = {}
app.saveTS = 0
app.lastPage = nil
app.lastSection = nil
app.lastIdx = nil
app.lastTitle = nil
app.lastScript = nil
app.gfx_buttons = {}
app.uiStatus = {init = 1, mainMenu = 2, pages = 3, confirm = 4}
app.pageStatus = {display = 1, editing = 2, saving = 3, eepromWrite = 4, rebooting = 5}
app.telemetryStatus = {ok = 1, noSensor = 2, noTelemetry = 3}
app.uiState = app.uiStatus.init
app.pageState = app.pageStatus.display
app.lastLabel = nil
app.NewRateTable = nil
app.RateTable = nil
app.fieldHelpTxt = nil
app.protocol = {}
app.protocolTransports = {}
app.radio = {}
app.sensor = {}
app.init = nil
app.guiIsRunning = false
app.menuLastSelected = {}
app.adjfunctions = nil
app.profileCheckScheduler = os.clock()
app.offlineMode = false

--[[
app.audio: Table containing boolean flags for various audio states.
    - playTimeout: Flag to indicate if timeout audio should be played.
    - playSaving: Flag to indicate if saving audio should be played.
    - playLoading: Flag to indicate if loading audio should be played.
    - playEscPowerCycle: Flag to indicate if ESC power cycle audio should be played.
    - playServoOverideDisable: Flag to indicate if servo override disable audio should be played.
    - playServoOverideEnable: Flag to indicate if servo override enable audio should be played.
    - playMixerOverideDisable: Flag to indicate if mixer override disable audio should be played.
    - playMixerOverideEnable: Flag to indicate if mixer override enable audio should be played.
    - playEraseFlash: Flag to indicate if erase flash audio should be played.

]]
app.audio = {}
app.audio.playTimeout = false
app.audio.playEscPowerCycle = false
app.audio.playServoOverideDisable = false
app.audio.playServoOverideEnable = false
app.audio.playMixerOverideDisable = false
app.audio.playMixerOverideEnable = false
app.audio.playEraseFlash = false


--[[
    app.dialogs: Table to manage dialog states and properties.
    - progress: Boolean indicating if a progress dialog is active.
    - progressDisplay: Boolean indicating if the progress dialog is displayed.
    - progressWatchDog: Timer or reference to monitor progress dialog.
    - progressCounter: Counter to track progress updates.
    - progressRateLimit: Timestamp to limit the rate of progress updates.
    - progressRate: Number specifying how many times per second the dialog value can change.
]]
app.dialogs = {}
app.dialogs.progress = false
app.dialogs.progressDisplay = false
app.dialogs.progressWatchDog = nil
app.dialogs.progressCounter = 0
app.dialogs.progressRateLimit = os.clock()
app.dialogs.progressRate = 0.2 

--[[
    This section of the code initializes several variables related to the progress of ESC (Electronic Speed Controller) operations in the app.

    Variables:
    - app.dialogs.progressESC: A boolean flag indicating the progress state of the ESC.
    - app.dialogs.progressDisplayEsc: A boolean flag indicating whether to display the ESC progress.
    - app.dialogs.progressWatchDogESC: A variable for the ESC watchdog timer.
    - app.dialogs.progressCounterESC: A counter for tracking ESC progress.
    - app.dialogs.progressESCRateLimit: A timestamp for rate limiting ESC progress updates.
    - app.dialogs.progressESCRate: The rate at which ESC progress updates are allowed (in seconds).
]]
app.dialogs.progressESC = false
app.dialogs.progressDisplayEsc = false
app.dialogs.progressWatchDogESC = nil
app.dialogs.progressCounterESC = 0
app.dialogs.progressESCRateLimit = os.clock()
app.dialogs.progressESCRate = 2.5 

--[[
    Initializes the save dialog properties for the app.
    
    Properties:
    - save: Boolean flag indicating if the save dialog is active.
    - saveDisplay: Boolean flag indicating if the save dialog should be displayed.
    - saveWatchDog: Timer or watchdog for the save dialog (initially nil).
    - saveProgressCounter: Counter to track the progress of the save operation.
    - saveRateLimit: Timestamp of the last save operation to enforce rate limiting.
    - saveRate: Minimum time interval (in seconds) between save operations.
]]
app.dialogs.save = false
app.dialogs.saveDisplay = false
app.dialogs.saveWatchDog = nil
app.dialogs.saveProgressCounter = 0
app.dialogs.saveRateLimit = os.clock()
app.dialogs.saveRate = 0.2

--[[
    Initializes the 'nolink' dialog properties within the 'app' namespace.
    
    Properties:
    - nolink: Boolean flag indicating the presence of a link.
    - nolinkDisplay: Boolean flag for displaying the 'nolink' dialog.
    - nolinkValueCounter: Counter for the 'nolink' dialog value.
    - nolinkRateLimit: Timestamp for rate limiting the 'nolink' dialog updates.
    - nolinkRate: Time interval (in seconds) for rate limiting the 'nolink' dialog updates.
]]
app.dialogs.nolink = false
app.dialogs.nolinkDisplay = false
app.dialogs.nolinkValueCounter = 0
app.dialogs.nolinkRateLimit = os.clock()
app.dialogs.nolinkRate = 0.2 

--[[
    This code snippet initializes two boolean flags within the `app.dialogs` table:
    - `badversion`: Indicates whether there is a bad version detected.
    - `badversionDisplay`: Controls the display state of the bad version dialog.
]]
app.dialogs.badversion = false
app.dialogs.badversionDisplay = false

--[[
    Function: app.getRSSI
    Description: Retrieves the RSSI (Received Signal Strength Indicator) value.
    Returns 100 if the system is in simulation mode, the RSSI sensor check is skipped, or the app is in offline mode.
    Otherwise, returns 100 if telemetry is active, and 0 if it is not.
    Returns:
        number - The RSSI value (100 or 0).
]]
function app.getRSSI()
    if app.offlineMode == true then return 100 end


    if rfsuite.session.telemetryState then
        return 100
    else
        return 0
    end
end


--[[
    Function: app.resetState
    Description: Resets the application state by initializing various configuration settings, triggers, dialogs, and session variables to their default values. Also, it forces garbage collection to free up memory.
    Parameters: None
    Returns: None
]]
function app.resetState()

    config.useCompiler = true
    rfsuite.config.useCompiler = true
    pageLoaded = 100
    pageTitle = nil
    pageFile = nil
    app.triggers.exitAPP = false
    app.triggers.noRFMsg = false
    app.dialogs.nolinkDisplay = false
    app.dialogs.nolinkValueCounter = 0
    app.triggers.telemetryState = nil
    app.dialogs.progressDisplayEsc = false
    ELRS_PAUSE_TELEMETRY = false
    CRSF_PAUSE_TELEMETRY = false
    app.audio = {}
    app.triggers.wasConnected = false
    app.triggers.invalidConnectionSetup = false
    rfsuite.app.triggers.profileswitchLast = nil
    rfsuite.session.activeProfileLast = nil
    rfsuite.session.activeProfile = nil
    rfsuite.session.activeRateProfile = nil
    rfsuite.session.activeRateProfileLast = nil
    rfsuite.session.activeProfile = nil
    rfsuite.session.activeRateTable = nil
    rfsuite.app.triggers.disableRssiTimeout = false
    collectgarbage()
end


-- Retrieves the current window size from the LCD.
-- @return The window size as provided by lcd.getWindowSize().
function app.getWindowSize()
    return lcd.getWindowSize()
end

-- Function to invalidate the pages variable.
-- Typically called after writing MSP data.
-- Resets the app.Page to nil, sets app.pageState to app.pageStatus.display,
-- and initializes app.saveTS to 0.
local function invalidatePages()
    app.Page = nil
    app.pageState = app.pageStatus.display
    app.saveTS = 0
    collectgarbage()
end

-- Reboots the flight controller (FBL unit) by issuing an MSP command.
-- Sets the application page state to 'rebooting' and adds a reboot command to the MSP queue.
-- Once the command is processed, it invalidates the pages.
local function rebootFc()

    app.pageState = app.pageStatus.rebooting
    rfsuite.tasks.msp.mspQueue:add({
        command = 68, -- MSP_REBOOT
        processReply = function(self, buf)
            invalidatePages()
            rfsuite.utils.onReboot()
        end,
        simulatorResponse = {}
    })
end

-- This table represents an MSP (MultiWii Serial Protocol) command to write data to EEPROM.
-- @field command The MSP command code for EEPROM write (250).
-- @field processReply Function to handle the response from the EEPROM write command.
-- @field errorHandler Function to handle errors that occur during the EEPROM write command.
-- @field simulatorResponse Table to handle simulator responses (currently empty).
local mspEepromWrite = {
    command = 250, -- MSP_EEPROM_WRITE, fails when armed
    processReply = function(self, buf)
        app.triggers.closeSave = true
        if app.Page.postEepromWrite then 
            app.Page.postEepromWrite() 
        end
        
        if app.Page.reboot then
            -- app.audio.playSaveArmed = true
            rebootFc()

        else
            invalidatePages()
        end
    end,
    errorHandler = function(self)
        app.triggers.closeSave = true
        app.audio.playSaveArmed = true
        app.triggers.showSaveArmedWarning = true
    end,
    simulatorResponse = {}
}

--[[
    Function: app.settingsSaved

    Description:
    This function handles the saving of settings. It checks if the current page requires writing to EEPROM.
    If so, it queues an EEPROM write task unless one is already in progress. If no EEPROM write is needed,
    it invalidates the pages and sets a trigger to close the save process. Finally, it runs garbage collection.

    Parameters:
    None

    Returns:
    None
]]
function app.settingsSaved()

    -- check if this page requires writing to eeprom to save (most do)
    if app.Page and app.Page.eepromWrite then
        -- don't write again if we're already responding to earlier page.write()s
        if app.pageState ~= app.pageStatus.eepromWrite then
            app.pageState = app.pageStatus.eepromWrite
            rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
        end
    elseif app.pageState ~= app.pageStatus.eepromWrite then
        -- If we're not already trying to write to eeprom from a previous save, then we're done.
        invalidatePages()
        app.triggers.closeSave = true
    end
    collectgarbage()
    rfsuite.utils.reportMemoryUsage("app.settingsSaved")
end

--[[
    Function: saveSettings
    Description: This function saves all settings by making API calls to save data. It handles the saving process differently for multi mspapi.
    It logs the saving process, initializes APIs, sets error and completion handlers, injects values into the payload, and sends the payload.
    If preSave and postSave functions are defined, they are executed before and after the saving process respectively.
    The function also ensures that all API requests are completed before finalizing the save process.
--]]
local function saveSettings()
    if app.pageState == app.pageStatus.saving then return end

    app.pageState = app.pageStatus.saving
    app.saveTS = os.clock()

    -- we handle saving 100% different for multi mspapi
    rfsuite.utils.log("Saving data", "debug")

    local mspapi = rfsuite.app.Page.mspapi
    local apiList = mspapi.api
    local values = mspapi.values

    local totalRequests = #apiList  -- Total API calls to be made
    local completedRequests = 0      -- Counter for completed requests

    -- run a function in a module if it exists just prior to saving
    if app.Page.preSave then app.Page.preSave(app.Page) end

    for apiID, apiNAME in ipairs(apiList) do
        rfsuite.utils.log("Saving data for API: " .. apiNAME, "debug")

        local payloadData = values[apiNAME]
        local payloadStructure = mspapi.structure[apiNAME]

        -- Initialise the API
        local API = rfsuite.tasks.msp.api.load(apiNAME)
        API.setErrorHandler(function(self, buf)
            app.triggers.saveFailed = true
        end
        )
        API.setCompleteHandler(function(self, buf)
            completedRequests = completedRequests + 1
            rfsuite.utils.log("API " .. apiNAME .. " write complete", "debug")

            -- Check if this is the last completed request
            if completedRequests == totalRequests then
                rfsuite.utils.log("All API requests have been completed!", "debug")
                
                -- Run the postSave function if it exists
                if app.Page.postSave then app.Page.postSave(app.Page) end

                -- we need to save to epprom etc
                app.settingsSaved()

            end
        end)

        -- Create lookup table for fields by apikey
        local fieldMap = {}
        local fieldMapBitmap = {}
        for fidx, f in ipairs(app.Page.mspapi.formdata.fields) do
            if not f.bitmap then
                -- normal fields
                if f.mspapi == apiID then
                    fieldMap[f.apikey] = fidx
                end
            else
                -- bitmap fields
                local bitmap_part1, bitmap_part2 = string.match(f.apikey, "([^%-]+)%-%>(.+)")
                if not fieldMapBitmap[bitmap_part1] then
                    fieldMapBitmap[bitmap_part1] = {}
                end
                fieldMapBitmap[bitmap_part1][f.bitmap] = fidx
            end    
        end


        -- Inject values into the payload
        for i, v in pairs(payloadData) do
            local fieldIndex = fieldMap[i]
            if fieldIndex then
                -- Normal field
                payloadData[i] = app.Page.fields[fieldIndex].value
            elseif fieldMapBitmap[i] then
                -- Bitmap field
                local originalValue = tonumber(v) or 0
                local newValue = originalValue
        
                for bit, fieldIndex in pairs(fieldMapBitmap[i]) do
                    local fieldVal = math.floor(tonumber(app.Page.fields[fieldIndex].value) or 0)
                    local mask = 1 << (bit)
                    if fieldVal ~= 0 then
                        newValue = newValue | mask  -- Set bit
                    else
                        newValue = newValue & (~mask)  -- Clear bit
                    end
                end
        
                payloadData[i] = newValue
            end
        
        end


        -- Send the payload
        for i, v in pairs(payloadData) do
            rfsuite.utils.log("Set value for " .. i .. " to " .. v, "debug")
            API.setValue(i, v)
        end
        
             

        API.write()
    end
    
end

--[[
    Updates the page with new values received from the MSP and API structures.
    This function handles both initial values and attributes in one loop to prevent too many cascading loops.

    @param values - Table containing the new values to update the form with.
    @param structure - Table containing the structure of the MSP and API data.

    The function performs the following steps:
    1. Ensures that `app.Page.mspapi.formdata`, `app.Page.mspapi.api`, and `rfsuite.app.Page.fields` exist.
    2. Defines a helper function `combined_api_parts` to split and convert API keys.
    3. Creates a reversed API table for quick lookups if it doesn't already exist.
    4. Iterates over the form fields and updates them based on the provided values and structure.
    5. Logs debug information and handles cases where fields or values are missing.
--]]
function app.mspApiUpdateFormAttributes(values, structure)
    -- Ensure app.Page and its mspapi.formdata exist
    if not (app.Page.mspapi.formdata and app.Page.mspapi.api and rfsuite.app.Page.fields) then
        rfsuite.utils.log("app.Page.mspapi.formdata or its components are nil", "debug")
        return
    end

    local function combined_api_parts(s)
        local part1, part2 = s:match("^([^:]+):([^:]+)$")
    
        if part1 and part2 then
            local num = tonumber(part1)
            if num then
                part1 = num  -- Convert string to number
            else
                -- Fast lookup in precomputed table
                part1 = app.Page.mspapi.api_reversed[part1] or nil
            end
    
            if part1 then
                return { part1, part2 }
            end
        end
    
        return nil
    end

    local fields = app.Page.mspapi.formdata.fields
    local api = app.Page.mspapi.api

    -- Create a reversed API table for quick lookups
    if not app.Page.mspapi.api_reversed then
        app.Page.mspapi.api_reversed = {}
        for index, value in pairs(app.Page.mspapi.api) do
            app.Page.mspapi.api_reversed[value] = index
        end
    end

    for i, f in ipairs(fields) do
        -- Define some key details
        local formField = rfsuite.app.formFields[i]

        if type(formField) == 'userdata' then

            -- Check if the field has an API key and extract the parts if needed
            -- we do not need to handle this on the save side as read has simple
            -- populated the mspapi and api fierds in the formdata.fields
            -- meaning they are already in the correct format
            if f.api then
                rfsuite.utils.log("API field found: " .. f.api, "debug")
                local parts = combined_api_parts(f.api)
                if parts then
                f.mspapi = parts[1]
                f.apikey = parts[2]
                end
            end

            local apikey = f.apikey
            local mspapiID = f.mspapi
            local mspapiNAME = api[mspapiID]
            local targetStructure = structure[mspapiNAME]

            if mspapiID  == nil or mspapiID  == nil then 
                rfsuite.utils.log("API field missing mspapi or apikey", "debug")
            else        
                for _, v in ipairs(targetStructure) do

                    if not v.bitmap then
                        -- we have a standard api field - proceed to injecting values
                        if v.field == apikey and mspapiID == f.mspapi then

                            -- insert help string
                            local help_target = "api." .. mspapiNAME .. "." .. apikey
                            local help_return = rfsuite.i18n.get(help_target)
                            if help_target ~=  help_return then
                                v.help = help_return
                            else
                                v.help = nil    
                            end

                            rfsuite.app.ui.injectApiAttributes(formField, f, v)

                            local scale = f.scale or 1
                            if values and values[mspapiNAME] and values[mspapiNAME][apikey] then
                                rfsuite.app.Page.fields[i].value = values[mspapiNAME][apikey] / scale
                            end

                            if values[mspapiNAME][apikey] == nil then
                                rfsuite.utils.log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                                formField:enable(false)
                            end

                            break -- Found field, can move on
                        end
                    else
                        -- bitmap fields 
                        for bidx, b in ipairs(v.bitmap) do
                            local bitmapField = v.field .. "->" .. b.field

                            if bitmapField  == apikey  and mspapiID == f.mspapi then
                                    -- we have now found a bitmap field so should proceed with injecting
                                    -- the values into the form field
                                    -- insert help string
                                    local help_target = "api." .. mspapiNAME .. "." .. apikey
                                    local help_return = rfsuite.i18n.get(help_target)
                                    if help_target ~=  help_return then
                                        v.help = help_return
                                    else
                                        v.help = nil    
                                    end

                                    rfsuite.app.ui.injectApiAttributes(formField, f, b)

                                    local scale = f.scale or 1

                                    -- extract bit at position bidx
                                    if values and values[mspapiNAME] and values[mspapiNAME][v.field] then
                                        local raw_value = values[mspapiNAME][v.field]
                                        local bit_value = (raw_value >> bidx - 1) & 1  
                                        rfsuite.app.Page.fields[i].value = bit_value / scale
                                    end
        
                                    if values[mspapiNAME][v.field] == nil then
                                        rfsuite.utils.log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                                        formField:enable(false)
                                    end

                                    -- insert bit location for later reference
                                    rfsuite.app.Page.fields[i].bitmap = bidx - 1


                            end    
                        end
                    end    
                end
            end
        else
            rfsuite.utils.log("Form field skipped; not valid for this api version?", "debug")    
        end    
    end
    collectgarbage()
    rfsuite.utils.reportMemoryUsage("app.mspApiUpdateFormAttributes")

    -- set focus back to menu
    rfsuite.app.formNavigationFields['menu']:focus(true)
end


--[[
    requestPage - Requests a page using the new API form system.

    This function ensures that the necessary API and form data exist, initializes
    the state if needed, and processes API calls sequentially. It prevents duplicate
    execution if already running and handles both API success and error cases.

    The function performs the following steps:
    1. Checks if app.Page.mspapi and its api/formdata exist.
    2. Initializes the apiState if not already initialized.
    3. Prevents duplicate execution by checking the isProcessing flag.
    4. Initializes values and structure on the first run.
    5. Processes each API call sequentially using a recursive function.
    6. Handles API success by storing the response and moving to the next API.
    7. Handles API errors by logging the error and moving to the next API.
    8. Resets the state and triggers postRead and postLoad functions if they exist.

    Note: The function uses rfsuite.utils.log for logging and rfsuite.tasks.msp.api.load
    for loading the API. It also updates form attributes and manages progress loader triggers.
]]
local function requestPage()
    -- Ensure app.Page and its mspapi.api exist
    if not app.Page.mspapi then
        return
    end

    if not app.Page.mspapi.api and not app.Page.mspapi.formdata then
        rfsuite.utils.log("app.Page.mspapi.api did not pass consistancy checks", "debug")
        return
    end

    if not rfsuite.app.Page.mspapi.apiState then
        rfsuite.app.Page.mspapi.apiState = {
            currentIndex = 1,
            isProcessing = false
        }
    end    

    local apiList = app.Page.mspapi.api
    local state = rfsuite.app.Page.mspapi.apiState  -- Reference persistent state

    -- Prevent duplicate execution if already running
    if state.isProcessing then
        rfsuite.utils.log("requestPage is already running, skipping duplicate call.", "debug")
        return
    end
    state.isProcessing = true  -- Set processing flag

    if not rfsuite.app.Page.mspapi.values then
        rfsuite.utils.log("requestPage Initialize values on first run", "debug")
        rfsuite.app.Page.mspapi.values = {}  -- Initialize if first run
        rfsuite.app.Page.mspapi.structure = {}  -- Initialize if first run
        rfsuite.app.Page.mspapi.receivedBytesCount = {}  -- Initialize if first run
        rfsuite.app.Page.mspapi.receivedBytes = {}  -- Initialize if first run
        rfsuite.app.Page.mspapi.positionmap = {}  -- Initialize if first run
        rfsuite.app.Page.mspapi.other = {} 
    end

    -- Ensure state.currentIndex is initialized
    if state.currentIndex == nil then
        state.currentIndex = 1
    end

-- Function to check for unresolved timeouts and trigger an alert
local function checkForUnresolvedTimeouts()
    if not app or not app.Page or not app.Page.mspapi then return end

    local hasUnresolvedTimeouts = false
    for apiKey, retries in pairs(app.Page.mspapi.retryCount or {}) do
        if retries >= 3 then
            hasUnresolvedTimeouts = true
            rfsuite.utils.log("[ALERT] API " .. apiKey .. " failed after 3 timeouts.", "info")
        end
    end

    if hasUnresolvedTimeouts then
        -- disable all fields leaving only menu enabled
        rfsuite.app.ui.disableAllFields()
        rfsuite.app.ui.disableAllNavigationFields()
        rfsuite.app.ui.enableNavigationField('menu')
        rfsuite.app.triggers.closeProgressLoader = true
    end
end

-- Recursive function to process API calls sequentially
local function processNextAPI()
    -- **Exit gracefully if the app is closing**
    if not app or not app.Page or not app.Page.mspapi then
        rfsuite.utils.log("App is closing. Stopping processNextAPI.", "debug")
        return
    end

    if state.currentIndex > #apiList or #apiList == 0 then
        if state.isProcessing then  
            state.isProcessing = false  
            state.currentIndex = 1  

            app.triggers.isReady = true

            if app.Page.postRead then 
                app.Page.postRead(app.Page) 
            end

            app.mspApiUpdateFormAttributes(app.Page.mspapi.values, app.Page.mspapi.structure)

            if app.Page.postLoad then 
                app.Page.postLoad(app.Page) 
            else
                rfsuite.app.triggers.closeProgressLoader = true    
            end

            -- **Check for unresolved timeouts AFTER all APIs have been processed**
            checkForUnresolvedTimeouts()  -- 🔹 Added here
        end
        return
    end

    local v = apiList[state.currentIndex]
    local apiKey = type(v) == "string" and v or v.name 

    if not apiKey then
        rfsuite.utils.log("API key is missing for index " .. tostring(state.currentIndex), "warning")
        state.currentIndex = state.currentIndex + 1
        rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)
        return
    end

    local API = rfsuite.tasks.msp.api.load(v)

    -- **Ensure retryCount table exists**
    if app and app.Page and app.Page.mspapi then
        app.Page.mspapi.retryCount = app.Page.mspapi.retryCount or {}  
    end

    local retryCount = app.Page.mspapi.retryCount[apiKey] or 0
    local handled = false

    -- **Log API Start**
    rfsuite.utils.log("[PROCESS] API: " .. apiKey .. " (Attempt " .. (retryCount + 1) .. ")", "debug")

    -- **Timeout handler function**
    local function handleTimeout()
        if handled then return end
        handled = true  

        -- **Exit safely if app is closed**
        if not app or not app.Page or not app.Page.mspapi then
            rfsuite.utils.log("App is closing. Timeout handling skipped.", "debug")
            return
        end

        retryCount = retryCount + 1  
        app.Page.mspapi.retryCount[apiKey] = retryCount  

        if retryCount < 3 then  
            rfsuite.utils.log("[TIMEOUT] API: " .. apiKey .. " (Retry " .. retryCount .. ")", "warning")
            rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)  
        else
            rfsuite.utils.log("[TIMEOUT FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
            state.currentIndex = state.currentIndex + 1
            rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)  
        end
    end

    -- **Schedule timeout callback**
    rfsuite.tasks.callback.inSeconds(2, handleTimeout)

    -- **API success handler**
    API.setCompleteHandler(function(self, buf)
        if handled then return end
        handled = true  

        -- **Exit safely if app is closed**
        if not app or not app.Page or not app.Page.mspapi then
            rfsuite.utils.log("App is closing. Skipping API success handling.", "debug")
            return
        end

        -- **Log API Success**
        rfsuite.utils.log("[SUCCESS] API: " .. apiKey .. " completed successfully.", "debug")

        app.Page.mspapi.values[apiKey] = API.data().parsed
        app.Page.mspapi.structure[apiKey] = API.data().structure
        app.Page.mspapi.receivedBytes[apiKey] = API.data().buffer
        app.Page.mspapi.receivedBytesCount[apiKey] = API.data().receivedBytesCount
        app.Page.mspapi.positionmap[apiKey] = API.data().positionmap
        app.Page.mspapi.other[apiKey] = API.data().other or {}

        -- **Reset retry count on success**
        app.Page.mspapi.retryCount[apiKey] = 0  

        state.currentIndex = state.currentIndex + 1
        rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)  
    end)

    -- **API error handler**
    API.setErrorHandler(function(self, err)
        if handled then return end
        handled = true  

        -- **Exit safely if app is closed**
        if not app or not app.Page or not app.Page.mspapi then
            rfsuite.utils.log("App is closing. Skipping API error handling.", "debug")
            return
        end

        retryCount = retryCount + 1  
        app.Page.mspapi.retryCount[apiKey] = retryCount  

        if retryCount < 3 then  
            rfsuite.utils.log("[ERROR] API: " .. apiKey .. " failed (Retry " .. retryCount .. "): " .. tostring(err), "warning")
            rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)  
        else
            rfsuite.utils.log("[ERROR FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
            state.currentIndex = state.currentIndex + 1
            rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)  
        end
    end)

    API.read()
end

    -- Start processing the first API
    processNextAPI()
end

--[[
    Updates the current telemetry state. This function is called frequently to check the telemetry status.
    
    - If the system is not in simulation mode:
        - Sets telemetry state to `noSensor` if the RSSI sensor is not available.
        - Sets telemetry state to `noTelemetry` if the RSSI value is 0.
        - Sets telemetry state to `ok` if the RSSI value is valid.
    - If the system is in simulation mode, sets telemetry state to `ok`.
]]
function app.updateTelemetryState()

    if system:getVersion().simulation ~= true then
        if not rfsuite.session.telemetrySensor then
            app.triggers.telemetryState = app.telemetryStatus.noSensor
        elseif app.getRSSI() == 0 then
            app.triggers.telemetryState = app.telemetryStatus.noTelemetry
        else
            app.triggers.telemetryState = app.telemetryStatus.ok
        end
    else
        app.triggers.telemetryState = app.telemetryStatus.ok
    end


end

-- Function: app.paint
-- Description: Calls the paint method of the current page if it exists.
-- Note: This function is triggered by lcd.refresh and is not a wakeup function.
function app.paint()
    if app.Page and app.Page.paint then
        app.Page.paint(app.Page)
    end
end

-- This function is called to wake up the application.
-- It sets the `app.guiIsRunning` flag to true and then
-- calls the `app.wakeupUI` and `app.wakeupForm` functions
-- to initialize the user interface and form respectively.
-- @param widget The widget that triggered the wakeup.
function app.wakeup(widget)
    app.guiIsRunning = true

    app.wakeupUI()
    app.wakeupForm()
end

--[[
    Function: app.wakeupForm
    Description: Executes the wakeup function of the current page if it exists. This function acts as a timer for background processing on the loaded page.
    Preconditions:
        - app.Page must be defined.
        - app.uiState must be equal to app.uiStatus.pages.
        - app.Page.wakeup must be a valid function.
    Usage: Call this function to handle background processing for the current page.
]]
function app.wakeupForm()
    if app.Page and app.uiState == app.uiStatus.pages and app.Page.wakeup then
        -- run the pages wakeup function if it exists
        app.Page.wakeup(app.Page)
    end
end

--[[ 
    Function: app.wakeupUI
    Description: Handles the main UI wakeup routine for the Ethos forms. This function manages various triggers and states to ensure the UI operates efficiently and responds to user interactions and system events.
    
    Triggers and States Managed:
    - exitAPP: Exits the application if triggered.
    - closeProgressLoader: Accelerates the closing of the progress loader.
    - closeSave: Manages the save progress and closes the save loader.
    - closeSaveFake: Simulates the save process in a simulator environment.
    - profileSwitching: Handles profile switching and triggers reloads if necessary.
    - telemetryState: Manages telemetry state and displays no-link warnings.
    - triggerSave: Prompts the user to save settings.
    - triggerReloadNoPrompt: Triggers a reload without user prompt.
    - triggerReload: Prompts the user to reload data.
    - triggerReloadFull: Prompts the user to perform a full reload.
    - isSaving: Displays a progress box during the save process.
    - isSavingFake: Simulates the save process in a simulator environment.
    - showSaveArmedWarning: Displays a warning if saving while armed.
    - reload: Reloads the current page.
    - reloadFull: Performs a full reload of the current page.
    - audio alerts: Plays various audio alerts based on the current state and preferences.
]]
function app.wakeupUI()

    -- exit app called : quick abort
    -- as we dont need to run the rest of the stuff
    if app.triggers.exitAPP == true then
        app.triggers.exitAPP = false
        form.invalidate()
        system.exit()
        rfsuite.utils.reportMemoryUsage("Exit App")
        return
    end

    -- close progress loader.  this essentially just accelerates 
    -- the close of the progress bar once the data is loaded.
    -- so if not yet at 100%.. it says.. move there quickly
    if app.triggers.closeProgressLoader == true  then
        if app.dialogs.progressCounter >= 90 then
            app.dialogs.progressCounter = app.dialogs.progressCounter + 0.5
            if app.dialogs.progress ~= nil then app.ui.progressDisplayValue(app.dialogs.progressCounter) end
        else
            app.dialogs.progressCounter = app.dialogs.progressCounter + 2
            if app.dialogs.progress ~= nil then app.ui.progressDisplayValue(app.dialogs.progressCounter) end
        end

        if app.dialogs.progressCounter >= 101 and rfsuite.tasks.msp.mspQueue:isProcessed() then
            app.dialogs.progressWatchDog = nil
            app.dialogs.progressDisplay = false
            if app.dialogs.progress ~= nil then app.ui.progressDisplayClose() end
            app.dialogs.progressCounter = 0
            app.triggers.closeProgressLoader = false
        end
    end

    -- close save loader.  this essentially just accelerates 
    -- the close of the progress bar once the data is loaded.
    -- so if not yet at 100%.. it says.. move there quickly
    if app.triggers.closeSave == true then
        app.triggers.isSaving = false

        if rfsuite.tasks.msp.mspQueue:isProcessed() then
            if (app.dialogs.saveProgressCounter > 40 and app.dialogs.saveProgressCounter <= 80) then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 1.5
            elseif (app.dialogs.saveProgressCounter > 90) then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 1
            else
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 2
            end
        end

        if app.dialogs.save ~= nil then app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter) end

        if app.dialogs.saveProgressCounter >= 100 and rfsuite.tasks.msp.mspQueue:isProcessed() then
            app.triggers.closeSave = false
            app.dialogs.saveProgressCounter = 0
            app.dialogs.saveDisplay = false
            app.dialogs.saveWatchDog = nil
            if app.dialogs.save ~= nil then

                app.ui.progressDisplaySaveClose()

            end
        end
    end

    -- close progress loader when in sim.  
    -- the simulator cannot save - so we fake the whole process
    if app.triggers.closeSaveFake == true then
        app.triggers.isSaving = false

        app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5

        if app.dialogs.save ~= nil then app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter) end

        if app.dialogs.saveProgressCounter >= 100 then
            app.triggers.closeSaveFake = false
            app.dialogs.saveProgressCounter = 0
            app.dialogs.saveDisplay = false
            app.dialogs.saveWatchDog = nil
            app.ui.progressDisplaySaveClose()
        end
    end

    -- profile switching - trigger a reload when profile changes
    if app.Page ~= nil and (app.Page.refreshOnProfileChange == true or app.Page.refreshOnRateChange == true or app.Page.refreshFullOnProfileChange == true or app.Page.refreshFullOnRateChange == true) and app.uiState == app.uiStatus.pages and app.triggers.isSaving == false and rfsuite.app.dialogs.saveDisplay ~= true and rfsuite.app.dialogs.progressDisplay ~= true and rfsuite.tasks.msp.mspQueue:isProcessed() then

        local now = os.clock()
        local profileCheckInterval

        -- alter the interval for checking profile changes depenant of if using msp or not
        if (rfsuite.tasks.telemetry.getSensorSource("pid_profile") ~= nil and rfsuite.tasks.telemetry.getSensorSource("rate_profile") ~= nil) then
            profileCheckInterval = 0.1
        else
            profileCheckInterval = 1.5
        end

        if (now - app.profileCheckScheduler) >= profileCheckInterval then
            app.profileCheckScheduler = now

            rfsuite.utils.getCurrentProfile()

            if rfsuite.session.activeProfile ~= nil and rfsuite.session.activeProfileLast ~= nil then

                if app.Page.refreshOnProfileChange == true or  app.Page.refreshFullOnProfileChange == true then
                    if rfsuite.session.activeProfile ~= rfsuite.session.activeProfileLast and rfsuite.session.activeProfileLast ~= nil then
                        if app.Page.refreshFullOnProfileChange == true then
                            app.triggers.reloadFull = true
                        else
                            app.triggers.reload = true
                        end
                        return true
                    end
                end

            end

            if rfsuite.session.activeRateProfile ~= nil and rfsuite.session.activeRateProfileLast ~= nil then

                if app.Page.refreshOnRateChange == true or app.Page.refreshFullOnRateChange == true then
                    if rfsuite.session.activeRateProfile ~= rfsuite.session.activeRateProfileLast and rfsuite.session.activeRateProfileLast ~= nil then
                            if app.Page.refreshFullOnRateChange == true then
                                app.triggers.reloadFull = true
                            else
                                app.triggers.reload = true
                            end
                            return true
                    end
                end
            end

        end

    end

    if app.triggers.telemetryState ~= 1 and app.triggers.disableRssiTimeout == false then

        if rfsuite.app.dialogs.progressDisplay == true then app.ui.progressDisplayClose() end
        if rfsuite.app.dialogs.saveDisplay == true then app.ui.progressDisplaySaveClose() end

        if app.dialogs.nolinkDisplay == false and app.dialogs.nolinkDisplayErrorDialog ~= true and app.offlineMode ~= true then 
            app.ui.progressNolinkDisplay() 
        end
    end

    if (app.dialogs.nolinkDisplay == true) and app.triggers.disableRssiTimeout == false then

        app.dialogs.nolinkValueCounter = app.dialogs.nolinkValueCounter + 10

        if app.dialogs.nolinkValueCounter >= 101 then

            app.ui.progressNolinkDisplayClose()

            if app.guiIsRunning == true and app.triggers.invalidConnectionSetup ~= true and app.triggers.wasConnected == false then

                local buttons = {{
                    label = rfsuite.i18n.get("app.btn_ok"),
                    action = function()

                        app.triggers.exitAPP = true
                        app.dialogs.nolinkDisplayErrorDialog = false
                        return true
                    end
                }}

                local message
                local apiVersionAsString = tostring(rfsuite.session.apiVersion)
                local moduleState = (model.getModule(0):enable()  or model.getModule(1):enable()) or false
                local sportSensor = system.getSource({appId = 0xF101})
                local elrsSensor = system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1})

                if not rfsuite.utils.ethosVersionAtLeast() then
                    message = string.format(string.upper(rfsuite.i18n.get("ethos")).. " < V%d.%d.%d", 
                    rfsuite.config.ethosVersion[1], 
                    rfsuite.config.ethosVersion[2], 
                    rfsuite.config.ethosVersion[3])
                    app.triggers.invalidConnectionSetup = true
                elseif not rfsuite.tasks.active() then
                    message = rfsuite.i18n.get("app.check_bg_task") 
                    app.triggers.invalidConnectionSetup = true
                elseif  moduleState == false and app.offlineMode == false then
                    message = rfsuite.i18n.get("app.check_rf_module_on") 
                    app.triggers.invalidConnectionSetup = true 
                elseif not (sportSensor or elrsSensor)  and app.offlineMode == false then
                    message = rfsuite.i18n.get("app.check_discovered_sensors")
                    app.triggers.invalidConnectionSetup = true                                            
                elseif app.getRSSI() == 0 and app.offlineMode == false then
                    message =  rfsuite.i18n.get("app.check_heli_on")
                    app.triggers.invalidConnectionSetup = true
                elseif rfsuite.session.apiVersion == nil and app.offlineMode == false then
                    message = rfsuite.i18n.get("app.check_msp_version")
                    app.triggers.invalidConnectionSetup = true
                elseif not rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiVersionAsString) and app.offlineMode == false then
                    message = rfsuite.i18n.get("app.check_supported_version") .. " (" .. rfsuite.session.apiVersion .. ")."
                    app.triggers.invalidConnectionSetup = true
                end

                -- display message and abort if error occured
                if app.triggers.invalidConnectionSetup == true and app.triggers.wasConnected == false then

                    form.openDialog({
                        width = nil,
                        title = rfsuite.i18n.get("error"):gsub("^%l", string.upper),
                        message = message,
                        buttons = buttons,
                        wakeup = function()
                        end,
                        paint = function()
                        end,
                        options = TEXT_LEFT
                    })

                    app.dialogs.nolinkDisplayErrorDialog = true

                end

                app.dialogs.nolinkValueCounter = 0
                app.dialogs.nolinkDisplay = false

            else
                app.triggers.wasConnected = true
            end

        end
        app.ui.progressDisplayNoLinkValue(app.dialogs.nolinkValueCounter)
    end

    -- display a warning if we trigger one of these events
    -- we only show this if we are on an actual form for a page.
    -- a watchdog to enable the close button when saving data if we exheed the save timout
    if rfsuite.config.watchdogParam ~= nil and rfsuite.config.watchdogParam ~= 1 then app.protocol.saveTimeout = rfsuite.config.watchdogParam end
    if app.dialogs.saveDisplay == true then
        if app.dialogs.saveWatchDog ~= nil then
            if (os.clock() - app.dialogs.saveWatchDog) > (tonumber(app.protocol.saveTimeout + 5)) or (app.dialogs.saveProgressCounter > 120 and rfsuite.tasks.msp.mspQueue:isProcessed()) then
                app.audio.playTimeout = true
                app.ui.progressDisplaySaveMessage(rfsuite.i18n.get("app.error_timed_out"))
                app.ui.progressDisplaySaveCloseAllowed(true)
                app.dialogs.save:value(100)
                app.dialogs.saveProgressCounter = 0
                app.dialogs.saveDisplay = false
                app.triggers.isSaving = false

                app.Page = app.PageTmp
                app.PageTmp = {}
            end
        end
    end

    -- a watchdog to enable the close button on a progress box dialog when loading data from the fbl
    if app.dialogs.progressDisplay == true and app.dialogs.progressWatchDog ~= nil then

        app.dialogs.progressCounter = app.dialogs.progressCounter + (rfsuite.app.Page.progressCounter or 1.5)
        app.ui.progressDisplayValue(app.dialogs.progressCounter)

        if (os.clock() - app.dialogs.progressWatchDog) > (tonumber(rfsuite.tasks.msp.protocol.pageReqTimeout)) then

            app.audio.playTimeout = true

            if app.dialogs.progress ~= nil then
                app.ui.progressDisplayMessage(rfsuite.i18n.get("app.error_timed_out"))
                app.ui.progressDisplayCloseAllowed(true)
            end

            -- switch back to original page values
            app.Page = app.PageTmp
            app.PageTmp = {}
            app.dialogs.progressCounter = 0
            app.dialogs.progressDisplay = false
        end

    end

    -- a save was triggered - popup a box asking to save the data
    if app.triggers.triggerSave == true then
        local buttons = {{
            label = rfsuite.i18n.get("app.btn_ok"),
            action = function()

                -- we have to fake a save dialog in sim as its not actually possible 
                -- to save in sim!
                app.PageTmp = app.Page
                app.triggers.isSaving = true
                app.triggers.triggerSave = false


                saveSettings()
                return true
            end
        }, {
            label = rfsuite.i18n.get("app.btn_cancel"),
            action = function()
                app.triggers.triggerSave = false
                return true
            end
        }}
        local theTitle = rfsuite.i18n.get("app.msg_save_settings")
        local theMsg
        if rfsuite.app.Page.extraMsgOnSave then
            theMsg = rfsuite.i18n.get("app.msg_save_current_page") .. "\n\n" .. rfsuite.app.Page.extraMsgOnSave
        else    
            theMsg = rfsuite.i18n.get("app.msg_save_current_page")
        end


        form.openDialog({
            width = nil,
            title = theTitle,
            message = theMsg,
            buttons = buttons,
            wakeup = function()
            end,
            paint = function()
            end,
            options = TEXT_LEFT
        })

        app.triggers.triggerSave = false
    end

    if app.triggers.triggerSaveNoProgress == true then
        app.triggers.triggerSaveNoProgress = false
        app.PageTmp = app.Page     
        saveSettings()
    end     


    -- a reload that is pretty much instant with no prompt to ask them
    if app.triggers.triggerReloadNoPrompt == true then
        app.triggers.triggerReloadNoPrompt = false
        app.triggers.reload = true
    end

    -- a reload was triggered - popup a box asking for the reload to be done
    if app.triggers.triggerReload == true then
        local buttons = {{
            label = rfsuite.i18n.get("app.btn_ok"),
            action = function()
                -- trigger RELOAD
                app.triggers.reload = true
                return true
            end
        }, 
        {
            label = rfsuite.i18n.get("app.btn_cancel"),
            action = function()
                return true
            end
        }}
        form.openDialog({
            width = nil,
            title = rfsuite.i18n.get("reload"):gsub("^%l", string.upper),
            message = rfsuite.i18n.get("app.msg_reload_settings"),
            buttons = buttons,
            wakeup = function()
            end,
            paint = function()
            end,
            options = TEXT_LEFT
        })

        app.triggers.triggerReload = false
    end

   -- a full reload was triggered - popup a box asking for the reload to be done
   if app.triggers.triggerReloadFull == true then
    local buttons = {{
        label = rfsuite.i18n.get("app.btn_ok"),
        action = function()
            -- trigger RELOAD
            app.triggers.reloadFull = true
            return true
        end
    }, {
        label = rfsuite.i18n.get("app.btn_cancel"),
        action = function()
            return true
        end
    }}
    form.openDialog({
        width = nil,
        title = rfsuite.i18n.get("reload"):gsub("^%l", string.upper),
        message = rfsuite.i18n.get("app.msg_reload_settings"),
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

    app.triggers.triggerReloadFull = false
    end

    -- a save was triggered - lets display a progress box
    if app.triggers.isSaving then
        app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5
        if app.pageState >= app.pageStatus.saving then
            if app.dialogs.saveDisplay == false then
                app.triggers.saveFailed = false
                app.dialogs.saveProgressCounter = 0
                app.ui.progressDisplaySave()
                rfsuite.tasks.msp.mspQueue.retryCount = 0
            end
            if app.pageState == app.pageStatus.saving then
                app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter, rfsuite.i18n.get("app.msg_saving_settings"))
            elseif app.pageState == app.pageStatus.eepromWrite then
                app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter, rfsuite.i18n.get("app.msg_saving_settings"))
            elseif app.pageState == app.pageStatus.rebooting then
                app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter, rfsuite.i18n.get("app.msg_rebooting"))
            end

        else
            app.triggers.isSaving = false
            app.dialogs.saveDisplay = false
            app.dialogs.saveWatchDog = nil
        end
    elseif app.triggers.isSavingFake == true then

        if app.dialogs.saveDisplay == false then
            app.triggers.saveFailed = false
            app.dialogs.saveProgressCounter = 0
            app.ui.progressDisplaySave()
            rfsuite.tasks.msp.mspQueue.retryCount = 0
            app.triggers.closeSaveFake = true
            app.triggers.isSavingFake = false
        end
    end

    -- after saving show brief warning if armed 
    if app.triggers.showSaveArmedWarning == true and app.triggers.closeSave == false then
        if app.dialogs.progressDisplay == false then
            app.dialogs.progressCounter = 0
            if rfsuite.session.apiVersion >= 12.08 then
                app.ui.progressDisplay(rfsuite.i18n.get("app.msg_save_not_commited"), rfsuite.i18n.get("app.msg_please_disarm_to_save_warning"))
            else    
                app.ui.progressDisplay(rfsuite.i18n.get("app.msg_save_not_commited"), rfsuite.i18n.get("app.msg_please_disarm_to_save"))
            end    
        end
        if app.dialogs.progressCounter >= 100 then
            app.triggers.showSaveArmedWarning = false
            app.ui.progressDisplayClose()
        end
    end


    -- check we have telemetry
    app.updateTelemetryState()

    -- if we are on the home page - then ensure pages are invalidated
    if app.uiState == app.uiStatus.mainMenu then
        invalidatePages()
    elseif app.triggers.isReady and rfsuite.tasks.msp.mspQueue:isProcessed() and app.Page and app.Page.values then
        app.triggers.isReady = false
        app.triggers.closeProgressLoader = true
    end

    -- if we are viewing a page with form data then we need to run some stuff USED
    -- by the msp processing
    if app.uiState == app.uiStatus.pages then

        -- intercept and populate app.Page if it's empty
        if not app.Page and app.PageTmp then 
            app.Page = app.PageTmp 
        end

        -- trigger a request page if we have a page waiting to be retrieved
        if app.Page and app.Page.mspapi and app.pageState == app.pageStatus.display and app.triggers.isReady == false then 
            requestPage() 
        end

    end

    -- capture a reload request and load respective Page
    -- this needs to be done a little better as there is no need FOR
    -- all the menu case checks - we should just be able to do as a task
    -- when viewing the page
    if app.triggers.reload == true then
        app.ui.progressDisplay()
        app.triggers.reload = false
        app.ui.openPageRefresh(app.lastIdx, app.lastTitle, app.lastScript)
    end

    if app.triggers.reloadFull == true then
        app.ui.progressDisplay()
        app.triggers.reloadFull = false
        app.ui.openPage(app.lastIdx, app.lastTitle, app.lastScript)
    end

    -- play audio
    -- alerts 
    if app.audio.playEraseFlash == true then
        rfsuite.utils.playFile("app", "eraseflash.wav")
        app.audio.playEraseFlash = false
    end

    if app.audio.playTimeout == true then
        rfsuite.utils.playFile("app", "timeout.wav")
        app.audio.playTimeout = false
    end

    if app.audio.playEscPowerCycle == true then
        rfsuite.utils.playFile("app", "powercycleesc.wav")
        app.audio.playEscPowerCycle = false
    end

    if app.audio.playServoOverideEnable == true then
        rfsuite.utils.playFile("app", "soverideen.wav")
        app.audio.playServoOverideEnable = false
    end

    if app.audio.playServoOverideDisable == true then
        rfsuite.utils.playFile("app", "soveridedis.wav")
        app.audio.playServoOverideDisable = false
    end

    if app.audio.playMixerOverideEnable == true then
        rfsuite.utils.playFile("app", "moverideen.wav")
        app.audio.playMixerOverideEnable = false
    end

    if app.audio.playMixerOverideDisable == true then
        rfsuite.utils.playFile("app", "moveridedis.wav")
        app.audio.playMixerOverideDisable = false
    end

    if app.audio.playSaveArmed == true then
        rfsuite.utils.playFileCommon("warn.wav")
        app.audio.playSaveArmed = false
    end

    if app.audio.playBufferWarn == true then
        rfsuite.utils.playFileCommon("warn.wav")
        app.audio.playBufferWarn = false
    end


end

--[[
    Creates the log tool for the application.
    This function initializes various configurations and settings for the log tool,
    including disabling buffer warnings, setting the environment version, 
    determining the LCD dimensions, loading the radio configuration, 
    and setting the initial UI state. It also checks for developer mode, 
    updates the menu selection, displays the progress, and opens the logs page in offline mode.
]]
function app.create_logtool()
    triggers.showUnderUsedBufferWarning = false
    triggers.showOverUsedBufferWarning = false

    -- rfsuite.session.apiVersion = nil
    config.environment = system.getVersion()
    config.ethosRunningVersion = {config.environment.major, config.environment.minor, config.environment.revision}

    rfsuite.session.lcdWidth, rfsuite.session.lcdHeight = rfsuite.utils.getWindowSize()
    app.radio = assert(rfsuite.compiler.loadfile("app/radios.lua"))()

    app.uiState = app.uiStatus.init

    -- override developermode if file exists.
    if not rfsuite.preferences.developer.devtools and rfsuite.utils.file_exists("../developermode") then
        rfsuite.preferences.developer.devtools = true
    end

    rfsuite.app.menuLastSelected["mainmenu"] = pidx
    rfsuite.app.ui.progressDisplay()

    rfsuite.app.offlineMode = true
    rfsuite.app.ui.openPage(1, "Logs", "logs/logs.lua", 1) -- final param says to load in standalone mode
end

--[[
    Function: app.create

    Initializes the application by setting up the environment configuration, 
    determining the LCD dimensions, loading the radio configuration, 
    setting the initial UI state, and checking for developer mode.

    Steps:
    1. Sets the environment configuration using the system version.
    2. Retrieves and sets the LCD width and height.
    3. Loads the radio configuration from "app/radios.lua".
    4. Sets the initial UI state to 'init'.
    5. Checks for the existence of a developer mode file and enables developer mode if found.
    6. Opens the main menu UI.
]]
function app.create()

    -- rfsuite.session.apiVersion = nil
    config.environment = system.getVersion()
    config.ethosRunningVersion = {config.environment.major, config.environment.minor, config.environment.revision}

    rfsuite.session.lcdWidth, rfsuite.session.lcdHeight = rfsuite.utils.getWindowSize()
    app.radio = assert(rfsuite.compiler.loadfile("app/radios.lua"))()

    app.uiState = app.uiStatus.init

    -- override developermode if file exists.
    if not rfsuite.preferences.developer.devtools and rfsuite.utils.file_exists("../developermode") then
        rfsuite.preferences.developer.devtools = true
    end

    app.ui.openMainMenu()

end

--[[
Handles various events for the app, including key presses and page events.

Parameters:
- widget: The widget triggering the event.
- category: The category of the event.
- value: The value associated with the event.
- x: The x-coordinate of the event.
- y: The y-coordinate of the event.

Returns:
- 0 if a rapid exit is triggered.
- The return value of the page event handler if it handles the event.
- true if the event is handled by the generic event handler.
- false if the event is not handled.
]]
function app.event(widget, category, value, x, y)

    -- long press on return at any point will force an rapid exit
    if value == KEY_RTN_LONG then
        rfsuite.utils.log("KEY_RTN_LONG", "info")
        invalidatePages()
        system.exit()
        return 0
    end

    -- the page has its own event system.  we should use it.
    if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) then
        if app.Page.event then
            rfsuite.utils.log("USING PAGES EVENTS", "debug")
            local ret = app.Page.event(widget, category, value, x, y)
            if ret ~= nil then
                return ret
            end    
        end
    end

    -- generic events handler for most pages
    if app.uiState == app.uiStatus.pages then

        -- close button (top menu) should go back to main menu
        if category == EVT_CLOSE and value == 0 or value == 35 then
            rfsuite.utils.log("EVT_CLOSE", "info")
            if app.dialogs.progressDisplay then app.ui.progressDisplayClose() end
            if app.dialogs.saveDisplay then app.ui.progressDisplaySaveClose() end
            if app.Page.onNavMenu then app.Page.onNavMenu(app.Page) end
            app.ui.openMainMenu()
            return true
        end

        -- long press on enter should result in a save dialog box
        if value == KEY_ENTER_LONG then
            if rfsuite.app.Page.navButtons and rfsuite.app.Page.navButtons.save == false then
                return true
            end
            rfsuite.utils.log("EVT_ENTER_LONG (PAGES)", "info")
            if app.dialogs.progressDisplay then app.ui.progressDisplayClose() end
            if app.dialogs.saveDisplay then app.ui.progressDisplaySaveClose() end
            if rfsuite.app.Page and rfsuite.app.Page.onSaveMenu then
                rfsuite.app.Page.onSaveMenu(rfsuite.app.Page)
            else
                rfsuite.app.triggers.triggerSave = true
            end
            system.killEvents(KEY_ENTER_BREAK)
            return true
        end
    end

    -- catch all to stop lock press on main menu doing anything
    if app.uiState == app.uiStatus.mainMenu and value == KEY_ENTER_LONG then
         rfsuite.utils.log("EVT_ENTER_LONG (MAIN MENU)", "info")
         if app.dialogs.progressDisplay then app.ui.progressDisplayClose() end
         if app.dialogs.saveDisplay then app.ui.progressDisplaySaveClose() end
         system.killEvents(KEY_ENTER_BREAK)
         return true
    end

    return false
end

--[[
Closes the application and performs necessary cleanup operations.

This function sets the application state to indicate that the GUI is no longer running
and that the application is not in offline mode. It then checks if there is an active
page and if the current UI state is either in pages or main menu, and if so, it calls
the close method of the active page.

Additionally, it closes any open progress, save, or no-link dialogs. It then invalidates
the pages, resets the application state, and exits the system.

Returns:
    true: Always returns true to indicate successful closure.
]]
function app.close()
    app.guiIsRunning = false
    app.offlineMode = false
    app.uiState = app.uiStatus.init

    if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) and app.Page.close then
        app.Page.close()
    end

    if app.dialogs.progress then app.ui.progressDisplayClose() end
    if app.dialogs.save then app.ui.progressDisplaySaveClose() end
    if app.dialogs.noLink then app.ui.progressNolinkDisplayClose() end

    invalidatePages()
    app.resetState()
    system.exit()
    return true
end

return app
