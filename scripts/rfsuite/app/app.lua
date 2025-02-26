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

local triggers = {}
triggers.exitAPP = false
triggers.noRFMsg = false
triggers.triggerSave = false
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

rfsuite.session.tailMode = nil
rfsuite.session.swashMode = nil
rfsuite.session.activeProfile = nil
rfsuite.session.activeRateProfile = nil
rfsuite.session.activeProfileLast = nil
rfsuite.session.activeRateLast = nil
rfsuite.session.servoCount = nil
rfsuite.session.servoOverride = nil
rfsuite.session.clockSet = nil

app.triggers = {}
app.triggers = triggers

app.ui = {}
app.ui = assert(loadfile("app/lib/ui.lua"))(config)
app.utils = {}
app.utils = assert(loadfile("app/lib/utils.lua"))(config)


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

app.audio = {}
app.audio.playDemo = false
app.audio.playConnecting = false
app.audio.playConnected = false
app.audio.playTimeout = false
app.audio.playSaving = false
app.audio.playLoading = false
app.audio.playEscPowerCycle = false
app.audio.playServoOverideDisable = false
app.audio.playServoOverideEnable = false
app.audio.playMixerOverideDisable = false
app.audio.playMixerOverideEnable = false
app.audio.playEraseFlash = false
app.offlineMode = false

app.dialogs = {}
app.dialogs.progress = false
app.dialogs.progressDisplay = false
app.dialogs.progressWatchDog = nil
app.dialogs.progressCounter = 0
app.dialogs.progressRateLimit = os.clock()
app.dialogs.progressRate = 0.2 -- how many times per second we can change dialog value

app.dialogs.progressESC = false
app.dialogs.progressDisplayEsc = false
app.dialogs.progressWatchDogESC = nil
app.dialogs.progressCounterESC = 0
app.dialogs.progressESCRateLimit = os.clock()
app.dialogs.progressESCRate = 2.5 -- how many times per second we can change dialog value

app.dialogs.save = false
app.dialogs.saveDisplay = false
app.dialogs.saveWatchDog = nil
app.dialogs.saveProgressCounter = 0
app.dialogs.saveRateLimit = os.clock()
app.dialogs.saveRate = 0.2 -- how many times per second we can change dialog value

app.dialogs.nolink = false
app.dialogs.nolinkDisplay = false
app.dialogs.nolinkValueCounter = 0
app.dialogs.nolinkRateLimit = os.clock()
app.dialogs.nolinkRate = 0.2 -- how many times per second we can change dialog value

app.dialogs.badversion = false
app.dialogs.badversionDisplay = false

rfsuite.config.saveTimeout = nil
rfsuite.config.requestTimeout = nil
rfsuite.config.maxRetries = nil
rfsuite.config.lcdWidth = nil
rfsuite.config.lcdHeight = nil
rfsuite.config.ethosRunningVersion = nil

-- RETURN THE CURRENT RSSI SENSOR VALUE 
function app.getRSSI()
    if system:getVersion().simulation == true or rfsuite.preferences.skipRssiSensorCheck == true or app.offlineMode == true then return 100 end

    if rfsuite.tasks.telemetry.active() == true then
        return 100
    else
        return 0
    end
end

-- RESET ALL VALUES TO DEFAULTS. FUNCTION IS CALLED WHEN THE CLOSE EVENT RUNS
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

-- RETURN CURRENT LCD SIZE
function app.getWindowSize()
    return lcd.getWindowSize()
end

-- INAVALIDATE THE PAGES VARIABLE. TYPICALLY CALLED AFTER WRITING MSP DATA
local function invalidatePages()
    app.Page = nil
    app.pageState = app.pageStatus.display
    app.saveTS = 0
end

-- ISSUE AN MSP COMNMAND TO REBOOT THE FBL UNIT
local function rebootFc()

    app.pageState = app.pageStatus.rebooting
    rfsuite.tasks.msp.mspQueue:add({
        command = 68, -- MSP_REBOOT
        processReply = function(self, buf)
            invalidatePages()
        end,
        simulatorResponse = {}
    })
end

-- ISSUE AN MSP COMMAND TO TELL THE FBL TO WRITE THE DATA TO EPPROM
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
        if rfsuite.preferences.saveWhenArmedWarning == true then app.triggers.showSaveArmedWarning = true end
    end,
    simulatorResponse = {}
}

