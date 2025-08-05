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
local i18n = rfsuite.i18n.get
local utils = rfsuite.utils
local log = utils.log
local compile = rfsuite.compiler.loadfile

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
    Then, the UI library is loaded from "app/lib/ui.lua" using the compile function,
    and the result is assigned to app.ui. The config parameter is passed to the loaded file.

]]
app.ui = nil
app.ui = assert(compile("app/lib/ui.lua"))(config)


--[[
    Initializes the app.utils table and loads utility functions from the specified file.
    The utility functions are loaded from "app/lib/utils.lua" and are passed the 'config' parameter.
    If the file cannot be loaded, an error will be thrown.
]]
app.utils = nil



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
app.radio = {}
app.sensor = {}
app.init = nil
app.guiIsRunning = false
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
app.dialogs.progressRate = 0.25 

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
app.dialogs.saveRate = 0.25

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
app.dialogs.nolinkRate = 0.25

--[[
    This code snippet initializes two boolean flags within the `app.dialogs` table:
    - `badversion`: Indicates whether there is a bad version detected.
    - `badversionDisplay`: Controls the display state of the bad version dialog.
]]
app.dialogs.badversion = false
app.dialogs.badversionDisplay = false


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
            utils.onReboot()
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
        if rfsuite.session.isArmed then
          app.triggers.closeSave = true
          app.audio.playSaveArmed = true
          app.triggers.showSaveArmedWarning = true
        end  
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
            app.triggers.closeSave = true
            rfsuite.tasks.msp.mspQueue:add(mspEepromWrite)
        end
    elseif app.pageState ~= app.pageStatus.eepromWrite then
        -- If we're not already trying to write to eeprom from a previous save, then we're done.
        invalidatePages()
        app.triggers.closeSave = true
    end
    collectgarbage()
    utils.reportMemoryUsage("app.settingsSaved")
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
    log("Saving data", "debug")

    local mspapi = app.Page.apidata
    local apiList = mspapi.api
    local values = mspapi.values

    local totalRequests = #apiList  -- Total API calls to be made
    local completedRequests = 0      -- Counter for completed requests

    -- run a function in a module if it exists just prior to saving
    if app.Page.preSave then app.Page.preSave(app.Page) end

    for apiID, apiNAME in ipairs(apiList) do
        log("Saving data for API: " .. apiNAME, "debug")

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
            log("API " .. apiNAME .. " write complete", "debug")

            -- Check if this is the last completed request
            if completedRequests == totalRequests then
                log("All API requests have been completed!", "debug")
                
                -- Run the postSave function if it exists
                if app.Page.postSave then app.Page.postSave(app.Page) end

                -- we need to save to epprom etc
                app.settingsSaved()

            end
        end)

        -- Create lookup table for fields by apikey
        local fieldMap = {}
        local fieldMapBitmap = {}
        for fidx, f in ipairs(app.Page.apidata.formdata.fields) do
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
            log("Set value for " .. i .. " to " .. v, "debug")
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
    1. Ensures that `app.Page.apidata.formdata`, `app.Page.apidata.api`, and `app.Page.fields` exist.
    2. Defines a helper function `combined_api_parts` to split and convert API keys.
    3. Creates a reversed API table for quick lookups if it doesn't already exist.
    4. Iterates over the form fields and updates them based on the provided values and structure.
    5. Logs debug information and handles cases where fields or values are missing.
