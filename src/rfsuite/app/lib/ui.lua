--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local lcdColor = lcd.color
local lcdDrawText = lcd.drawText
local lcdFont = lcd.font
local lcdGetTextSize = lcd.getTextSize
local lcdGetWindowSize = lcd.getWindowSize
local lcdLoadMask = lcd.loadMask
local osClock = os.clock
local tableConcat = table.concat
local mathFloor = math.floor
local app = rfsuite.app
local session = rfsuite.session

local ui = {}

local arg = {...}
local config = arg[1]
local preferences = rfsuite.preferences
local utils = rfsuite.utils
local tasks = rfsuite.tasks
local apiCore

local MSP_DEBUG_PLACEHOLDER = "MSP Waiting"

local function resolveScriptFromRules(rules)
    if type(rules) ~= "table" then return nil end
    for _, rule in ipairs(rules) do
        local op = rule.op or rule[1]
        local ver = rule.ver or rule[2]
        local script = rule.script or rule[3]
        if op and ver and script and utils.apiVersionCompare(op, ver) then
            return script, rule.loaderspeed
        end
    end
    return nil
end

local function resolvePageScript(page, section)
    local rules = page.script_by_mspversion or page.scriptByMspVersion
    if not rules and section then
        rules = section.script_by_mspversion or section.scriptByMspVersion
    end
    if rules then
        local chosen, speed = resolveScriptFromRules(rules)
        if chosen then return chosen, speed end
        if page.script_default then return page.script_default, page.loaderspeed end
    end
    return page.script, page.loaderspeed
end