-- SAVE ALL SETTINGS 
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
end

-- Save all settings
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

        -- Inject values into the payload
        for i, v in pairs(payloadData) do    
            for fidx, f in ipairs(app.Page.mspapi.formdata.fields) do
                if f.apikey == i and f.mspapi == apiID then
                    payloadData[i] = app.Page.fields[fidx].value
                end
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

-- Update the page with the new values received from the MSP and API structures
-- we do both initial values and attributes in one loop to preven to many cascading loops
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

                    if v.field == apikey and mspapiID == f.mspapi then
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
                end
            end
        else
            rfsuite.utils.log("Form field skipped; not valid for this api version?", "debug")    
        end    
    end
end


-- REQUEST A PAGE USING THE NEW API FORM SYSTEM
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
    end

    -- Ensure state.currentIndex is initialized
    if state.currentIndex == nil then
        state.currentIndex = 1
    end

    -- Recursive function to process API calls sequentially
    local function processNextAPI()
        if state.currentIndex > #apiList or #apiList == 0 then
            if state.isProcessing then  -- Ensure this runs only once
                state.isProcessing = false  -- Reset processing flag
                state.currentIndex = 1  -- Reset for next run

                app.triggers.isReady = true

                -- Run the postRead function if it exists
                if app.Page.postRead then app.Page.postRead(app.Page) end

                -- Populate the form fields with data
                app.mspApiUpdateFormAttributes(app.Page.mspapi.values,app.Page.mspapi.structure)

                -- Run the postLoad function if it exists
                -- if postload exits.. then it must take responsibility for 
                -- closing the progress dialog.
                if app.Page.postLoad then 
                    app.Page.postLoad(app.Page) 
                else
                    rfsuite.app.triggers.closeProgressLoader = true    
                end
            end
            return
        end

        local v = apiList[state.currentIndex]
        local apiKey = type(v) == "string" and v or v.name  -- Use API name or unique key

        if not apiKey then
            rfsuite.utils.log("API key is missing for index " .. tostring(state.currentIndex), "debug")
            state.currentIndex = state.currentIndex + 1
            processNextAPI()
            return
        end

        local API = rfsuite.tasks.msp.api.load(v)

        -- Handle API success
        API.setCompleteHandler(function(self, buf)

            if app.Page and app.Page.mspapi then
                -- Store API response with API name as the key
                app.Page.mspapi.values[apiKey] = API.data().parsed

                -- Store the structure with the API name as the key
                app.Page.mspapi.structure[apiKey] = API.data().structure

                -- Move to the next API
                state.currentIndex = state.currentIndex + 1
                processNextAPI()
            end    
        end)

        -- Handle API errors
        API.setErrorHandler(function(self, err)
            rfsuite.utils.log("API error for " .. apiKey .. ": " .. tostring(err), "debug")

            -- Move to the next API even if there's an error
            state.currentIndex = state.currentIndex + 1
            processNextAPI()
        end)

        API.read()
    end

    -- Start processing the first API
    processNextAPI()
end

-- UPDATE CURRENT TELEMETRY STATE - RUNS MOST CLOCK CYCLES
function app.updateTelemetryState()

    if system:getVersion().simulation ~= true then
        if not rfsuite.session.rssiSensor then
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

-- PAINT.  HOOK INTO PAINT FUNCTION TO ALLOW lcd FUNCTIONS TO BE USED
-- NOTE. this function will only be called if lcd.refesh is triggered. it is not a wakeup function
function app.paint()
    if app.Page and app.Page.paint then
        app.Page.paint(app.Page)
    end
end


function app.wakeup(widget)
    app.guiIsRunning = true

    app.wakeupUI()
    app.wakeupForm()
end

-- WAKEUPFORM.  RUN A FUNCTION CALLED wakeup THAT IS RETURNED WHEN REQUESTING A PAGE
-- THIS ESSENTIALLY GIVES US A TIMER THAT CAN BE USED BY A PAGE THAT HAS LOADED TO
-- HANDLE BACKGROUND PROCESSING
function app.wakeupForm()
    if app.Page and app.uiState == app.uiStatus.pages and app.Page.wakeup then
        -- run the pages wakeup function if it exists
        app.Page.wakeup(app.Page)
    end