--]]
function app.mspApiUpdateFormAttributes(values, structure)

    -- Ensure app.Page and its mspapi.formdata exist
    if not (app.Page.apidata.formdata and app.Page.apidata.api and app.Page.fields) then
        log("app.Page.apidata.formdata or its components are nil", "debug")
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
                part1 = app.Page.apidata.api_reversed[part1] or nil
            end
    
            if part1 then
                return { part1, part2 }
            end
        end
    
        return nil
    end

    local fields = app.Page.apidata.formdata.fields
    local api = app.Page.apidata.api

    -- Create a reversed API table for quick lookups
    if not app.Page.apidata.api_reversed then
        app.Page.apidata.api_reversed = {}
        for index, value in pairs(app.Page.apidata.api) do
            app.Page.apidata.api_reversed[value] = index
        end
    end

    for i, f in ipairs(fields) do
        -- Define some key details
        local formField = app.formFields[i]

        if type(formField) == 'userdata' then

            -- Check if the field has an API key and extract the parts if needed
            -- we do not need to handle this on the save side as read has simple
            -- populated the mspapi and api fierds in the formdata.fields
            -- meaning they are already in the correct format
            if f.api then
                log("API field found: " .. f.api, "debug")
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
                log("API field missing mspapi or apikey", "debug")
            else        
                for _, v in ipairs(targetStructure) do

                    if not v.bitmap then
                        -- we have a standard api field - proceed to injecting values
                        if v.field == apikey and mspapiID == f.mspapi then

                            -- insert help string
                            local help_target = "api." .. mspapiNAME .. "." .. apikey
                            local help_return = i18n(help_target)
                            if help_target ~=  help_return then
                                v.help = help_return
                            else
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
                                    local help_return = i18n(help_target)
                                    if help_target ~=  help_return then
                                        v.help = help_return
                                    else
                                        v.help = nil    
                                    end

                                    app.ui.injectApiAttributes(formField, f, b)

                                    local scale = f.scale or 1

                                    -- extract bit at position bidx
                                    if values and values[mspapiNAME] and values[mspapiNAME][v.field] then
                                        local raw_value = values[mspapiNAME][v.field]
                                        local bit_value = (raw_value >> bidx - 1) & 1  
                                        app.Page.fields[i].value = bit_value / scale
                                    end
        
                                    if values[mspapiNAME][v.field] == nil then
                                        log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                                        formField:enable(false)
                                    end

                                    -- insert bit location for later reference
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
    collectgarbage()
    utils.reportMemoryUsage("app.mspApiUpdateFormAttributes")

    -- set focus back to menu
    app.formNavigationFields['menu']:focus(true)
end


--[[
    requestPage - Requests a page using the new API form system.

    This function ensures that the necessary API and form data exist, initializes
    the state if needed, and processes API calls sequentially. It prevents duplicate
    execution if already running and handles both API success and error cases.

    The function performs the following steps:
    1. Checks if app.Page.apidata and its api/formdata exist.
    2. Initializes the apiState if not already initialized.
    3. Prevents duplicate execution by checking the isProcessing flag.
    4. Initializes values and structure on the first run.
    5. Processes each API call sequentially using a recursive function.
    6. Handles API success by storing the response and moving to the next API.
    7. Handles API errors by logging the error and moving to the next API.
    8. Resets the state and triggers postRead and postLoad functions if they exist.

    Note: The function uses log for logging and rfsuite.tasks.msp.api.load
    for loading the API. It also updates form attributes and manages progress loader triggers.
]]
local function requestPage()
    -- Ensure app.Page and its mspapi.api exist
    if not app.Page.apidata then
        return
    end

    if not app.Page.apidata.api and not app.Page.apidata.formdata then
        log("app.Page.apidata.api did not pass consistancy checks", "debug")
        return
    end

    if not app.Page.apidata.apiState then
        app.Page.apidata.apiState = {
            currentIndex = 1,
            isProcessing = false
        }
    end    

    local apiList = app.Page.apidata.api
    local state = app.Page.apidata.apiState  -- Reference persistent state

    -- Prevent duplicate execution if already running
    if state.isProcessing then
        log("requestPage is already running, skipping duplicate call.", "debug")
        return
    end
    state.isProcessing = true  -- Set processing flag

    if not app.Page.apidata.values then
        log("requestPage Initialize values on first run", "debug")
        app.Page.apidata.values = {}  -- Initialize if first run
        app.Page.apidata.structure = {}  -- Initialize if first run
        app.Page.apidata.receivedBytesCount = {}  -- Initialize if first run
        app.Page.apidata.receivedBytes = {}  -- Initialize if first run
        app.Page.apidata.positionmap = {}  -- Initialize if first run
        app.Page.apidata.other = {} 
    end

    -- Ensure state.currentIndex is initialized
    if state.currentIndex == nil then
        state.currentIndex = 1
    end

-- Function to check for unresolved timeouts and trigger an alert
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
        -- disable all fields leaving only menu enabled
        app.ui.disableAllFields()
        app.ui.disableAllNavigationFields()
        app.ui.enableNavigationField('menu')
        app.triggers.closeProgressLoader = true
    end
end