local function getMspStatusExtras()
    local m = tasks and tasks.msp
    if not m then return nil end
    local q = m.mspQueue
    if not q then return nil end

    local parts = {}

    local common = m.common
    if common and common.getLastTxCmd then
        local ok_tx, tx = pcall(common.getLastTxCmd)
        if ok_tx and tx and tx ~= 0 then parts[#parts + 1] = "Transmit " .. tostring(tx) end
    end
    if common and common.getLastRxCmd then
        local ok_rx, rx = pcall(common.getLastRxCmd)
        if ok_rx and rx and rx ~= 0 then parts[#parts + 1] = "Receive " .. tostring(rx) end
    end

    if q.retryCount ~= nil then
        local retries = q.retryCount - 1
        if retries > 0 then
            parts[#parts + 1] = "Retry " .. tostring(retries)
        end
    end

    local crc = session and session.mspCrcErrors
    if crc and crc > 0 then
        parts[#parts + 1] = "CRC " .. tostring(crc)
    end

    if session then
        local tout = session.mspTimeouts or 0
        if tout > 0 then
            parts[#parts + 1] = "Timeout " .. tostring(tout)
        end
    end

    if #parts == 0 then return nil end
    return tableConcat(parts, " ")
end

local function getMspStatusForDialog()
    if not session then return nil end
    if session.mspStatusClearAt and osClock() >= session.mspStatusClearAt then
        session.mspStatusMessage = nil
        session.mspStatusClearAt = nil
    end
    local mspStatus = session.mspStatusMessage
    if not mspStatus and session.mspStatusLast and session.mspStatusUpdatedAt and (osClock() - session.mspStatusUpdatedAt) < 0.75 then
        mspStatus = session.mspStatusLast
    end
    if preferences and preferences.general and preferences.general.mspstatusdialog then
        local extras = getMspStatusExtras()
        if extras then
            if mspStatus then
                mspStatus = mspStatus .. " " .. extras
            else
                mspStatus = extras
            end
        end
    end

    return mspStatus
end

function ui.registerProgressDialog(handle, baseMessage)
    if not session then return end
    session.progressDialog = {
        handle = handle,
        baseMessage = baseMessage or ""
    }
end

function ui.clearProgressDialog(handle)
    if not session or not session.progressDialog then return end
    if handle == nil or session.progressDialog.handle == handle then
        session.progressDialog = nil
    end
end

function ui.updateProgressDialogMessage(statusOverride)

    -- First update the standard app dialogs (the ones actually on screen)
    if app and app.dialogs then
        if app.dialogs.progressDisplay and app.dialogs.progress then
            local mspStatus = statusOverride or getMspStatusForDialog()
            local base = app.dialogs.progressBaseMessage or ""
            local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
            local msg = showDebug and (mspStatus or MSP_DEBUG_PLACEHOLDER) or base
            if showDebug and mspStatus then msg = mspStatus end
            pcall(function() app.dialogs.progress:message(msg) end)
        end
        if app.dialogs.saveDisplay and app.dialogs.save then
            local mspStatus = statusOverride or getMspStatusForDialog()
            local base = app.dialogs.saveBaseMessage or ""
            local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
            local msg = showDebug and (mspStatus or MSP_DEBUG_PLACEHOLDER) or base
            if showDebug and mspStatus then msg = mspStatus end
            pcall(function() app.dialogs.save:message(msg) end)
        end
    end

    -- Then update any custom registered dialog
    local pd = session and session.progressDialog
    if pd and pd.handle then
        local mspStatus = statusOverride or getMspStatusForDialog()
        local composedMessage = pd.baseMessage or ""
        local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
        if showDebug then
            composedMessage = mspStatus or MSP_DEBUG_PLACEHOLDER
        end
        pcall(function() pd.handle:message(composedMessage) end)
    end
end

local function getApiCore()
    if apiCore then return apiCore end
    apiCore = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()
    return apiCore
end

local function openProgressDialog(opts)
    if utils.ethosVersionAtLeast({1, 7, 0}) and form.openWaitDialog then
        opts.progress = true
        return form.openWaitDialog(opts)
    end
    return form.openProgressDialog(opts)
end

function ui.progressDisplay(title, message, speed)


    if app.dialogs.progressDisplay then return end

    title = title or "@i18n(app.msg_loading)@"
    message = message or "@i18n(app.msg_loading_from_fbl)@"

    local speedMult = tonumber(speed)
    if speedMult == nil then
        speedMult = (app.loaderSpeed and app.loaderSpeed.DEFAULT) or 1.0
    end
    app.dialogs.progressSpeed = speedMult

    local reachedTimeout = false

    if session then session.mspTimeouts = 0 end
    app.dialogs.progressDisplay = true
    app.dialogs.progressWatchDog = osClock()
    app.dialogs.progressBaseMessage = message
    app.dialogs.progressMspStatusLast = nil
    local useWaitDialog = utils.ethosVersionAtLeast({1, 7, 0}) and form.openWaitDialog
    app.dialogs.progressIsWait = useWaitDialog or false
    app.dialogs.progress = openProgressDialog({
        title = title,
        message = message,
        close = function() end,
        wakeup = function()
            local now = osClock()

            app.dialogs.progress:value(app.dialogs.progressCounter)

            local mult = app.dialogs.progressSpeed or 1.0

            local isProcessing = (app.Page and app.Page.apidata and app.Page.apidata.apiState and app.Page.apidata.apiState.isProcessing) or false
            local apiV = tostring(session.apiVersion)

            if not app.triggers.closeProgressLoader then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (2 * mult)
                if app.dialogs.progressCounter > 50 and session.apiVersion and not utils.stringInArray(rfsuite.config.supportedMspApiVersion, apiV) then print("No API version yet") end
            elseif isProcessing then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (3 * mult)
            elseif app.triggers.closeProgressLoader and tasks.msp and tasks.msp.mspQueue:isProcessed() then
                if app.dialogs.progressIsWait then
                    app.dialogs.progress:close()
                    ui.clearProgressDialog(app.dialogs.progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = nil
                    app.triggers.closeProgressLoaderNoisProcessed = false
                    return
                end
                if preferences.general.hs_loader == 0 then mult = mult * 2 end
                app.dialogs.progressCounter = app.dialogs.progressCounter + (15 * mult)
                if app.dialogs.progressCounter >= 100 then
                    app.dialogs.progress:close()
                    ui.clearProgressDialog(app.dialogs.progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = nil
                end
            elseif app.triggers.closeProgressLoader and app.triggers.closeProgressLoaderNoisProcessed then
                if app.dialogs.progressIsWait then
                    app.dialogs.progress:close()
                    ui.clearProgressDialog(app.dialogs.progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = nil
                    app.triggers.closeProgressLoaderNoisProcessed = false
                    return
                end
                if preferences.general.hs_loader == 0 then mult = mult * 1.5 end
                app.dialogs.progressCounter = app.dialogs.progressCounter + (15 * mult)
                if app.dialogs.progressCounter >= 100 then
                    app.dialogs.progress:close()
                    ui.clearProgressDialog(app.dialogs.progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.triggers.closeProgressLoader = false
                    app.dialogs.progressSpeed = nil
                    app.triggers.closeProgressLoaderNoisProcessed = false

                end
            end

            if app.dialogs.progressWatchDog and tasks.msp and (osClock() - app.dialogs.progressWatchDog) > tonumber(tasks.msp.protocol.pageReqTimeout) and app.dialogs.progressDisplay == true and reachedTimeout == false then
                reachedTimeout = true
                app.audio.playTimeout = true
                app.dialogs.progress:message("@i18n(app.error_timed_out)@")
                app.dialogs.progress:closeAllowed(true)
                app.dialogs.progress:value(100)
                ui.clearProgressDialog(app.dialogs.progress)
                app.Page = app.PageTmp
                app.PageTmp = nil
                app.dialogs.progressCounter = 0
                app.dialogs.progressSpeed = nil
                app.dialogs.progressDisplay = false

                ui.disableAllFields()
                ui.disableAllNavigationFields()
                ui.enableNavigationField('menu')                

            end

            if not tasks.msp then
                app.dialogs.progressCounter = app.dialogs.progressCounter + (2 * mult)
                if app.dialogs.progressCounter >= 100 then
                    app.dialogs.progress:close()
                    ui.clearProgressDialog(app.dialogs.progress)
                    app.dialogs.progressDisplay = false
                    app.dialogs.progressCounter = 0
                    app.dialogs.progressSpeed = nil

                end
            end

            local mspStatus = getMspStatusForDialog()
            local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
            local msg = showDebug and (mspStatus or MSP_DEBUG_PLACEHOLDER) or (app.dialogs.progressBaseMessage or "")
            if showDebug and mspStatus then msg = mspStatus end
            app.dialogs.progress:message(msg)

        end
    })

    app.dialogs.progressCounter = 0
    app.dialogs.progress:value(0)
    app.dialogs.progress:closeAllowed(false)
    ui.registerProgressDialog(app.dialogs.progress, app.dialogs.progressBaseMessage)
end

function ui.progressDisplaySave(message)

    local reachedTimeout = false

    if session then session.mspTimeouts = 0 end
    app.dialogs.saveDisplay = true
    app.dialogs.saveWatchDog = osClock()
    app.dialogs.saveBaseMessage = nil
    app.dialogs.saveMspStatusLast = nil

    local SAVE_MESSAGE_TAG = {[app.pageStatus.saving] = "@i18n(app.msg_saving_settings)@", [app.pageStatus.eepromWrite] = "@i18n(app.msg_saving_settings)@", [app.pageStatus.rebooting] = "@i18n(app.msg_rebooting)@"}

    local resolvedMessage = message or SAVE_MESSAGE_TAG[app.pageState] or "@i18n(app.msg_saving_settings)@"
    local title = "@i18n(app.msg_saving)@"
    app.dialogs.saveBaseMessage = resolvedMessage

    local useWaitDialog = utils.ethosVersionAtLeast({1, 7, 0}) and form.openWaitDialog
    app.dialogs.saveIsWait = useWaitDialog or false
    app.dialogs.save = openProgressDialog({
        title = title,
        message = resolvedMessage,
        close = function() end,
        wakeup = function()
            local now = osClock()

            app.dialogs.save:value(app.dialogs.saveProgressCounter)

            local isProcessing = (app.Page and app.Page.apidata and app.Page.apidata.apiState and app.Page.apidata.apiState.isProcessing) or false

            if not app.dialogs.saveProgressCounter then app.dialogs.saveProgressCounter = 0 end

            if isProcessing then
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 3
            elseif app.triggers.closeSaveFake then
                if app.dialogs.saveIsWait then
                    app.triggers.closeSaveFake = false
                    app.dialogs.saveProgressCounter = 0
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveWatchDog = nil
                    app.dialogs.save:close()
                    ui.clearProgressDialog(app.dialogs.save)
                    return
                end
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 5
                if app.dialogs.saveProgressCounter >= 100 then
                    app.triggers.closeSaveFake = false
                    app.dialogs.saveProgressCounter = 0
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveWatchDog = nil
                    app.dialogs.save:close()
                    ui.clearProgressDialog(app.dialogs.save)

                end
            elseif tasks.msp.mspQueue:isProcessed() then
                if app.dialogs.saveIsWait then
                    app.dialogs.save:close()
                    ui.clearProgressDialog(app.dialogs.save)
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveProgressCounter = 0
                    app.triggers.closeSave = false
                    app.triggers.isSaving = false
                    return
                end
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 15
                if app.dialogs.saveProgressCounter >= 100 then
                    app.dialogs.save:close()
                    ui.clearProgressDialog(app.dialogs.save)
                    app.dialogs.saveDisplay = false
                    app.dialogs.saveProgressCounter = 0
                    app.triggers.closeSave = false
                    app.triggers.isSaving = false

                end
            else
                app.dialogs.saveProgressCounter = app.dialogs.saveProgressCounter + 2
            end

            local timeout = tonumber(tasks.msp.protocol.saveTimeout + 5)
            if (app.dialogs.saveWatchDog and (osClock() - app.dialogs.saveWatchDog) > timeout) and reachedTimeout == false or (app.dialogs.saveProgressCounter > 120 and tasks.msp.mspQueue:isProcessed()) and app.dialogs.saveDisplay == true and reachedTimeout == false then
                reachedTimeout = true
                app.audio.playTimeout = true
                app.dialogs.save:message("@i18n(app.error_timed_out)@")
                app.dialogs.save:closeAllowed(true)
                app.dialogs.save:value(100)
                app.dialogs.saveProgressCounter = 0
                app.dialogs.saveDisplay = false
                app.triggers.isSaving = false
                ui.clearProgressDialog(app.dialogs.save)
                app.Page = app.PageTmp
                app.PageTmp = nil

            end

            local mspStatus = getMspStatusForDialog()
            local showDebug = preferences and preferences.general and preferences.general.mspstatusdialog
            local msg = showDebug and (mspStatus or MSP_DEBUG_PLACEHOLDER) or (app.dialogs.saveBaseMessage or "")
            if showDebug and mspStatus then msg = mspStatus end
            pcall(function() app.dialogs.save:message(msg) end)
        end
    })

    app.dialogs.save:value(0)
    app.dialogs.save:closeAllowed(false)
    ui.registerProgressDialog(app.dialogs.save, app.dialogs.saveBaseMessage)
end

function ui.progressDisplayIsActive()


    return app.dialogs.progressDisplay or app.dialogs.saveDisplay or app.dialogs.progressDisplayEsc or app.dialogs.nolinkDisplay or app.dialogs.badversionDisplay
end

function ui.disableAllFields()


    for i = 1, #app.formFields do
        local field = app.formFields[i]
        if type(field) == "userdata" then field:enable(false) end
    end
end

function ui.enableAllFields()


    for _, field in ipairs(app.formFields) do if type(field) == "userdata" then field:enable(true) end end
end

function ui.disableAllNavigationFields()


    for _, v in pairs(app.formNavigationFields) do v:enable(false) end
end

function ui.enableAllNavigationFields()


    for _, v in pairs(app.formNavigationFields) do v:enable(true) end
end

function ui.enableNavigationField(x)


    local field = app.formNavigationFields[x]
    if field then field:enable(true) end
end

function ui.disableNavigationField(x)


    local field = app.formNavigationFields[x]
    if field then field:enable(false) end
end

function ui.cleanupCurrentPage()
    if preferences and preferences.developer and preferences.developer.memstats then
        local mem_kb = collectgarbage("count")
        local function tcount(t)
            if type(t) ~= "table" then return 0 end
            local n = 0
            for _ in pairs(t) do n = n + 1 end
            return n
        end
        local apidata = tasks and tasks.msp and tasks.msp.api and tasks.msp.api.apidata
        local apiLoader = tasks and tasks.msp and tasks.msp.api
        local cbq = tasks and tasks.callback and tasks.callback._queue
        local pageLabel = (app and app.lastScript) or (app and app.Page and app.Page.pageTitle) or "?"
        local function gfxMaskCount()
            if not app or type(app.gfx_buttons) ~= "table" then return 0 end
            local total = 0
            for _, section in pairs(app.gfx_buttons) do
                if type(section) == "table" then
                    for _ in pairs(section) do total = total + 1 end
                end
            end
            return total
        end
        utils.log(string.format(
            "[mem] cleanup start: %.1f KB | page=%s | apidata v=%d s=%d b=%d bc=%d p=%d o=%d | apiCache file=%d chunk=%d | help=%d gfx=%d cbq=%d",
            mem_kb, tostring(pageLabel),
            tcount(apidata and apidata.values),
            tcount(apidata and apidata.structure),
            tcount(apidata and apidata.receivedBytes),
            tcount(apidata and apidata.receivedBytesCount),
            tcount(apidata and apidata.positionmap),
            tcount(apidata and apidata.other),
            tcount(apiLoader and apiLoader._fileExistsCache),
            tcount(apiLoader and apiLoader._chunkCache),
            tcount(ui._helpCache),
            gfxMaskCount(),
            tcount(cbq)
        ), "debug")
    end

    -- Let the current page release resources.
    if app.Page then
        local hook = app.Page.close or app.Page.onClose or app.Page.destroy
        if type(hook) == "function" then
            local ok, err = pcall(hook, app.Page)
            if not ok then
                utils.log("Page cleanup error: " .. tostring(err), "debug")
            end
        end
    end

    if app.Page and app.Page.apidata then
        -- Drop cached MSP API data for just this page's APIs.
        if tasks and tasks.msp and tasks.msp.api and tasks.msp.api.apidata and app.Page.apidata.api then
            local apidata = tasks.msp.api.apidata
            for _, v in ipairs(app.Page.apidata.api) do
                local apiKey = type(v) == "string" and v or v.name
                if apiKey then
                    if apidata.values then apidata.values[apiKey] = nil end
                    if apidata.structure then apidata.structure[apiKey] = nil end
                    if apidata.receivedBytes then apidata.receivedBytes[apiKey] = nil end
                    if apidata.receivedBytesCount then apidata.receivedBytesCount[apiKey] = nil end
                    if apidata.positionmap then apidata.positionmap[apiKey] = nil end
                    if apidata.other then apidata.other[apiKey] = nil end
                end
            end
        end

        if app.Page.apidata.formdata then
            if app.Page.apidata.formdata.rows then for i = 1, #app.Page.apidata.formdata.rows do app.Page.apidata.formdata.rows[i] = nil end end
            if app.Page.apidata.formdata.cols then for i = 1, #app.Page.apidata.formdata.cols do app.Page.apidata.formdata.cols[i] = nil end end
            if app.Page.apidata.formdata.fields then for i = 1, #app.Page.apidata.formdata.fields do app.Page.apidata.formdata.fields[i] = nil end end
            if app.Page.apidata.formdata.labels then for i = 1, #app.Page.apidata.formdata.labels do app.Page.apidata.formdata.labels[i] = nil end end
        end

        if app.Page.apidata.api then for i = 1, #app.Page.apidata.api do app.Page.apidata.api[i] = nil end end
        if app.Page.apidata.api_reversed then for i = 1, #app.Page.apidata.api_reversed do app.Page.apidata.api_reversed[i] = nil end end

        app.Page.apidata = nil
    end

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end
    if app.formNavigationFields then for k in pairs(app.formNavigationFields) do app.formNavigationFields[k] = nil end end

    app.fieldHelpTxt = nil
    ui._helpCache = {}

    app.Page = nil
    app.PageTmp = nil

    collectgarbage('collect')

    if preferences and preferences.developer and preferences.developer.memstats then
        local mem_kb = collectgarbage("count")
        local function tcount(t)
            if type(t) ~= "table" then return 0 end
            local n = 0
            for _ in pairs(t) do n = n + 1 end
            return n
        end
        local apidata = tasks and tasks.msp and tasks.msp.api and tasks.msp.api.apidata
        local apiLoader = tasks and tasks.msp and tasks.msp.api
        local cbq = tasks and tasks.callback and tasks.callback._queue
        local pageLabel = (app and app.lastScript) or (app and app.Page and app.Page.pageTitle) or "?"
        local function gfxMaskCount()
            if not app or type(app.gfx_buttons) ~= "table" then return 0 end
            local total = 0
            for _, section in pairs(app.gfx_buttons) do
                if type(section) == "table" then
                    for _ in pairs(section) do total = total + 1 end
                end
            end
            return total
        end
        utils.log(string.format(
            "[mem] cleanup end: %.1f KB | page=%s | apidata v=%d s=%d b=%d bc=%d p=%d o=%d | apiCache file=%d chunk=%d | help=%d gfx=%d cbq=%d",
            mem_kb, tostring(pageLabel),
            tcount(apidata and apidata.values),
            tcount(apidata and apidata.structure),
            tcount(apidata and apidata.receivedBytes),
            tcount(apidata and apidata.receivedBytesCount),
            tcount(apidata and apidata.positionmap),
            tcount(apidata and apidata.other),
            tcount(apiLoader and apiLoader._fileExistsCache),
            tcount(apiLoader and apiLoader._chunkCache),
            tcount(ui._helpCache),
            gfxMaskCount(),
            tcount(cbq)
        ), "debug")
    end
end

function ui.resetPageState(activesection)

    ui.cleanupCurrentPage()

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end

    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    app.formFieldsOffline = {}
    app.formFieldsBGTask = {}
    app.lastLabel = nil
    app.isOfflinePage = false
    app.lastMenu = nil
    app.lastIdx = nil
    app.lastTitle = nil
    app.lastScript = nil

    session.lastPage = nil
    app.triggers.isReady = false
    app.uiState = app.uiStatus.mainMenu
    app.triggers.disableRssiTimeout = false
    if tasks.msp then tasks.msp.api.resetApidata() end

    if activesection then
        if not app.gfx_buttons[activesection] then app.gfx_buttons[activesection] = {} end
        for k in pairs(app.gfx_buttons) do if k ~= activesection then app.gfx_buttons[k] = nil end end
    else
        if not app.gfx_buttons["mainmenu"] then app.gfx_buttons["mainmenu"] = {} end
        for k in pairs(app.gfx_buttons) do if k ~= "mainmenu" then app.gfx_buttons[k] = nil end end
    end

    collectgarbage('collect')
end

function ui.openMainMenu()

    ui.resetPageState()

    utils.reportMemoryUsage("app.openMainMenu", "start")

    if tasks.msp then tasks.msp.protocol.mspIntervalOveride = nil end

    form.clear()

    if preferences.general.iconsize == nil or preferences.general.iconsize == "" then
        preferences.general.iconsize = 1
    else
        preferences.general.iconsize = tonumber(preferences.general.iconsize)
    end

    local w, h = lcdGetWindowSize()
    local windowWidth = w
    local windowHeight = h

    local buttonW, buttonH, padding, numPerRow

    if preferences.general.iconsize == 0 then
        padding = app.radio.buttonPaddingSmall
        buttonW = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    elseif preferences.general.iconsize == 1 then
        padding = app.radio.buttonPaddingSmall
        buttonW = app.radio.buttonWidthSmall
        buttonH = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    elseif preferences.general.iconsize == 2 then
        padding = app.radio.buttonPadding
        buttonW = app.radio.buttonWidth
        buttonH = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    app.gfx_buttons["mainmenu"] = app.gfx_buttons["mainmenu"] or {}
    preferences.menulastselected["mainmenu"] = preferences.menulastselected["mainmenu"] or 1

    -- Prefer the already-built menu structure; fallback loads manifest directly.
    local Menu = (app.MainMenu and app.MainMenu.sections) or (assert(loadfile("app/modules/manifest.lua"))().sections)

    local lc, bx, y = 0, 0, 0

    local header = form.addLine("@i18n(app.header_configuration)@")

    local navX = windowWidth - 110
    app.formNavigationFields['menu'] = form.addButton(header, {x = navX, y = app.radio.linePaddingTop, w = 100, h = app.radio.navbuttonHeight}, {
        text = "@i18n(app.navigation_menu)@",
        icon = nil,
        options = FONT_S,
        paint = function() end,
        press = function()
            app.close()
        end
    })

    for pidx, pvalue in ipairs(Menu) do

        app.formFieldsOffline[pidx] = pvalue.offline or false
        app.formFieldsBGTask[pidx] = pvalue.bgtask or false

        if pvalue.newline then
            lc = 0
            form.addLine("@i18n(app.header_system)@")
        end

        if lc == 0 then y = form.height() + ((preferences.general.iconsize == 2) and app.radio.buttonPadding or app.radio.buttonPaddingSmall) end

        bx = (buttonW + padding) * lc

        if preferences.general.iconsize ~= 0 then
            app.gfx_buttons["mainmenu"][pidx] = app.gfx_buttons["mainmenu"][pidx] or lcdLoadMask(pvalue.image)
        else
            app.gfx_buttons["mainmenu"][pidx] = nil
        end

        app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.title,
            icon = app.gfx_buttons["mainmenu"][pidx],
            options = FONT_S,
            paint = function() end,
            press = function()
                preferences.menulastselected["mainmenu"] = pidx
                local speed = tonumber(pvalue.loaderspeed) or (app.loaderSpeed and app.loaderSpeed.DEFAULT) or 1.0
                if pvalue.module then
                    app.isOfflinePage = true
                    local script, speedOverride = resolvePageScript(pvalue)
                    if speedOverride ~= nil then
                        speed = tonumber(speedOverride) or (app.loaderSpeed and app.loaderSpeed[speedOverride]) or speed
                    end
                    app.ui.progressDisplay(nil, nil, speed)
                    app.ui.openPage({idx = pidx, title = pvalue.title, script = pvalue.module .. "/" .. script})
                else
                    app.ui.progressDisplay(nil, nil, speed)
                    app.ui.openMainMenuSub(pvalue.id)
                end
            end
        })

        app.formFields[pidx]:enable(false)

        lc = lc + 1
        if lc == numPerRow then lc = 0 end
    end

    app.triggers.closeProgressLoader = true

    utils.reportMemoryUsage("app.openMainMenu", "end")

    collectgarbage('collect')
    collectgarbage('collect')
end

function ui.openMainMenuSub(activesection)

    ui.resetPageState(activesection)

    utils.reportMemoryUsage("app.openMainMenuSub", "start")

    if not utils.ethosVersionAtLeast(config.ethosVersion) then return end

    local MainMenu = app.MainMenu
    
    app.lastMenu = activesection

    preferences.general.iconsize = tonumber(preferences.general.iconsize) or 1

    local buttonW, buttonH, padding, numPerRow

    if preferences.general.iconsize == 0 then
        padding = app.radio.buttonPaddingSmall
        buttonW = (app.lcdWidth - padding) / app.radio.buttonsPerRow - padding
        buttonH = app.radio.navbuttonHeight
        numPerRow = app.radio.buttonsPerRow
    elseif preferences.general.iconsize == 1 then
        padding = app.radio.buttonPaddingSmall
        buttonW = app.radio.buttonWidthSmall
        buttonH = app.radio.buttonHeightSmall
        numPerRow = app.radio.buttonsPerRowSmall
    elseif preferences.general.iconsize == 2 then
        padding = app.radio.buttonPadding
        buttonW = app.radio.buttonWidth
        buttonH = app.radio.buttonHeight
        numPerRow = app.radio.buttonsPerRow
    end

    form.clear()

    app.gfx_buttons[activesection] = app.gfx_buttons[activesection] or {}
    preferences.menulastselected[activesection] = preferences.menulastselected[activesection] or 1

    for idx, section in ipairs(MainMenu.sections) do
        if section.id == activesection then
            local w, h = lcdGetWindowSize()
            local windowWidth, windowHeight = w, h
            local padding = app.radio.buttonPadding

            form.addLine(section.title)

            local x = windowWidth - 110
            app.formNavigationFields['menu'] = form.addButton(line, {x = x, y = app.radio.linePaddingTop, w = 100, h = app.radio.navbuttonHeight}, {
                text = "@i18n(app.navigation_menu)@",
                icon = nil,
                options = FONT_S,
                paint = function() end,
                press = function()
                    app.lastIdx = nil
                    session.lastPage = nil
                    if app.Page and app.Page.onNavMenu then app.Page.onNavMenu(app.Page) end
                    app.ui.openMainMenu()
                end
            })
            app.formNavigationFields['menu']:focus()

            local lc, y = 0, 0

            for pidx, page in ipairs(MainMenu.pages) do
                if page.section == idx then
                    local hideEntry = (page.ethosversion and not utils.ethosVersionAtLeast(page.ethosversion)) or (page.mspversion and utils.apiVersionCompare("<", page.mspversion)) 

                    local offline = page.offline
                    app.formFieldsOffline[pidx] = offline or false

                    if not hideEntry then
                        if lc == 0 then y = form.height() + ((preferences.general.iconsize == 2) and app.radio.buttonPadding or app.radio.buttonPaddingSmall) end

                        local x = (buttonW + padding) * lc

                        if preferences.general.iconsize ~= 0 then
                            app.gfx_buttons[activesection][pidx] = app.gfx_buttons[activesection][pidx] or lcdLoadMask("app/modules/" .. page.folder .. "/" .. page.image)
                        else
                            app.gfx_buttons[activesection][pidx] = nil
                        end

                        app.formFields[pidx] = form.addButton(line, {x = x, y = y, w = buttonW, h = buttonH}, {
                            text = page.title,
                            icon = app.gfx_buttons[activesection][pidx],
                            options = FONT_S,
                            paint = function() end,
                            press = function()
                                preferences.menulastselected[activesection] = pidx
                                local speed = tonumber(page.loaderspeed or section.loaderspeed) or (app.loaderSpeed and app.loaderSpeed.DEFAULT) or 1.0
                                app.isOfflinePage = offline
                                local script, speedOverride = resolvePageScript(page, section)
                                if speedOverride ~= nil then
                                    speed = tonumber(speedOverride) or (app.loaderSpeed and app.loaderSpeed[speedOverride]) or speed
                                end
                                app.ui.progressDisplay(nil, nil, speed)
                                app.ui.openPage({idx = pidx, title = page.title, script = page.folder .. "/" .. script})
                            end
                        })


                        lc = (lc + 1) % numPerRow
                    end
                end
            end
        end
    end

    -- Aggressive cache clearing on page exit to minimize memory retention.
    if app and type(app.gfx_buttons) == "table" then
        app.gfx_buttons = {}
        if preferences and preferences.developer and preferences.developer.memstats then
            utils.log("[mem] gfx cache cleared on page exit", "debug")
        end
    end

    if tasks and tasks.msp and tasks.msp.api then
        if tasks.msp.api.clearFileExistsCache then tasks.msp.api.clearFileExistsCache() end
        if tasks.msp.api.clearChunkCache then tasks.msp.api.clearChunkCache() end
        if preferences and preferences.developer and preferences.developer.memstats then
            utils.log("[mem] msp api caches cleared on page exit", "debug")
        end
    end

    -- Trim MSP API file-exists cache if it grows (can creep with many module/API loads).
    if tasks and tasks.msp and tasks.msp.api and tasks.msp.api._fileExistsCache then
        local cache = tasks.msp.api._fileExistsCache
        local n = 0
        for _ in pairs(cache) do n = n + 1 end
        if n > 16 then
            tasks.msp.api.clearFileExistsCache()
        end
    end

    app.triggers.closeProgressLoader = true

    utils.reportMemoryUsage("app.openMainMenuSub", "end")

    collectgarbage('collect')
    collectgarbage('collect')
end

function ui.getLabel(id, page)
    if id == nil then return nil end
    for i = 1, #page do if page[i].label == id then return page[i] end end
    return nil
end

function ui._guardField(fields, i)
    if not (fields and fields[i]) then
        ui.disableAllFields()
        ui.disableAllNavigationFields()
        ui.enableNavigationField('menu')
        return nil
    end
    return fields[i]
end

function ui._prepareFieldLine(f, radioText)
    local formLines = app.formLines
    local posField

    if f.inline and f.inline >= 1 and f.label then
        if radioText == 2 and f.t2 then f.t = f.t2 end
        local p = app.utils.getInlinePositions(f)
        posField = p.posField
        form.addStaticText(formLines[app.formLineCnt], p.posText, f.t)
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

    return posField
end

function ui.fieldBoolean(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = ui._guardField(fields, i)
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text

    if not f then return end

    local invert = (f.subtype == 1)

    local posField = ui._prepareFieldLine(f, radioText)

    local function decode()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        local v = (active.value == 1) and 1 or 0
        if invert then v = (v == 1) and 0 or 1 end
        return (v == 1)
    end

    local function encode(b)
        local v = b and 1 or 0
        if invert then v = (v == 1) and 0 or 1 end
        return v
    end

    formFields[i] = form.addBooleanField(formLines[app.formLineCnt], posField, function() return decode() end, function(valueBool)
        local value = encode(valueBool == true)
        if f.postEdit then f.postEdit(page, value) end
        if f.onChange then f.onChange(page, value) end
        f.value = app.utils.saveFieldValue(fields[i], value)
    end)

    if f.disable then formFields[i]:enable(false) end
end

function ui.fieldBooleanInverted(i, lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields and fields[i] or nil
    local prevSubtype = f and f.subtype or nil
    if f then f.subtype = 1 end
    ui.fieldBoolean(i, lf)
    if f then f.subtype = prevSubtype end
end

function ui.fieldChoice(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text

    local posField = ui._prepareFieldLine(f, radioText)

    local tbldata = f.table and app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}
    if f.tableEthos then
        tbldata = f.tableEthos
    end


    formFields[i] = form.addChoiceField(formLines[app.formLineCnt], posField, tbldata, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        if f.postEdit then f.postEdit(page, value) end
        if f.onChange then f.onChange(page, value) end
        f.value = app.utils.saveFieldValue(fields[i], value)
    end)

    if f.disable then formFields[i]:enable(false) end
end

function ui.fieldSlider(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

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

    formFields[i] = form.addSliderField(formLines[app.formLineCnt], posField, minValue, maxValue, function()
        if not (fields and fields[i]) then
            ui.disableAllFields()
            ui.disableAllNavigationFields()
            ui.enableNavigationField('menu')
            return nil
        end
        return app.utils.getFieldValue(fields[i])
    end, function(value)
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.decimals then currentField:decimals(f.decimals) end
    if f.step then currentField:step(f.step) end
    if f.disable then currentField:enable(false) end

    if f.help or f.apikey then
        if not f.help and f.apikey then f.help = f.apikey end
        if app.fieldHelpTxt and app.fieldHelpTxt[f.help] and app.fieldHelpTxt[f.help].t then currentField:help(app.fieldHelpTxt[f.help].t) end
    end

end

function ui.fieldNumber(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

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

    formFields[i] = form.addNumberField(formLines[app.formLineCnt], posField, minValue, maxValue, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

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
    if f.unit then currentField:suffix(f.unit) end
    if f.step then currentField:step(f.step) end
    if f.disable then currentField:enable(false) end

    if f.help or f.apikey then
        if not f.help and f.apikey then f.help = f.apikey end
        if app.fieldHelpTxt and app.fieldHelpTxt[f.help] and app.fieldHelpTxt[f.help].t then currentField:help(app.fieldHelpTxt[f.help].t) end
    end

    if f.instantChange == false then
        currentField:enableInstantChange(false)
    else
        currentField:enableInstantChange(true)
    end
end

function ui.fieldSource(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

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

    formFields[i] = form.addSourceField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable then currentField:enable(false) end

end

function ui.fieldSensor(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

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

    formFields[i] = form.addSensorField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable then currentField:enable(false) end

end

function ui.fieldColor(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

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

    formFields[i] = form.addColorField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return COLOR_BLACK end
        local color = active
        if type(color) ~= "number" then
            return COLOR_BLACK
        else
            return color
        end
    end, function(value)
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable then currentField:enable(false) end

end

function ui.fieldSwitch(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields

    local posField = ui._prepareFieldLine(f)

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

    formFields[i] = form.addSwitchField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
    end)

    local currentField = formFields[i]

    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end

    if f.disable then currentField:enable(false) end

end

function ui.fieldStaticText(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text

    local posField = ui._prepareFieldLine(f, radioText)
    local active = ui._guardField(fields, i)
    if not active then return end
    formFields[i] = form.addStaticText(formLines[app.formLineCnt], posField, app.utils.getFieldValue(active))

    local currentField = formFields[i]
    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end
    if f.decimals then currentField:decimals(f.decimals) end
    if f.unit then currentField:suffix(f.unit) end
    if f.step then currentField:step(f.step) end
end

function ui.fieldText(i,lf)
    local page = app.Page
    local fields = page and page.apidata and page.apidata.formdata.fields or lf
    local f = fields[i]
    local formLines = app.formLines
    local formFields = app.formFields
    local radioText = app.radio.text

    local posField = ui._prepareFieldLine(f, radioText)

    formFields[i] = form.addTextField(formLines[app.formLineCnt], posField, function()
        local active = ui._guardField(fields, i)
        if not active then return nil end
        return app.utils.getFieldValue(active)
    end, function(value)
        if f.postEdit then f.postEdit(page) end
        if f.onChange then f.onChange(page) end
        f.value = app.utils.saveFieldValue(fields[i], value)
    end)

    local currentField = formFields[i]
    if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end
    if f.disable then currentField:enable(false) end

    if f.help and app.fieldHelpTxt and app.fieldHelpTxt[f.help] and app.fieldHelpTxt[f.help].t then currentField:help(app.fieldHelpTxt[f.help].t) end

    if f.instantChange == false then
        currentField:enableInstantChange(false)
    else
        currentField:enableInstantChange(true)
    end
end

function ui.fieldLabel(f, i, l)

    if f.t then
        if f.t2 then f.t = f.t2 end
        if f.label then f.t = "        " .. f.t end
    end

    if f.label then
        local label = app.ui.getLabel(f.label, l)
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

function ui.fieldHeader(title)
    local radio = app.radio
    local formFields = app.formFields
    local lcdWidth = app.lcdWidth

    if not title then title = "No Title" end

    local w, _ = lcdGetWindowSize()
    local padding = 5
    local colStart = mathFloor(w * 59.4 / 100)
    if radio.navButtonOffset then colStart = colStart - radio.navButtonOffset end

    local buttonW = radio.buttonWidth and radio.menuButtonWidth or ((w - colStart) / 3 - padding)
    local buttonH = radio.navbuttonHeight

    formFields['menu'] = form.addLine("")

    formFields['title'] = form.addStaticText(formFields['menu'], {x = 0, y = radio.linePaddingTop, w = lcdWidth, h = radio.navbuttonHeight}, title)

    app.ui.navigationButtons(w - 5, radio.linePaddingTop, buttonW, buttonH)
end

function ui.openPageRefresh(opts)
    app.triggers.isReady = false
end

ui._helpCache = ui._helpCache or {}

local function getHelpData(section)
    if ui._helpCache[section] == nil then
        local helpPath = "app/modules/" .. section .. "/help.lua"

        if utils.file_exists(helpPath) then
            local chunk = loadfile(helpPath)
            local helpData = chunk and chunk() or nil

            ui._helpCache[section] =
                (type(helpData) == "table") and helpData or false
        else
            ui._helpCache[section] = false
        end
    end

    return ui._helpCache[section] or nil
end


function ui.openPage(opts)

    if type(opts) ~= "table" then
        error("ui.openPage expects a table")
    end

    local idx = opts.idx
    local title = opts.title
    local script = opts.script
    if not script then
        error("ui.openPage requires opts.script")
    end

    utils.reportMemoryUsage("ui.openPage: " .. script, "start")

    -- Ensure previous page releases resources before loading a new one.
    ui.cleanupCurrentPage()

    app.uiState = app.uiStatus.pages
    app.triggers.isReady = false
    app.lastLabel = nil

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    local modulePath = "app/modules/" .. script
    app.Page = assert(loadfile(modulePath))(idx)

    local section = script:match("([^/]+)")
    local helpData = getHelpData(section)
    app.fieldHelpTxt = helpData and helpData.fields or nil

    if app.Page.openPage then

        utils.reportMemoryUsage("app.Page.openPage: " .. script, "start")

        app.Page.openPage(opts)
        collectgarbage('collect')
        utils.reportMemoryUsage("app.Page.openPage: " .. script, "end")
        return
    end

    app.lastIdx = idx
    app.lastTitle = title
    app.lastScript = script

    form.clear()
    session.lastPage = script

    local pageTitle = app.Page.pageTitle or title
    app.ui.fieldHeader(pageTitle)

    if app.Page.headerLine then
        local headerLine = form.addLine("")
        form.addStaticText(headerLine, {x = 0, y = app.radio.linePaddingTop, w = app.lcdWidth, h = app.radio.navbuttonHeight}, app.Page.headerLine)
    end

    app.formLineCnt = 0

    if not ui._fieldHandlers then
        ui._fieldHandlers = {
            [0] = ui.fieldStaticText,
            [1] = ui.fieldChoice,
            [2] = ui.fieldNumber,
            [3] = ui.fieldText,
            [4] = ui.fieldBoolean,
            [5] = ui.fieldBooleanInverted or ui.fieldBoolean,
            [6] = ui.fieldSlider,
            [7] = ui.fieldSource,
            [8] = ui.fieldSwitch,
            [9] = ui.fieldSensor,
            [10] = ui.fieldColor
        }
    end

    if app.Page.apidata and app.Page.apidata.formdata and app.Page.apidata.formdata.fields then
        for i, field in ipairs(app.Page.apidata.formdata.fields) do
            local label = app.Page.apidata.formdata.labels
            if session.apiVersion == nil then return end

            local valid = (field.apiversion == nil or utils.apiVersionCompare(">=", field.apiversion)) and (field.apiversionlt == nil or utils.apiVersionCompare("<", field.apiversionlt)) and (field.apiversiongt == nil or utils.apiVersionCompare(">", field.apiversiongt)) and (field.apiversionlte == nil or utils.apiVersionCompare("<=", field.apiversionlte)) and (field.apiversiongte == nil or utils.apiVersionCompare(">=", field.apiversiongte)) and
                              (field.enablefunction == nil or field.enablefunction())

            if field.hidden ~= true and valid then
                app.ui.fieldLabel(field, i, label)
                local fieldType = field.table and 1 or field.type
                local handler = ui._fieldHandlers[fieldType] or ui.fieldNumber
                handler(i)
            else
                app.formFields[i] = {}
            end
        end
    end

    utils.reportMemoryUsage("ui.openPage: " .. script, "end")

    collectgarbage('collect')
    collectgarbage('collect')
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
    if app.Page.navButtons == nil then
        navButtons = {menu = true, save = true, reload = true, help = true}
    else
        navButtons = app.Page.navButtons
    end

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

    if navButtons.menu == true then
        app.formNavigationFields['menu'] = form.addButton(line, {x = menuOffset, y = y, w = w, h = h}, {
            text = "@i18n(app.navigation_menu)@",
            icon = nil,
            options = FONT_S,
            paint = function() end,
            press = function()
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

    if navButtons.save == true then
        app.formNavigationFields['save'] = form.addButton(line, {x = saveOffset, y = y, w = w, h = h}, {
            text = "@i18n(app.navigation_save)@",
            icon = nil,
            options = FONT_S,
            paint = function() end,
            press = function()
                if app.Page and app.Page.onSaveMenu then
                    app.Page.onSaveMenu(app.Page)
                else
                    app.triggers.triggerSave = true
                end
            end
        })
    end

    if navButtons.reload == true then
        app.formNavigationFields['reload'] = form.addButton(line, {x = reloadOffset, y = y, w = w, h = h}, {
            text = "@i18n(app.navigation_reload)@",
            icon = nil,
            options = FONT_S,
            paint = function() end,
            press = function()
                if app.Page and app.Page.onReloadMenu then
                    app.Page.onReloadMenu(app.Page)
                else
                    app.triggers.triggerReload = true
                end
                return true
            end
        })
    end

    if navButtons.tool == true then app.formNavigationFields['tool'] = form.addButton(line, {x = toolOffset, y = y, w = wS, h = h}, {text = "@i18n(app.navigation_tools)@", icon = nil, options = FONT_S, paint = function() end, press = function() app.Page.onToolMenu() end}) end

    if navButtons.help == true then
        local section = app.lastScript:match("([^/]+)")
        local script = app.lastScript:match("/([^/]+)%.lua$")

        local help = getHelpData(section)
        if help then
            app.formNavigationFields['help'] = form.addButton(line, {x = helpOffset, y = y, w = wS, h = h}, {
                text = "@i18n(app.navigation_help)@",
                icon = nil,
                options = FONT_S,
                paint = function() end,
                press = function()
                    if app.Page and app.Page.onHelpMenu then
                        app.Page.onHelpMenu(app.Page)
                    else
                        if help.help[script] then
                            app.ui.openPageHelp(help.help[script])
                        else
                            app.ui.openPageHelp(help.help['default'])
                        end
                    end
                end
            })
        else
            app.formNavigationFields['help'] = form.addButton(line, {x = helpOffset, y = y, w = wS, h = h}, {text = "@i18n(app.navigation_help)@", icon = nil, options = FONT_S, paint = function() end, press = function() end})
            app.formNavigationFields['help']:enable(false)
        end
    end
end

function ui.openPageHelp(txtData, title)
    local message
    if type(txtData) == "table" then
        message = tableConcat(txtData, "\r\n\r\n")
    else
        message = txtData
    end

    if not title then title = "@i18n(app.header_help)@ - " .. (app.lastTitle or "") end

    form.openDialog({width = app.lcdWidth, title = title, message = message, buttons = {{label = "@i18n(app.btn_close)@", action = function() return true end}}, options = TEXT_LEFT})
end

function ui.injectApiAttributes(formField, f, v)
    local log = utils.log

    if v.decimals and not f.decimals then
        if f.type ~= 1 then
            log("Injecting decimals: " .. v.decimals, "debug")
            f.decimals = v.decimals
            if formField.decimals then formField:decimals(v.decimals) end
        end
    end

    if v.scale and not f.scale then
        log("Injecting scale: " .. v.scale, "debug");
        f.scale = v.scale
    end
    if v.mult and not f.mult then
        log("Injecting mult: " .. v.mult, "debug");
        f.mult = v.mult
    end
    if v.offset and not f.offset then
        log("Injecting offset: " .. v.offset, "debug");
        f.offset = v.offset
    end

    if v.unit and not f.unit then
        if f.type ~= 1 then
            log("Injecting unit: " .. v.unit, "debug")
            if formField.suffix then formField:suffix(v.unit) end
        end
    end

    if v.step and not f.step then
        if f.type ~= 1 then
            log("Injecting step: " .. v.step, "debug")
            f.step = v.step
            if formField.step then formField:step(v.step) end
        end
    end

    if v.min and not f.min then
        f.min = v.min
        if f.offset then f.min = f.min + f.offset end
        if f.type ~= 1 then
            log("Injecting min: " .. f.min, "debug")
            if formField.minimum then formField:minimum(f.min) end
        end
    end

    if v.max and not f.max then
        f.max = v.max
        if f.offset then f.max = f.max + f.offset end
        if f.type ~= 1 then
            log("Injecting max: " .. f.max, "debug")
            if formField.maximum then formField:maximum(f.max) end
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
            if formField.default then formField:default(default) end
        end
    end

    if v.table and not f.table then
        f.table = v.table
        local idxInc = f.tableIdxInc or v.tableIdxInc
        local tbldata = app.utils.convertPageValueTable(v.table, idxInc)
        if f.type == 1 then
            log("Injecting table: {}", "debug")
            if formField.values then formField:values(tbldata) end
        end
    end

    if v.tableEthos and not f.tableEthos then
        local tbldata = v.tableEthos
        if f.type == 1 then
            log("Injecting table: {}", "debug")
            if formField.values then formField:values(tbldata) end
        end
    end

    if v.help then
        f.help = v.help
        log("Injecting help: {}", "debug")
        if formField.help then formField:help(v.help) end
    end

    if formField.focus then formField:focus(true) end
end

function ui.mspApiUpdateFormAttributes()

    local values = tasks.msp.api.apidata.values
    local structure = tasks.msp.api.apidata.structure

    local log = utils.log

    if not (app.Page.apidata.formdata and app.Page.apidata.api and app.Page.apidata.formdata.fields) then
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
            if part1 then return {part1, part2} end
        end
        return nil
    end

    local fields = app.Page.apidata.formdata.fields
    local api = app.Page.apidata.api

    if not app.Page.apidata.api_reversed then
        app.Page.apidata.api_reversed = {}
        for index, value in pairs(app.Page.apidata.api) do app.Page.apidata.api_reversed[value] = index end
    end

    for i, f in ipairs(fields) do
        local formField = app.formFields[i]
        if type(formField) == 'userdata' then
            if f.api then
                log("API field found: " .. f.api, "debug")
                local parts = combined_api_parts(f.api)
                if parts then
                    f.mspapi = parts[1];
                    f.apikey = parts[2]
                end
            end

            local apikey = f.apikey
            local mspapiID = f.mspapi
            local mspapiNAME = api[mspapiID]
            local target = structure[mspapiNAME]

            if mspapiID == nil or mspapiID == nil then
                log("API field missing mspapi or apikey", "debug")
            else
                for _, v in ipairs(target) do
                    if not v.bitmap then
                        if v.field == apikey and mspapiID == f.mspapi then

                            if v.help and (v.help == "" or v.help:match("^@i18n%b()@$")) then v.help = nil end

                            app.ui.injectApiAttributes(formField, f, v)

                            local scale = f.scale or 1
                            if values and values[mspapiNAME] and values[mspapiNAME][apikey] then app.Page.apidata.formdata.fields[i].value = values[mspapiNAME][apikey] / scale end

                            if values[mspapiNAME][apikey] == nil then
                                log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                                formField:enable(false)
                            end
                            break
                        end
                    else

                        for bidx, b in ipairs(v.bitmap) do
                            local bitmapField = v.field .. "->" .. b.field
                            if bitmapField == apikey and mspapiID == f.mspapi then
                                if v.help and (v.help == "" or v.help:match("^@i18n%b()@$")) then v.help = nil end

                                app.ui.injectApiAttributes(formField, f, b)

                                local scale = f.scale or 1
                                if values and values[mspapiNAME] and values[mspapiNAME][v.field] then
                                    local raw_value = values[mspapiNAME][v.field]
                                    local bit_value = (raw_value >> bidx - 1) & 1
                                    app.Page.apidata.formdata.fields[i].value = bit_value / scale
                                end

                                if values[mspapiNAME][v.field] == nil then
                                    log("API field value is nil: " .. mspapiNAME .. " " .. apikey, "info")
                                    formField:enable(false)
                                end

                                app.Page.apidata.formdata.fields[i].bitmap = bidx - 1
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

function ui.requestPage()
    local log = utils.log

    if not app.Page.apidata then return end
    if not app.Page.apidata.api and not app.Page.apidata.formdata then
        log("app.Page.apidata.api did not pass consistancy checks", "debug")
        return
    end

    if not app.Page.apidata.apiState then app.Page.apidata.apiState = {currentIndex = 1, isProcessing = false} end

    local apiList = app.Page.apidata.api
    local state = app.Page.apidata.apiState

    if state.isProcessing then
        log("requestPage is already running, skipping duplicate call.", "debug")
        return
    end
    state.isProcessing = true

    if not tasks.msp.api.apidata.values then
        log("requestPage Initialize values on first run", "debug")
        tasks.msp.api.apidata.values = {}
        tasks.msp.api.apidata.structure = {}
        tasks.msp.api.apidata.receivedBytesCount = {}
        tasks.msp.api.apidata.receivedBytes = {}
        tasks.msp.api.apidata.positionmap = {}
        tasks.msp.api.apidata.other = {}
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
                app.ui.mspApiUpdateFormAttributes()
                if app.Page.postLoad then
                    app.Page.postLoad(app.Page)
                else
                    app.triggers.closeProgressLoader = true
                end
                checkForUnresolvedTimeouts()

            end
            return
        end

        local v = apiList[state.currentIndex]
        local apiKey = type(v) == "string" and v or v.name
        local retryCount = app.Page.apidata.retryCount and app.Page.apidata.retryCount[apiKey] or 0
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
            tasks.msp.api.apidata.values[apiKey] = API.data().parsed
            tasks.msp.api.apidata.structure[apiKey] = API.data().structure
            tasks.msp.api.apidata.receivedBytes[apiKey] = API.data().buffer
            tasks.msp.api.apidata.receivedBytesCount[apiKey] = API.data().receivedBytesCount
            tasks.msp.api.apidata.positionmap[apiKey] = API.data().positionmap
            tasks.msp.api.apidata.other[apiKey] = API.data().other or {}
            app.Page.apidata.retryCount[apiKey] = 0
            state.currentIndex = state.currentIndex + 1
            API = nil

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
            API = nil

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

function ui.saveSettings()

    local log = utils.log

    if app.pageState == app.pageStatus.saving then return end
    if not (app.Page and app.Page.apidata and app.Page.apidata.formdata and app.Page.apidata.formdata.fields and app.Page.apidata.api) then
        log("saveSettings called without valid apidata; skipping.", "info")
        app.pageState = app.pageStatus.display
        app.triggers.isSaving = false
        app.triggers.closeSaveFake = true
        app.triggers.saveFailed = true
        return
    end

    app.pageState = app.pageStatus.saving
    app.saveTS = osClock()

    log("Saving data", "debug")

    local mspapi = app.Page.apidata
    local apiList = mspapi.api
    local values = tasks.msp.api.apidata.values

    local totalRequests = #apiList
    local completedRequests = 0
    local enqueueFailures = 0

    app.Page.apidata.apiState.isProcessing = true

    if app.Page.preSave then app.Page.preSave(app.Page) end

    for apiID, apiNAME in ipairs(apiList) do

        utils.reportMemoryUsage("ui.saveSettings " .. apiNAME, "start")

        local payloadData = values[apiNAME]
        local payloadStructure = tasks.msp.api.apidata.structure[apiNAME]

        local API = tasks.msp.api.load(apiNAME)
        API.setErrorHandler(function(self, buf) app.triggers.saveFailed = true end)
        API.setCompleteHandler(function(self, buf)
            completedRequests = completedRequests + 1
            log("API " .. apiNAME .. " write complete", "debug")
            API = nil

            if completedRequests == totalRequests then
                log("All API requests have been completed!", "debug")
                app.Page.apidata.apiState.isProcessing = false
                if enqueueFailures > 0 or app.triggers.saveFailed then
                    app.pageState = app.pageStatus.display
                    app.triggers.closeSaveFake = true
                    app.triggers.isSaving = false
                else
                    if app.Page.postSave then app.Page.postSave(app.Page) end
                    app.utils.settingsSaved()
                end
            end
        end)

        local fieldMap = {}
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

        for k, v in pairs(payloadData) do
            local fieldIndex = fieldMap[k]
            if fieldIndex then
                payloadData[k] = app.Page.apidata.formdata.fields[fieldIndex].value
            elseif fieldMapBitmap[k] then
                local originalValue = tonumber(v) or 0
                local newValue = originalValue
                for bit, idx in pairs(fieldMapBitmap[k]) do
                    local fieldVal = mathFloor(tonumber(app.Page.apidata.formdata.fields[idx].value) or 0)
                    local mask = 1 << (bit)
                    if fieldVal ~= 0 then
                        newValue = newValue | mask
                    else
                        newValue = newValue & (~mask)
                    end
                end
                payloadData[k] = newValue
            end
        end

        for k, v in pairs(payloadData) do
            log("Set value for " .. k .. " to " .. v, "debug")
            API.setValue(k, v)
        end

        local payload = nil
        if app.Page.preSavePayload and payloadStructure then
            local core = getApiCore()
            if core and core.buildWritePayload then
                payload = core.buildWritePayload(apiNAME, payloadData, payloadStructure, false)
                local adjusted = app.Page.preSavePayload(payload)
                if adjusted ~= nil then payload = adjusted end
            end
        end

        local ok, reason
        if payload then
            ok, reason = API.write(payload)
        else
            ok, reason = API.write()
        end

        if not ok then
            enqueueFailures = enqueueFailures + 1
            completedRequests = completedRequests + 1
            app.triggers.saveFailed = true
            log("API " .. apiNAME .. " enqueue rejected: " .. tostring(reason), "info")
            if completedRequests == totalRequests then
                app.Page.apidata.apiState.isProcessing = false
                app.pageState = app.pageStatus.display
                app.triggers.closeSaveFake = true
                app.triggers.isSaving = false
            end
        end

        utils.reportMemoryUsage("ui.saveSettings " .. apiNAME, "end")

    end

end

function ui.rebootFc()

    app.pageState = app.pageStatus.rebooting
    local ok, reason = tasks.msp.mspQueue:add({
        command = 68,
        uuid = "ui.reboot",
        processReply = function(self, buf)
            app.utils.invalidatePages()
            utils.onReboot()
        end,
        simulatorResponse = {}
    })
    if not ok then
        utils.log("Reboot enqueue rejected: " .. tostring(reason), "info")
        app.pageState = app.pageStatus.display
        app.triggers.closeSaveFake = true
        app.triggers.isSaving = false
    end
end

function ui.adminStatsOverlay()


    if preferences and preferences.developer and preferences.developer.overlaystatsadmin then

        lcdFont(FONT_XXS)
        lcdColor(lcd.RGB(255, 255, 255))

        local cpuUsage = (rfsuite.performance and rfsuite.performance.cpuload) or 0
        local ramUsed = (rfsuite.performance and rfsuite.performance.usedram) or 0
        local luaRamKB = (rfsuite.performance and rfsuite.performance.luaRamKB) or 0

        local cfg = {startY = app.radio.navbuttonHeight + 3, decimalsKB = 0, labelGap = 4, blocks = {LOAD = {x = 0, valueRight = 50}, USED = {x = 70, valueRight = 130}, FREE = {x = 160, valueRight = 230}}}

        local function fmtInt(n) return utils.round(n or 0, 0) end
        local function fmtKB(n) return string.format("%." .. tostring(cfg.decimalsKB) .. "f", n or 0) end

        local rows = {{"LOAD", "LOAD:", tostring(fmtInt(cpuUsage)) .. "%"}, {"USED", "USED", tostring(fmtInt(ramUsed)) .. "kB"}, {"FREE", "FREE", tostring(fmtKB(luaRamKB)) .. "KB"}}

        local y = cfg.startY

        local function drawBlock(key, label, valueWithUnit)
            local b = cfg.blocks[key];
            if not b then return end

            lcdDrawText(b.x, y, label)

            local vx = b.x + lcdGetTextSize(label) + cfg.labelGap
            local vWidth = lcdGetTextSize(valueWithUnit)
            lcdDrawText(math.max(vx, b.valueRight - vWidth), y, valueWithUnit)
        end

        for i = 1, #rows do
            local key, label, v = rows[i][1], rows[i][2], rows[i][3]
            drawBlock(key, label, v)
        end
    end
end

return ui