end

-- WAKUP UI.  UI RUNS AT LOWER INTERVAL, TO SAVE CPU POWER.
-- THE GUTS OF ETHOS FORMS IS HANDLED WITHIN THIS FUNCTION
function app.wakeupUI()

    -- exit app called : quick abort
    -- as we dont need to run the rest of the stuff
    if app.triggers.exitAPP == true then
        app.triggers.exitAPP = false
        form.invalidate()
        system.exit()
        return
    end

    -- close progress loader.  this essentially just accelerates 
    -- the close of the progress bar once the data is loaded.
    -- so if not yet at 100%.. it says.. move there quickly
    if app.triggers.closeProgressLoader == true then
        if app.dialogs.progressCounter >= 90 then
            app.dialogs.progressCounter = app.dialogs.progressCounter + 0.5
            if app.dialogs.progress ~= nil then app.ui.progressDisplayValue(app.dialogs.progressCounter) end
        else
            app.dialogs.progressCounter = app.dialogs.progressCounter + 10
            if app.dialogs.progress ~= nil then app.ui.progressDisplayValue(app.dialogs.progressCounter) end
        end

        if app.dialogs.progressCounter >= 101 then
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
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5
            elseif (app.dialogs.saveProgressCounter > 90) then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 2
            else
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5
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

                if rfsuite.preferences.reloadOnSave == true then app.triggers.triggerReloadNoPrompt = true end

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
    if rfsuite.preferences.profileSwitching == true and app.Page ~= nil and (app.Page.refreshOnProfileChange == true or app.Page.refreshOnRateChange == true or app.Page.refreshFullOnProfileChange == true or app.Page.refreshFullOnRateChange == true) and app.uiState == app.uiStatus.pages and app.triggers.isSaving == false and rfsuite.app.dialogs.saveDisplay ~= true and rfsuite.app.dialogs.progressDisplay ~= true and rfsuite.tasks.msp.mspQueue:isProcessed() then

        local now = os.clock()
        local profileCheckInterval

        -- alter the interval for checking profile changes depenant of if using msp or not
        if (rfsuite.tasks.telemetry.getSensorSource("pidProfile") ~= nil and rfsuite.tasks.telemetry.getSensorSource("rateProfile") ~= nil) then
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

        if app.dialogs.nolinkDisplay == false and app.dialogs.nolinkDisplayErrorDialog ~= true then 
            app.ui.progressNolinkDisplay() 
        end
    end

    if (app.dialogs.nolinkDisplay == true) and app.triggers.disableRssiTimeout == false then

        app.dialogs.nolinkValueCounter = app.dialogs.nolinkValueCounter + 10

        if app.dialogs.nolinkValueCounter >= 101 then

            app.ui.progressNolinkDisplayClose()

            if app.guiIsRunning == true and app.triggers.invalidConnectionSetup ~= true and app.triggers.wasConnected == false then

                local buttons = {{
                    label = "   OK   ",
                    action = function()

                        app.triggers.exitAPP = true
                        app.dialogs.nolinkDisplayErrorDialog = false
                        return true
                    end
                }}

                local message
                local apiVersionAsString = tostring(rfsuite.session.apiVersion)
                if not rfsuite.utils.ethosVersionAtLeast() then
                    message = string.format("ETHOS < V%d.%d.%d", 
                    rfsuite.config.ethosVersion[1], 
                    rfsuite.config.ethosVersion[2], 
                    rfsuite.config.ethosVersion[3])
                    app.triggers.invalidConnectionSetup = true
                elseif not rfsuite.tasks.active() then
                    message = "Please enable the background task."
                    app.triggers.invalidConnectionSetup = true
                elseif app.getRSSI() == 0 and app.offlineMode == false then
                    message = "Please check your heli is powered on and telemetry is running."
                    app.triggers.invalidConnectionSetup = true
                elseif rfsuite.session.apiVersion == nil and app.offlineMode == false then
                    message = "Unable to determine MSP version in use."
                    app.triggers.invalidConnectionSetup = true
                elseif not rfsuite.utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiVersionAsString) and app.offlineMode == false then
                    message = "This version of the Lua script \ncan't be used with the selected model (" .. rfsuite.session.apiVersion .. ")."
                    app.triggers.invalidConnectionSetup = true
                end

                -- display message and abort if error occured
                if app.triggers.invalidConnectionSetup == true and app.triggers.wasConnected == false then

                    form.openDialog({
                        width = nil,
                        title = "Error",
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
    if rfsuite.preferences.watchdogParam ~= nil and rfsuite.preferences.watchdogParam ~= 1 then app.protocol.saveTimeout = rfsuite.preferences.watchdogParam end
    if app.dialogs.saveDisplay == true then
        if app.dialogs.saveWatchDog ~= nil then
            if (os.clock() - app.dialogs.saveWatchDog) > (tonumber(app.protocol.saveTimeout + 5)) or (app.dialogs.saveProgressCounter > 120 and rfsuite.tasks.msp.mspQueue:isProcessed()) then
                app.audio.playTimeout = true
                app.ui.progressDisplaySaveMessage("Error: timed out")
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

        app.dialogs.progressCounter = app.dialogs.progressCounter + 2
        app.ui.progressDisplayValue(app.dialogs.progressCounter)

        if (os.clock() - app.dialogs.progressWatchDog) > (tonumber(rfsuite.tasks.msp.protocol.pageReqTimeout)) then

            app.audio.playTimeout = true

            if app.dialogs.progress ~= nil then
                app.ui.progressDisplayMessage("Error: timed out")
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
            label = "                OK                ",
            action = function()

                app.audio.playSaving = true

                -- we have to fake a save dialog in sim as its not actually possible 
                -- to save in sim!
                app.PageTmp = app.Page
                app.triggers.isSaving = true
                app.triggers.triggerSave = false


                saveSettings()
                return true
            end
        }, {
            label = "CANCEL",
            action = function()
                app.triggers.triggerSave = false
                return true
            end
        }}
        local theTitle = "Save settings"
        local theMsg
        if rfsuite.app.Page.extraMsgOnSave then
            theMsg = "Save current page to flight controller?" .. "\n\n" .. rfsuite.app.Page.extraMsgOnSave
        else    
            theMsg = "Save current page to flight controller?"
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

    -- a reload that is pretty much instant with no prompt to ask them
    if app.triggers.triggerReloadNoPrompt == true then
        app.triggers.triggerReloadNoPrompt = false
        app.triggers.reload = true
    end

    -- a reload was triggered - popup a box asking for the reload to be done
    if app.triggers.triggerReload == true then
        local buttons = {{
            label = "                OK                ",
            action = function()
                -- trigger RELOAD
                app.triggers.reload = true
                return true
            end
        }, {
            label = "CANCEL",
            action = function()
                return true
            end
        }}
        form.openDialog({
            width = nil,
            title = "Reload",
            message = "Reload data from flight controller?",
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
        label = "                OK                ",
        action = function()
            -- trigger RELOAD
            app.triggers.reloadFull = true
            return true
        end
    }, {
        label = "CANCEL",
        action = function()
            return true
        end
    }}
    form.openDialog({
        width = nil,
        title = "Reload",
        message = "Reload data from flight controller?",
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
                app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter, "Saving data...")
            elseif app.pageState == app.pageStatus.eepromWrite then
                app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter, "Saving data...")
            elseif app.pageState == app.pageStatus.rebooting then
                app.ui.progressDisplaySaveValue(app.dialogs.saveProgressCounter, "Rebooting...")
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

    -- after saving show brief warning if armed (we only show this if feature it turned on as default option is to not allow save when armed for safety.
    if rfsuite.preferences.saveWhenArmedWarning == true then
        if app.triggers.showSaveArmedWarning == true and app.triggers.closeSave == false then
            if app.dialogs.progressDisplay == false then
                app.dialogs.progressCounter = 0
                app.ui.progressDisplay('Save not committed to EEPROM', 'Please disarm to save to ensure data integrity when saving.')
            end
            if app.dialogs.progressCounter >= 100 then
                app.triggers.showSaveArmedWarning = false
                app.ui.progressDisplayClose()
            end
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
    if rfsuite.preferences.audioAlerts == 0 or rfsuite.preferences.audioAlerts == 1 then

        if app.audio.playEraseFlash == true then
            rfsuite.utils.playFile("app", "eraseflash.wav")
            app.audio.playEraseFlash = false
        end

        if app.audio.playConnected == true then
            rfsuite.utils.playFile("app", "connected.wav")
            app.audio.playConnected = false
        end

        if app.audio.playConnecting == true then
            rfsuite.utils.playFile("app", "connecting.wav")
            app.audio.playConnecting = false
        end

        if app.audio.playDemo == true then
            rfsuite.utils.playFile("app", "demo.wav")
            app.audio.playDemo = false
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

        if app.audio.playSaving == true and rfsuite.preferences.audioAlerts == 0 then
            rfsuite.utils.playFile("app", "saving.wav")
            app.audio.playSaving = false
        end

        if app.audio.playLoading == true and rfsuite.preferences.audioAlerts == 0 then
            rfsuite.utils.playFile("app", "loading.wav")
            app.audio.playLoading = false
        end

        if app.audio.playSave == true then
            rfsuite.utils.playFile("app", "save.wav")
            app.audio.playSave = false
        end

        if app.audio.playSaveArmed == true then
            rfsuite.utils.playFileCommon("warn.wav")
            app.audio.playSaveArmed = false
        end

        if app.audio.playBufferWarn == true then
            rfsuite.utils.playFileCommon("warn.wav")
            app.audio.playBufferWarn = false
        end


    else
        app.audio.playLoading = false
        app.audio.playSaving = false
        app.audio.playTimeout = false
        app.audio.playDemo = false
        app.audio.playConnecting = false
        app.audio.playConnected = false
        app.audio.playEscPowerCycle = false
        app.audio.playServoOverideDisable = false
        app.audio.playServoOverideEnable = false
    end

end

function app.create_logtool()
    triggers.showUnderUsedBufferWarning = false
    triggers.showOverUsedBufferWarning = false

    -- session.apiVersion = nil
    config.environment = system.getVersion()
    config.ethosRunningVersion = {config.environment.major, config.environment.minor, config.environment.revision}

    rfsuite.config.lcdWidth, rfsuite.config.lcdHeight = rfsuite.utils.getWindowSize()
    app.radio = assert(loadfile("app/radios.lua"))().msp

    app.uiState = app.uiStatus.init

    -- override developermode if file exists.
    if not rfsuite.config.developerMode and rfsuite.utils.file_exists("../developermode") then
        rfsuite.config.developerMode = true
    end

    rfsuite.app.menuLastSelected["mainmenu"] = pidx
    rfsuite.app.ui.progressDisplay()

    rfsuite.app.offlineMode = true
    rfsuite.app.ui.openPage(1, "Logs", "logs/logs.lua", 1) -- final param says to load in standalone mode
end

function app.create()

    -- session.apiVersion = nil
    config.environment = system.getVersion()
    config.ethosRunningVersion = {config.environment.major, config.environment.minor, config.environment.revision}

    rfsuite.config.lcdWidth, rfsuite.config.lcdHeight = rfsuite.utils.getWindowSize()
    app.radio = assert(loadfile("app/radios.lua"))().msp

    app.uiState = app.uiStatus.init

    -- override developermode if file exists.
    if not rfsuite.config.developerMode and rfsuite.utils.file_exists("../developermode") then
        rfsuite.config.developerMode = true
    end

    app.ui.openMainMenu()

end

-- EVENT:  Called for button presses, scroll events, touch events, etc.
function app.event(widget, category, value, x, y)

    -- long press on return at any point will force an rapid exit
    if value == KEY_RTN_LONG then
        rfsuite.utils.log("KEY_RTN_LONG", "info")
        invalidatePages()
        system.exit()
        return 0
    end

    -- the page has its own even system.  we should use it.
    if app.Page and (app.uiState == app.uiStatus.pages or app.uiState == app.uiStatus.mainMenu) then
        if app.Page.event then
            rfsuite.utils.log("USING PAGES EVENTS", "info")
            local ret = app.Page.event(widget, category, value, x, y)
            print(ret)
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
            rfsuite.utils.log("EVT_ENTER_LONG (PAGES)", "info")
            if app.dialogs.progressDisplay then app.ui.progressDisplayClose() end
            if app.dialogs.saveDisplay then app.ui.progressDisplaySaveClose() end
            app.triggers.triggerSave = true
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

function app.close()
    app.guiIsRunning = false
    app.offlineMode = false

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