-- Recursive function to process API calls sequentially
local function processNextAPI()
    -- **Exit gracefully if the app is closing**
    if not app or not app.Page or not app.Page.apidata then
        log("App is closing. Stopping processNextAPI.", "debug")
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

            app.mspApiUpdateFormAttributes(app.Page.apidata.values, app.Page.apidata.structure)

            if app.Page.postLoad then 
                app.Page.postLoad(app.Page) 
            else
                app.triggers.closeProgressLoader = true    
            end

            -- **Check for unresolved timeouts AFTER all APIs have been processed**
            checkForUnresolvedTimeouts()  -- 🔹 Added here
        end
        return
    end

    local v = apiList[state.currentIndex]
    local apiKey = type(v) == "string" and v or v.name 

    if not apiKey then
        log("API key is missing for index " .. tostring(state.currentIndex), "warning")
        state.currentIndex = state.currentIndex + 1
        rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)
        return
    end

    local API = rfsuite.tasks.msp.api.load(v)

    -- **Ensure retryCount table exists**
    if app and app.Page and app.Page.apidata then
        app.Page.apidata.retryCount = app.Page.apidata.retryCount or {}  
    end

    local retryCount = app.Page.apidata.retryCount[apiKey] or 0
    local handled = false

    -- **Log API Start**
    log("[PROCESS] API: " .. apiKey .. " (Attempt " .. (retryCount + 1) .. ")", "debug")

    -- **Timeout handler function**
    local function handleTimeout()
        if handled then return end
        handled = true  

        -- **Exit safely if app is closed**
        if not app or not app.Page or not app.Page.apidata then
            log("App is closing. Timeout handling skipped.", "debug")
            return
        end

        retryCount = retryCount + 1  
        app.Page.apidata.retryCount[apiKey] = retryCount  

        if retryCount < 3 then  
            log("[TIMEOUT] API: " .. apiKey .. " (Retry " .. retryCount .. ")", "warning")
            rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)  
        else
            log("[TIMEOUT FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
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
        if not app or not app.Page or not app.Page.apidata then
            log("App is closing. Skipping API success handling.", "debug")
            return
        end

        -- **Log API Success**
        log("[SUCCESS] API: " .. apiKey .. " completed successfully.", "debug")

        app.Page.apidata.values[apiKey] = API.data().parsed
        app.Page.apidata.structure[apiKey] = API.data().structure
        app.Page.apidata.receivedBytes[apiKey] = API.data().buffer
        app.Page.apidata.receivedBytesCount[apiKey] = API.data().receivedBytesCount
        app.Page.apidata.positionmap[apiKey] = API.data().positionmap
        app.Page.apidata.other[apiKey] = API.data().other or {}

        -- **Reset retry count on success**
        app.Page.apidata.retryCount[apiKey] = 0  

        state.currentIndex = state.currentIndex + 1
        rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)  
    end)

    -- **API error handler**
    API.setErrorHandler(function(self, err)
        if handled then return end
        handled = true  

        -- **Exit safely if app is closed**
        if not app or not app.Page or not app.Page.apidata then
            log("App is closing. Skipping API error handling.", "debug")
            return
        end

        retryCount = retryCount + 1  
        app.Page.apidata.retryCount[apiKey] = retryCount  

        if retryCount < 3 then  
            log("[ERROR] API: " .. apiKey .. " failed (Retry " .. retryCount .. "): " .. tostring(err), "warning")
            rfsuite.tasks.callback.inSeconds(0.5, processNextAPI)  
        else
            log("[ERROR FAIL] API: " .. apiKey .. " failed after 3 attempts. Skipping.", "error")
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
        elseif app.utils.getRSSI() == 0 then
            app.triggers.telemetryState = app.telemetryStatus.noTelemetry
        else
            app.triggers.telemetryState = app.telemetryStatus.ok
        end
    else
        app.triggers.telemetryState = app.telemetryStatus.noTelemetry
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

--[[
app._uiTasks

A table containing a sequence of functions, each representing a logical UI update or task for the Rotorflight Ethos Suite application. These tasks are executed in order to manage UI state, handle dialogs, process telemetry, and respond to user or system triggers.

Each function in the table is responsible for a specific aspect of the application's UI logic, including but not limited to:

1. Exiting the application and cleaning up resources.
2. Managing the progress loader dialog and its closure.
3. Handling the save loader dialog and its closure.
4. Simulating save progress in a simulator environment.
5. Detecting profile or rate changes and triggering UI reloads as needed.
6. Enabling or disabling main menu icons based on connection state and API version.
7. Displaying a "no-link" dialog when telemetry is lost or not established.
8. Updating the "no-link" progress and message based on connection diagnostics.
9. Monitoring save operation timeouts and handling failures.
10. Monitoring progress operation timeouts and handling failures.
11. Triggering save dialogs and handling user confirmation.
12. Triggering reload dialogs and handling user confirmation.
13. Displaying saving progress and managing save state transitions.
14. Warning the user if attempting to save while the system is armed.
15. Updating telemetry state and page readiness.
16. Triggering page retrieval when required.
17. Performing reload actions for the current or full page.
18. Playing pending audio alerts for various events.
19. Invoking page-specific wakeup functions if defined.

Each task function typically checks relevant triggers or state variables before performing its logic, ensuring that UI updates occur only when necessary. This modular approach allows for clear separation of concerns and easier maintenance of the UI update logic.
]]
app._uiTasks = {
  -- 1. Exit App
  function()
    if app.triggers.exitAPP then
      app.triggers.exitAPP = false
      form.invalidate()
      system.exit()
      utils.reportMemoryUsage("Exit App")
    end
  end,

  -- 2. Close Progress Loader
  function()
    if not app.triggers.closeProgressLoader then return end
    local p = app.dialogs.progressCounter
    local q = rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if p >= 90 then p = p + 10 else p = p + 15 end
    app.dialogs.progressCounter = p
    if app.dialogs.progress then
      app.ui.progressDisplayValue(p)
    end
    if p >= 101 and q and q:isProcessed() then
      app.dialogs.progressWatchDog = nil
      app.dialogs.progressDisplay  = false
      app.ui.progressDisplayClose()
      app.dialogs.progressCounter   = 0
      app.triggers.closeProgressLoader = false
    end
  end,

  -- 3. Close Save Loader
  function()
    if not app.triggers.closeSave then return end
    local p, q = app.dialogs.saveProgressCounter, rfsuite.tasks.msp.mspQueue
    app.triggers.isSaving = false
    if q:isProcessed() then
      if     p > 90 then p = p + 5
      elseif p > 40 then p = p + 15
      else                p = p + 5 end
    end
    app.dialogs.saveProgressCounter = p
    if app.dialogs.save then
      app.ui.progressDisplaySaveValue(p)
    end
    if p >= 100 and q:isProcessed() then
      app.triggers.closeSave           = false
      app.dialogs.saveProgressCounter  = 0
      app.dialogs.saveDisplay          = false
      app.dialogs.saveWatchDog         = nil
      app.ui.progressDisplaySaveClose()
    end
  end,

  -- 4. Close Save (Fake) in Simulator
  function()
    if not app.triggers.closeSaveFake then return end
    app.triggers.isSaving = false
    app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5
    if app.dialogs.save then
      app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter)
    end
    if app.dialogs.saveProgressCounter >= 100 then
      app.triggers.closeSaveFake          = false
      app.dialogs.saveProgressCounter     = 0
      app.dialogs.saveDisplay             = false
      app.dialogs.saveWatchDog            = nil
      app.ui.progressDisplaySaveClose()
    end
  end,

  -- 5. Profile / Rate Change Detection
  function()
    if not (app.Page and (app.Page.refreshOnProfileChange or app.Page.refreshOnRateChange or app.Page.refreshFullOnProfileChange or app.Page.refreshFullOnRateChange)
           and app.uiState == app.uiStatus.pages and not app.triggers.isSaving
           and not app.dialogs.saveDisplay and not app.dialogs.progressDisplay
           and rfsuite.tasks.msp.mspQueue:isProcessed()) then return end
    local now = os.clock();
    local interval = (rfsuite.tasks.telemetry.getSensorSource("pid_profile") and rfsuite.tasks.telemetry.getSensorSource("rate_profile"))
                     and 0.1 or 1.5
    if (now - (app.profileCheckScheduler or 0)) >= interval then
      app.profileCheckScheduler = now
      app.utils.getCurrentProfile()
      -- compare and trigger reloads
      if rfsuite.session.activeProfileLast and app.Page.refreshOnProfileChange and
         rfsuite.session.activeProfile ~= rfsuite.session.activeProfileLast then
        app.triggers.reload = not app.Page.refreshFullOnProfileChange
        app.triggers.reloadFull = app.Page.refreshFullOnProfileChange
        return
      end
      if rfsuite.session.activeRateProfileLast and app.Page.refreshOnRateChange and
         rfsuite.session.activeRateProfile ~= rfsuite.session.activeRateProfileLast then
        app.triggers.reload = not app.Page.refreshFullOnRateChange
        app.triggers.reloadFull = app.Page.refreshFullOnRateChange
        return
      end
    end
  end,

  -- 6. Main Menu Icon Enable/Disable
  function()
    if app.uiState ~= app.uiStatus.mainMenu and app.uiState ~= app.uiStatus.pages then return end
    if app.uiState == app.uiStatus.mainMenu then
      local apiV = tostring(rfsuite.session.apiVersion)

      if not rfsuite.session.isConnected then
        for i,v in pairs(app.formFieldsOffline) do
          if v == false then
            app.formFields[i]:enable(false)
          end
        end
      elseif rfsuite.session.apiVersion and app.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiV) then
        app.offlineMode = false
        for i in pairs(app.formFieldsOffline) do
          app.formFields[i]:enable(true)
        end
      end
    elseif not app.isOfflinePage then
      if not rfsuite.session.isConnected then app.ui.openMainMenu() end
    end
  end,

  -- 7. No-Link Initial Trigger
  function()
    if app.triggers.telemetryState == 1 or app.triggers.disableRssiTimeout then return end
    if not app.dialogs.nolinkDisplay and not app.triggers.wasConnected then
      if app.dialogs.progressDisplay then app.ui.progressDisplayClose() end
      if app.dialogs.saveDisplay then app.ui.progressDisplaySaveClose() end
      app.ui.progressNolinkDisplay()
      app.dialogs.nolinkDisplay = true
    end
  end,

  -- 8. No-Link Progress & Message Update
  function()
    if not (app.dialogs.nolinkDisplay and not app.triggers.wasConnected) then return end
    local apiStr = tostring(rfsuite.session.apiVersion)
    local moduleEnabled = model.getModule(0):enable() or model.getModule(1):enable()
    local sensorSport = system.getSource({appId=0xF101})
    local sensorElrs  = system.getSource({crsfId=0x14, subIdStart=0, subIdEnd=1})
    local curRssi    = app.utils.getRSSI()
    local invalid, abort = false, false
    local msg = i18n("app.msg_connecting_to_fbl")
    if not utils.ethosVersionAtLeast() then
      msg = string.format("%s < V%d.%d.%d", string.upper(i18n("ethos")), table.unpack(rfsuite.config.ethosVersion))
    elseif not rfsuite.tasks.active() then
      msg, invalid, abort = i18n("app.check_bg_task"), true, true
    elseif not moduleEnabled and not app.offlineMode then
      msg, invalid = i18n("app.check_rf_module_on"), true
    elseif not (sensorSport or sensorElrs) and not app.offlineMode then
      msg, invalid = i18n("app.check_discovered_sensors"), true
    elseif curRssi == 0 and not app.offlineMode then
      msg, invalid = i18n("app.check_heli_on"), true
    elseif not app.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiStr) and not app.offlineMode then
      msg = i18n("app.check_supported_version") .. " (" .. apiStr .. ")"
    end
    app.triggers.invalidConnectionSetup = invalid
    local step = invalid and 5 or 10
    app.dialogs.nolinkValueCounter = app.dialogs.nolinkValueCounter + step
    app.ui.progressDisplayNoLinkValue(app.dialogs.nolinkValueCounter, msg)
    if invalid and app.dialogs.nolinkValueCounter == 10 then app.audio.playBufferWarn = true end
    if app.dialogs.nolinkValueCounter >= 100 then
      app.dialogs.nolinkDisplay = false
      app.triggers.wasConnected    = true
      app.ui.progressNolinkDisplayClose()
      if abort then app.close() end
    end
  end,

  -- 9. Save Timeout Watchdog
  function()
    if not app.dialogs.saveDisplay or not app.dialogs.saveWatchDog then return end
    local timeout = tonumber(rfsuite.tasks.msp.protocol.saveTimeout + 5)
    if (os.clock() - app.dialogs.saveWatchDog) > timeout or (app.dialogs.saveProgressCounter > 120 and rfsuite.tasks.msp.mspQueue:isProcessed()) then
      app.audio.playTimeout = true
      app.ui.progressDisplaySaveMessage(i18n("app.error_timed_out"))
      app.ui.progressDisplaySaveCloseAllowed(true)
      app.dialogs.save:value(100)
      app.dialogs.saveProgressCounter = 0
      app.dialogs.saveDisplay = false
      app.triggers.isSaving = false
      app.Page = app.PageTmp
      app.PageTmp = nil
    end
  end,

  -- 10. Progress Timeout Watchdog
  function()
    if not app.dialogs.progressDisplay or not app.dialogs.progressWatchDog then return end
    app.dialogs.progressCounter = app.dialogs.progressCounter + (app.Page and app.Page.progressCounter or 1.5)
    app.ui.progressDisplayValue(app.dialogs.progressCounter)
    if (os.clock() - app.dialogs.progressWatchDog) > tonumber(rfsuite.tasks.msp.protocol.pageReqTimeout) then
      app.audio.playTimeout = true
      app.ui.progressDisplayMessage(i18n("app.error_timed_out"))
      app.ui.progressDisplayCloseAllowed(true)
      app.Page = app.PageTmp
      app.PageTmp = nil
      app.dialogs.progressCounter = 0
      app.dialogs.progressDisplay = false
    end
  end,

  -- 11. Trigger Save Dialogs
  function()
    if app.triggers.triggerSave then
      app.triggers.triggerSave = false
      form.openDialog({
        width   = nil,
        title   = i18n("app.msg_save_settings"),
        message = (app.Page.extraMsgOnSave and
                   i18n("app.msg_save_current_page").."\n\n"..app.Page.extraMsgOnSave or
                   i18n("app.msg_save_current_page")),
        buttons = {{ label=i18n("app.btn_ok"), action=function()
          app.PageTmp = app.Page

          app.triggers.isSaving = true
          saveSettings()
          return true
        end },{ label=i18n("app.btn_cancel"),action=function() return true end }},
        wakeup = function() end,
        paint  = function() end,
        options= TEXT_LEFT
      })
    elseif app.triggers.triggerSaveNoProgress then
      app.triggers.triggerSaveNoProgress = false
      app.PageTmp = app.Page
      saveSettings()
    end
  end,

  -- 12. Trigger Reload Dialogs
  function()
    if app.triggers.triggerReloadNoPrompt then
      app.triggers.triggerReloadNoPrompt = false
      app.triggers.reload = true
      return
    end
    if app.triggers.triggerReload then
      app.triggers.triggerReload = false
      form.openDialog({
        title   = i18n("reload"):gsub("^%l", string.upper),
        message = i18n("app.msg_reload_settings"),
        buttons = {{ label=i18n("app.btn_ok"), action=function() app.triggers.reload = true; return true end },
                   { label=i18n("app.btn_cancel"), action=function() return true end }},
        options = TEXT_LEFT
      })
    elseif app.triggers.triggerReloadFull then
      app.triggers.triggerReloadFull = false
      form.openDialog({
        title   = i18n("reload"):gsub("^%l", string.upper),
        message = i18n("app.msg_reload_settings"),
        buttons = {{ label=i18n("app.btn_ok"), action=function() app.triggers.reloadFull = true; return true end },
                   { label=i18n("app.btn_cancel"), action=function() return true end }},
        options = TEXT_LEFT
      })
    end
  end,

  -- 13. Saving Progress Display
  function()
    if app.triggers.isSaving then
      app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5
      if app.pageState >= app.pageStatus.saving then
        if not app.dialogs.saveDisplay then
          app.triggers.saveFailed          = false
          app.dialogs.saveProgressCounter  = 0
          app.ui.progressDisplaySave()
          rfsuite.tasks.msp.mspQueue.retryCount = 0
        end
        local msg = ({[app.pageStatus.saving] = "app.msg_saving_settings",
                     [app.pageStatus.eepromWrite] = "app.msg_saving_settings",
                     [app.pageStatus.rebooting]   = "app.msg_rebooting"})[app.pageState]
        app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter, i18n(msg))
      else
        app.triggers.isSaving      = false
        app.dialogs.saveDisplay    = false
        app.dialogs.saveWatchDog   = nil
      end
    elseif app.triggers.isSavingFake then
      app.triggers.isSavingFake = false
      app.triggers.closeSaveFake = true
    end
  end,

  -- 14. Armed-Save Warning
  function()
    if not app.triggers.showSaveArmedWarning or app.triggers.closeSave then return end
    if not app.dialogs.progressDisplay then
      app.dialogs.progressCounter = 0
      local key = (rfsuite.session.apiVersion >= 12.08 and "app.msg_please_disarm_to_save_warning" or "app.msg_please_disarm_to_save")
      app.ui.progressDisplay(
        i18n("app.msg_save_not_commited"),
        i18n(key)
      )
    end
    if app.dialogs.progressCounter >= 100 then
      app.triggers.showSaveArmedWarning = false
      app.ui.progressDisplayClose()
    end
  end,

  -- 15. Telemetry & Page State Updates
  function()
    app.updateTelemetryState()
    if app.uiState == app.uiStatus.mainMenu then
      invalidatePages()
    elseif app.triggers.isReady and rfsuite.tasks.msp.mspQueue:isProcessed()
           and app.Page and app.Page.values then
      app.triggers.isReady           = false
      app.triggers.closeProgressLoader = true
    end
  end,

  -- 16. Page Retrieval Trigger
  function()
    if app.uiState == app.uiStatus.pages then
      if not app.Page and app.PageTmp then app.Page = app.PageTmp end
      if app.Page and app.Page.apidata and app.pageState == app.pageStatus.display
         and not app.triggers.isReady then
        requestPage()
      end
    end
  end,

  -- 17. Perform Reload Actions
  function()
    if app.triggers.reload then
      app.triggers.reload = false
      app.ui.progressDisplay()
      app.ui.openPageRefresh(app.lastIdx, app.lastTitle, app.lastScript)
    end
    if app.triggers.reloadFull then
      app.triggers.reloadFull = false
      app.ui.progressDisplay()
      app.ui.openPage(app.lastIdx, app.lastTitle, app.lastScript)
    end
  end,

  -- 18. Play Pending Audio Alerts
  function()
    local a = app.audio
    if a.playEraseFlash         then utils.playFile("app","eraseflash.wav");            a.playEraseFlash = false end
    if a.playTimeout            then utils.playFile("app","timeout.wav");               a.playTimeout = false end
    if a.playEscPowerCycle      then utils.playFile("app","powercycleesc.wav");        a.playEscPowerCycle = false end
    if a.playServoOverideEnable then utils.playFile("app","soverideen.wav");           a.playServoOverideEnable = false end
    if a.playServoOverideDisable then utils.playFile("app","soveridedis.wav");        a.playServoOverideDisable = false end
    if a.playMixerOverideEnable then utils.playFile("app","moverideen.wav");           a.playMixerOverideEnable = false end
    if a.playMixerOverideDisable then utils.playFile("app","moveridedis.wav");        a.playMixerOverideDisable = false end
    if a.playSaveArmed          then utils.playFileCommon("warn.wav");                  a.playSaveArmed = false end
    if a.playBufferWarn         then utils.playFileCommon("warn.wav");                  a.playBufferWarn = false end
  end,

  -- 19. Wakeup UI Tasks
  function()
        if app.Page and app.uiState == app.uiStatus.pages and app.Page.wakeup then
            -- run the pages wakeup function if it exists
            app.Page.wakeup(app.Page)
        end
  end,
}

--- Handles periodic execution of UI tasks in a round-robin fashion.
-- This function is intended to be called regularly (e.g., on each system wakeup or tick).
-- It distributes the execution of tasks in `app._uiTasks` based on the configured percentage (`app._uiTaskPercent`),
-- ensuring that at least one task is executed per tick. The function uses an accumulator to handle fractional
-- task execution rates and maintains the index of the next task to execute in `app._nextUiTask`.
-- Tasks are executed in order, wrapping around to the beginning of the list as needed.
app._nextUiTask         = 1   -- accumulator for fractional tasks per tick
app._taskAccumulator    = 0   -- desired throughput percentage of total tasks per tick (0-100)
app._uiTaskPercent      = 50  -- e.g., 80% of tasks each tick
function app.wakeup()

  -- mark gui as active
  app.guiIsRunning = true

  local total = #app._uiTasks
  local tasksThisTick = math.max(1, (total * app._uiTaskPercent) / 100)

  app._taskAccumulator = app._taskAccumulator + tasksThisTick

  while app._taskAccumulator >= 1 do
    local idx = app._nextUiTask
    app._uiTasks[idx]()
    app._nextUiTask = (idx % total) + 1
    app._taskAccumulator = app._taskAccumulator - 1
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

    app.lcdWidth, app.lcdHeight = lcd.getWindowSize()
    app.radio = assert(compile("app/radios.lua"))()

    app.uiState = app.uiStatus.init

    rfsuite.preferences.menulastselected["mainmenu"] = pidx
    app.ui.progressDisplay()

    app.offlineMode = true
    app.ui.openPage(1, "Logs", "logs/logs.lua", 1) -- final param says to load in standalone mode
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

    app.lcdWidth, app.lcdHeight = lcd.getWindowSize()
    app.radio = assert(compile("app/radios.lua"))()

    app.uiState = app.uiStatus.init

    if not app.MainMenu then
        app.MainMenu  = assert(compile("app/modules/init.lua"))()
    end

    if not app.ui then
        app.ui = assert(compile("app/lib/ui.lua"))(config)
    end

    if not app.utils then
        app.utils = assert(compile("app/lib/utils.lua"))(config)
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
        log("KEY_RTN_LONG", "info")
        invalidatePages()
        system.exit()
        return 0
    end

    -- the page has its own event system.  we should use it.
    if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) then
        if app.Page.event then
            log("USING PAGES EVENTS", "debug")
            local ret = app.Page.event(widget, category, value, x, y)
            if ret ~= nil then
                return ret
            end    
        end
    end

    -- catch exit from sub menu
    if app.uiState == app.uiStatus.mainMenu and app.lastMenu ~= nil and value == 35 then
        app.ui.openMainMenu()
        return true
    end

    -- catch exit from sub menu
    if rfsuite.app.lastMenu ~= nil and category == 3 and value == 0 then
        app.ui.openMainMenu()
        return true
    end    

    -- generic events handler for most pages
    if app.uiState == app.uiStatus.pages then

        -- close button (top menu) should go back to main menu
        if category == EVT_CLOSE and value == 0 or value == 35 then
            log("EVT_CLOSE", "info")
            if app.dialogs.progressDisplay then app.ui.progressDisplayClose() end
            if app.dialogs.saveDisplay then app.ui.progressDisplaySaveClose() end
            if app.Page.onNavMenu then app.Page.onNavMenu(app.Page) end
            if  app.lastMenu == nil then
                app.ui.openMainMenu()
            else
                app.ui.openMainMenuSub(app.lastMenu)
            end
            return true
        end

        -- long press on enter should result in a save dialog box
        if value == KEY_ENTER_LONG then
            if app.Page.navButtons and app.Page.navButtons.save == false then
                return true
            end
            log("EVT_ENTER_LONG (PAGES)", "info")
            if app.dialogs.progressDisplay then app.ui.progressDisplayClose() end
            if app.dialogs.saveDisplay then app.ui.progressDisplaySaveClose() end
            if app.Page and app.Page.onSaveMenu then
                app.Page.onSaveMenu(app.Page)
            else
                app.triggers.triggerSave = true
            end
            system.killEvents(KEY_ENTER_BREAK)
            return true
        end
    end

    -- catch all to stop lock press on main menu doing anything
    if app.uiState == app.uiStatus.mainMenu and value == KEY_ENTER_LONG then
         log("EVT_ENTER_LONG (MAIN MENU)", "info")
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

    rfsuite.utils.reportMemoryUsage("closing application: start")

    -- save user preferences
    local userpref_file = "SCRIPTS:/" .. rfsuite.config.preferences .. "/preferences.ini"
    rfsuite.ini.save_ini_file(userpref_file, rfsuite.preferences)

    app.guiIsRunning = false
    app.offlineMode = false
    app.uiState = app.uiStatus.init

    if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) and app.Page.close then
        app.Page.close()
    end

    if app.dialogs.progress and app.ui then app.ui.progressDisplayClose() end
    if app.dialogs.save and app.ui then app.ui.progressDisplaySaveClose() end
    if app.dialogs.noLink and app.ui then app.ui.progressNolinkDisplayClose() end


    -- Reset configuration and compiler flags
    config.useCompiler = true
    rfsuite.config.useCompiler = true

    -- Reset page and navigation state
    pageLoaded = 100
    pageTitle = nil
    pageFile = nil
    app.Page = {}
    app.formFields = {}
    app.formNavigationFields = {}
    app.gfx_buttons = {}
    app.formLines = nil
    app.MainMenu = nil
    app.formNavigationFields = {}
    app.PageTmp = nil
    app.moduleList = nil
    app.utils = nil
    app.ui = nil

    -- Reset triggers
    app.triggers.exitAPP = false
    app.triggers.noRFMsg = false
    app.triggers.telemetryState = nil
    app.triggers.wasConnected = false
    app.triggers.invalidConnectionSetup = false
    app.triggers.disableRssiTimeout = false

    -- Reset dialogs
    app.dialogs.nolinkDisplay = false
    app.dialogs.nolinkValueCounter = 0
    app.dialogs.progressDisplayEsc = false

    -- Reset audio
    app.audio = {}

    -- Reset telemetry and protocol state
    ELRS_PAUSE_TELEMETRY = false
    CRSF_PAUSE_TELEMETRY = false

    -- Reset profile/rate state
    app.triggers.profileswitchLast = nil
    rfsuite.session.activeProfileLast = nil
    rfsuite.session.activeProfile = nil
    rfsuite.session.activeRateProfile = nil
    rfsuite.session.activeRateProfileLast = nil
    rfsuite.session.activeRateTable = nil

    -- Cleanup
    collectgarbage()
    invalidatePages()

    -- print out whats left
    --log("Application closed. Remaining tables:", "info")
    --for i,v in pairs(rfsuite.app) do
    --        log("   ->" .. tostring(i) .. " = " .. tostring(v), "info")
    --end

    rfsuite.utils.reportMemoryUsage("closing application: end")    

    system.exit()
    return true
end

return app
