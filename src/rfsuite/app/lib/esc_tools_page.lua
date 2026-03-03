--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local escToolsPage = {}

local function loadEscConfig(folder)
    if type(folder) ~= "string" or folder == "" then return nil end
    local path = "app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"
    local chunk = loadfile(path)
    if not chunk then return nil end
    local ok, moduleOrErr = pcall(chunk)
    if not ok or type(moduleOrErr) ~= "table" then return nil end
    return moduleOrErr
end

local function normalizeEscTarget(value, escConfig)
    local esc1Target = tonumber(escConfig and escConfig.esc4wayEsc1Target)
    local esc2Target = tonumber(escConfig and escConfig.esc4wayEsc2Target)
    if esc1Target == nil then esc1Target = 0 end
    if esc2Target == nil then esc2Target = 1 end
    esc1Target = math.floor(esc1Target)
    esc2Target = math.floor(esc2Target)
    if esc2Target == esc1Target then
        esc2Target = (esc1Target == 0) and 1 or 0
    end

    local target = tonumber(value)
    if target == esc2Target then return esc2Target end
    if target == esc1Target then return esc1Target end
    return esc1Target
end

local function scheduleIn(delaySeconds, fn)
    local delay = tonumber(delaySeconds) or 0
    if delay < 0 then delay = 0 end
    local scheduler = rfsuite.tasks and rfsuite.tasks.callback
    if delay > 0 and scheduler and scheduler.inSeconds then
        scheduler.inSeconds(delay, fn)
    else
        fn()
    end
end

local function isMspQueueIdle()
    local queue = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if queue and queue.isProcessed then
        return queue:isProcessed() == true
    end
    return true
end

local function writeEsc4WayTarget(target, opts, done)
    opts = opts or {}
    local waitForIdle = opts.waitForIdle == true
    local idlePollInterval = tonumber(opts.idlePollInterval)
    if idlePollInterval == nil then idlePollInterval = 0.15 end
    if idlePollInterval < 0 then idlePollInterval = 0 end
    local idleTimeout = tonumber(opts.idleTimeout)
    if idleTimeout == nil then idleTimeout = 2.5 end
    if idleTimeout < 0 then idleTimeout = 0 end
    local writeTimeout = tonumber(opts.timeout)
    if writeTimeout ~= nil and writeTimeout <= 0 then writeTimeout = nil end
    local retryCount = tonumber(opts.retryCount)
    if retryCount == nil then retryCount = 1 end
    if retryCount < 0 then retryCount = 0 end
    retryCount = math.floor(retryCount)
    local retryDelay = tonumber(opts.retryDelay)
    if retryDelay == nil then retryDelay = 0.75 end
    if retryDelay < 0 then retryDelay = 0 end
    local maxAttempts = retryCount + 1

    local mspApi = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if not (mspApi and mspApi.load) then
        if done then done(false, "msp_api_missing", 0) end
        return false
    end

    local attempts = 0
    local idleWaitStartedAt = os.clock()
    local finished = false

    local function finish(success, err)
        if finished then return end
        finished = true
        if done then done(success, err, attempts) end
    end

    local function tryWrite()
        if finished then return end

        if waitForIdle and not isMspQueueIdle() then
            if (os.clock() - idleWaitStartedAt) < idleTimeout then
                scheduleIn(idlePollInterval, tryWrite)
            else
                finish(false, "queue_busy")
            end
            return
        end

        attempts = attempts + 1
        local API = mspApi.load("4WIF_ESC_FWD_PROG")
        if not API then
            finish(false, "4wif_api_missing")
            return
        end
        if writeTimeout and API.setTimeout then
            API.setTimeout(writeTimeout)
        end
        API.setValue("target", target)
        API.setCompleteHandler(function(self, buf)
            finish(true)
        end)
        API.setErrorHandler(function(self, err)
            if attempts < maxAttempts then
                scheduleIn(retryDelay, tryWrite)
                return
            end
            finish(false, err)
        end)
        if rfsuite.utils and rfsuite.utils.uuid then
            API.setUUID(rfsuite.utils.uuid())
        else
            API.setUUID(tostring(os.clock()))
        end
        local ok, reason = API.write()
        if not ok then
            if attempts < maxAttempts then
                scheduleIn(retryDelay, tryWrite)
                return
            end
            finish(false, reason or "enqueue_failed")
        end
    end

    tryWrite()
    return true
end

local function readEscApiOnce(apiName, opts, done)
    opts = opts or {}
    local waitForIdle = opts.waitForIdle == true
    local idlePollInterval = tonumber(opts.idlePollInterval)
    if idlePollInterval == nil then idlePollInterval = 0.15 end
    if idlePollInterval < 0 then idlePollInterval = 0 end
    local idleTimeout = tonumber(opts.idleTimeout)
    if idleTimeout == nil then idleTimeout = 2.5 end
    if idleTimeout < 0 then idleTimeout = 0 end
    local readTimeout = tonumber(opts.timeout)
    if readTimeout ~= nil and readTimeout <= 0 then readTimeout = nil end
    local retryCount = tonumber(opts.retryCount)
    if retryCount == nil then retryCount = 0 end
    if retryCount < 0 then retryCount = 0 end
    retryCount = math.floor(retryCount)
    local retryDelay = tonumber(opts.retryDelay)
    if retryDelay == nil then retryDelay = 0.75 end
    if retryDelay < 0 then retryDelay = 0 end
    local maxAttempts = retryCount + 1

    local mspApi = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if not (mspApi and mspApi.load) then
        if done then done(false, "msp_api_missing", 0) end
        return false
    end
    if type(apiName) ~= "string" or apiName == "" then
        if done then done(false, "api_name_missing", 0) end
        return false
    end

    local attempts = 0
    local idleWaitStartedAt = os.clock()
    local finished = false

    local function finish(success, err)
        if finished then return end
        finished = true
        if done then done(success, err, attempts) end
    end

    local function tryRead()
        if finished then return end

        if waitForIdle and not isMspQueueIdle() then
            if (os.clock() - idleWaitStartedAt) < idleTimeout then
                scheduleIn(idlePollInterval, tryRead)
            else
                finish(false, "queue_busy")
            end
            return
        end

        attempts = attempts + 1
        local API = mspApi.load(apiName)
        if not API then
            finish(false, "api_missing")
            return
        end
        if readTimeout and API.setTimeout then
            API.setTimeout(readTimeout)
        end
        API.setCompleteHandler(function(self, buf)
            finish(true)
        end)
        API.setErrorHandler(function(self, err)
            if attempts < maxAttempts then
                scheduleIn(retryDelay, tryRead)
                return
            end
            finish(false, err)
        end)
        if rfsuite.utils and rfsuite.utils.uuid then
            API.setUUID(rfsuite.utils.uuid())
        else
            API.setUUID(tostring(os.clock()))
        end
        local ok, reason = API.read()
        if not ok then
            if attempts < maxAttempts then
                scheduleIn(retryDelay, tryRead)
                return
            end
            finish(false, reason or "enqueue_failed")
        end
    end

    tryRead()
    return true
end

function escToolsPage.createEsc4WayPostSaveHandler(folder, escConfig)
    local ESC = escConfig
    if type(ESC) ~= "table" then
        ESC = loadEscConfig(folder)
    end
    if not (ESC and ESC.postSaveSwitchCycle == true) then
        return nil
    end

    local resetTarget = tonumber(ESC.postSaveResetTarget) or 100
    local settleDelay = tonumber(ESC.postSaveSettleDelay)
    if settleDelay == nil then settleDelay = 0 end
    if settleDelay < 0 then settleDelay = 0 end
    local restoreDelay = tonumber(ESC.postSaveReturnTargetDelay)
    if restoreDelay == nil then restoreDelay = 0.8 end
    if restoreDelay < 0 then restoreDelay = 0 end
    local switchRetryCount = tonumber(ESC.postSaveSwitchRetryCount)
    if switchRetryCount == nil then switchRetryCount = 1 end
    if switchRetryCount < 0 then switchRetryCount = 0 end
    switchRetryCount = math.floor(switchRetryCount)
    local switchRetryDelay = tonumber(ESC.postSaveSwitchRetryDelay)
    if switchRetryDelay == nil then switchRetryDelay = 0.75 end
    if switchRetryDelay < 0 then switchRetryDelay = 0 end
    local switchTimeout = tonumber(ESC.postSaveSwitchTimeout)
    if switchTimeout == nil then switchTimeout = 6 end
    if switchTimeout <= 0 then switchTimeout = nil end
    local waitQueueIdle = ESC.postSaveWaitQueueIdle ~= false
    local queueIdlePoll = tonumber(ESC.postSaveQueueIdlePoll)
    if queueIdlePoll == nil then queueIdlePoll = 0.15 end
    if queueIdlePoll < 0 then queueIdlePoll = 0 end
    local queueIdleTimeout = tonumber(ESC.postSaveQueueIdleTimeout)
    if queueIdleTimeout == nil then queueIdleTimeout = 2.5 end
    if queueIdleTimeout < 0 then queueIdleTimeout = 0 end
    local restoreSettleDelay = tonumber(ESC.postSaveRestoreSettleDelay)
    if restoreSettleDelay == nil then restoreSettleDelay = 0.5 end
    if restoreSettleDelay < 0 then restoreSettleDelay = 0 end
    local flushRead = ESC.postSaveFlushRead == true
    local flushReadApi = ESC.postSaveFlushReadApi or ESC.mspapi
    local flushReadDelay = tonumber(ESC.postSaveFlushReadDelay)
    if flushReadDelay == nil then flushReadDelay = 0.25 end
    if flushReadDelay < 0 then flushReadDelay = 0 end
    local flushReadRetryCount = tonumber(ESC.postSaveFlushReadRetryCount)
    if flushReadRetryCount == nil then flushReadRetryCount = 0 end
    if flushReadRetryCount < 0 then flushReadRetryCount = 0 end
    flushReadRetryCount = math.floor(flushReadRetryCount)
    local flushReadRetryDelay = tonumber(ESC.postSaveFlushReadRetryDelay)
    if flushReadRetryDelay == nil then flushReadRetryDelay = 0.6 end
    if flushReadRetryDelay < 0 then flushReadRetryDelay = 0 end
    local flushReadTimeout = tonumber(ESC.postSaveFlushReadTimeout)
    if flushReadTimeout ~= nil and flushReadTimeout <= 0 then flushReadTimeout = nil end

    local writeOpts = {
        waitForIdle = waitQueueIdle,
        idlePollInterval = queueIdlePoll,
        idleTimeout = queueIdleTimeout,
        timeout = switchTimeout,
        retryCount = switchRetryCount,
        retryDelay = switchRetryDelay
    }
    local readOpts = {
        waitForIdle = waitQueueIdle,
        idlePollInterval = queueIdlePoll,
        idleTimeout = queueIdleTimeout,
        timeout = flushReadTimeout,
        retryCount = flushReadRetryCount,
        retryDelay = flushReadRetryDelay
    }

    return function(_, onComplete)
        local complete = onComplete
        if type(complete) ~= "function" then complete = nil end
        local completionSent = false
        local function finish()
            if completionSent then return end
            completionSent = true
            if rfsuite.utils and rfsuite.utils.log then
                rfsuite.utils.log("ESC 4WIF post-save cycle complete", "info")
            end
            if complete then complete() end
        end

        local target = normalizeEscTarget(rfsuite.session and rfsuite.session.esc4WayTarget, ESC)
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ESC 4WIF post-save cycle: " .. tostring(resetTarget) .. " -> " .. tostring(target), "info")
        end

        local function restoreTarget()
            writeEsc4WayTarget(target, writeOpts, function(success, err, attempts)
                if (not success) and rfsuite.utils and rfsuite.utils.log then
                    rfsuite.utils.log("ESC 4WIF post-save restore failed: " .. tostring(err) .. " (attempts=" .. tostring(attempts) .. ")", "info")
                end
                if not success then
                    scheduleIn(restoreSettleDelay, finish)
                    return
                end
                if not flushRead or type(flushReadApi) ~= "string" or flushReadApi == "" then
                    scheduleIn(restoreSettleDelay, finish)
                    return
                end
                scheduleIn(flushReadDelay, function()
                    readEscApiOnce(flushReadApi, readOpts, function(readOk, readErr, readAttempts)
                        if (not readOk) and rfsuite.utils and rfsuite.utils.log then
                            rfsuite.utils.log(
                                "ESC 4WIF post-save flush read failed: " .. tostring(readErr) .. " (attempts=" .. tostring(readAttempts) .. ")",
                                "info"
                            )
                        end
                        scheduleIn(restoreSettleDelay, finish)
                    end)
                end)
            end)
        end

        local function resetTargetAfterSettle()
            writeEsc4WayTarget(resetTarget, writeOpts, function(success, err, attempts)
                if (not success) and rfsuite.utils and rfsuite.utils.log then
                    rfsuite.utils.log("ESC 4WIF post-save reset failed: " .. tostring(err) .. " (attempts=" .. tostring(attempts) .. ")", "info")
                end
                scheduleIn(restoreDelay, restoreTarget)
            end)
        end

        scheduleIn(settleDelay, resetTargetAfterSettle)
        return false
    end
end

local function isFlagDisabled(value)
    return value == false or value == "false"
end

local function openLocalProgressDialog(opts)
    local useWait = rfsuite.utils and rfsuite.utils.ethosVersionAtLeast and
        rfsuite.utils.ethosVersionAtLeast({26, 1, 0}) and form.openWaitDialog
    if useWait then
        opts.progress = true
        return form.openWaitDialog(opts)
    end
    return form.openProgressDialog(opts)
end

function escToolsPage.createIsolatedSaveMenuHandler(folder, escConfig)
    local ESC = escConfig
    if type(ESC) ~= "table" then
        ESC = loadEscConfig(folder)
    end
    if not (ESC and ESC.useIsolatedSaveDialog == true) then
        return nil
    end

    local timeoutSeconds = tonumber(ESC.isolatedSaveTimeout)
    if timeoutSeconds == nil then timeoutSeconds = 30 end
    if timeoutSeconds < 1 then timeoutSeconds = 1 end
    local processingStep = tonumber(ESC.isolatedSaveProgressProcessingStep)
    if processingStep == nil then processingStep = 2 end
    if processingStep < 0 then processingStep = 0 end
    local processingCap = tonumber(ESC.isolatedSaveProgressProcessingCap)
    if processingCap == nil then processingCap = 90 end
    if processingCap < 0 then processingCap = 0 end
    if processingCap > 99 then processingCap = 99 end
    local idleStep = tonumber(ESC.isolatedSaveProgressIdleStep)
    if idleStep == nil then idleStep = 1 end
    if idleStep < 0 then idleStep = 0 end
    local idleCap = tonumber(ESC.isolatedSaveProgressIdleCap)
    if idleCap == nil then idleCap = 97 end
    if idleCap < processingCap then idleCap = processingCap end
    if idleCap > 99 then idleCap = 99 end
    local saveMessage = ESC.isolatedSaveMessage or "@i18n(app.msg_saving_settings)@"
    local waitEscMessage = ESC.isolatedSaveWaitEscMessage or "Waiting for ESC..."
    local gcAfterSave = ESC.isolatedSaveGcCollect ~= false
    local gcPasses = tonumber(ESC.isolatedSaveGcPasses)
    if gcPasses == nil then gcPasses = 1 end
    if gcPasses < 0 then gcPasses = 0 end
    gcPasses = math.floor(gcPasses)

    local saveState = {
        running = false,
        dialog = nil,
        startedAt = 0,
        progress = 0,
        pageRef = nil,
        messageTag = nil,
        gcOnClose = false
    }

    local function closeSaveDialog()
        local dialog = saveState.dialog
        if dialog then
            pcall(function() dialog:close() end)
        end
        local app = rfsuite.app
        if app and app.triggers then
            app.triggers.isSaving = false
        end
        saveState.running = false
        saveState.dialog = nil
        saveState.startedAt = 0
        saveState.progress = 0
        saveState.pageRef = nil
        saveState.messageTag = nil
        if saveState.gcOnClose and gcAfterSave and gcPasses > 0 then
            for _ = 1, gcPasses do
                collectgarbage("collect")
            end
        end
        saveState.gcOnClose = false
    end

    local function isSaveProcessing()
        local page = saveState.pageRef
        local app = rfsuite.app
        if page and page.apidata and page.apidata.apiState and page.apidata.apiState.isProcessing == true then
            return true
        end
        if app and app.triggers and app.triggers.savePendingAsync == true then
            return true
        end
        return false
    end

    local function isSaveComplete()
        local app = rfsuite.app
        if not app then return false end
        if isSaveProcessing() then return false end
        local queue = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
        if queue and queue.isProcessed and queue:isProcessed() ~= true then return false end
        return app.pageState == app.pageStatus.display
    end

    local function isSaveFailed()
        local app = rfsuite.app
        if not (app and app.triggers) then return false end
        return app.triggers.saveFailed == true and app.triggers.savePendingAsync ~= true
    end

    local function beginSave(page)
        local app = rfsuite.app
        if not (app and app.ui and type(app.ui.saveSettings) == "function") then return end
        if saveState.running then return end
        if not page then return end
        if app.pageState == app.pageStatus.saving then return end

        saveState.running = true
        saveState.startedAt = os.clock()
        saveState.progress = 0
        saveState.pageRef = page
        saveState.gcOnClose = true

        app.triggers.saveFailed = false
        app.triggers.savePendingAsync = false
        app.triggers.closeSave = false
        app.triggers.closeSaveFake = false
        app.triggers.isSaving = false

        local title = "@i18n(app.msg_saving)@"
        local message = saveMessage
        saveState.dialog = openLocalProgressDialog({
            title = title,
            message = message,
            close = function() end,
            wakeup = function()
                local dialog = saveState.dialog
                if not dialog then
                    closeSaveDialog()
                    return
                end

                if isSaveProcessing() then
                    saveState.progress = math.min(processingCap, saveState.progress + processingStep)
                elseif isSaveFailed() then
                    if rfsuite.utils and rfsuite.utils.log then
                        rfsuite.utils.log("ESC isolated save failed", "info")
                    end
                    dialog:message("@i18n(app.error_timed_out)@")
                    dialog:closeAllowed(true)
                    dialog:value(100)
                    closeSaveDialog()
                    return
                elseif isSaveComplete() then
                    dialog:value(100)
                    closeSaveDialog()
                    return
                else
                    saveState.progress = math.min(idleCap, saveState.progress + idleStep)
                end

                if (os.clock() - saveState.startedAt) > timeoutSeconds then
                    if rfsuite.utils and rfsuite.utils.log then
                        rfsuite.utils.log("ESC isolated save timeout", "info")
                    end
                    dialog:message("@i18n(app.error_timed_out)@")
                    dialog:closeAllowed(true)
                    dialog:value(100)
                    closeSaveDialog()
                    return
                end

                local appNow = rfsuite.app
                local pendingEsc = appNow and appNow.triggers and appNow.triggers.savePendingAsync == true
                local nextTag = (pendingEsc and saveState.progress >= processingCap) and "wait_esc" or "saving"
                if saveState.messageTag ~= nextTag then
                    saveState.messageTag = nextTag
                    if nextTag == "wait_esc" then
                        dialog:message(waitEscMessage)
                    else
                        dialog:message(saveMessage)
                    end
                end

                dialog:value(saveState.progress)
            end
        })

        if saveState.dialog then
            saveState.dialog:value(0)
            saveState.dialog:closeAllowed(false)
        else
            saveState.running = false
            saveState.startedAt = 0
            saveState.progress = 0
            saveState.pageRef = nil
        end

        app.ui.saveSettings(page)
    end

    local function onSaveMenu(page)
        if saveState.running then return true end
        local targetPage = page or (rfsuite.app and rfsuite.app.Page)
        if not targetPage then return true end
        if targetPage.canSave and targetPage.canSave(targetPage) ~= true then return true end

        local prefs = rfsuite.preferences and rfsuite.preferences.general
        if isFlagDisabled(prefs and prefs.save_confirm) then
            beginSave(targetPage)
            return true
        end

        form.openDialog({
            width = nil,
            title = "@i18n(app.msg_save_settings)@",
            message = "@i18n(app.msg_save_current_page)@",
            buttons = {
                {
                    label = "@i18n(app.btn_ok_long)@",
                    action = function()
                        beginSave(targetPage)
                        return true
                    end
                },
                {
                    label = "@i18n(app.btn_cancel)@",
                    action = function() return true end
                }
            },
            wakeup = function() end,
            paint = function() end,
            options = TEXT_LEFT
        })

        return true
    end

    return {
        onSaveMenu = onSaveMenu,
        close = closeSaveDialog
    }
end

function escToolsPage.createSubmenuHandlers(folder)
    local function onNavMenu()
        pageRuntime.openMenuContext({defaultSection = "system"})
        return true
    end

    local function event(_, category, value)
        return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
    end

    return {
        onNavMenu = onNavMenu,
        event = event,
        navButtons = {menu = true, save = true, reload = true, tool = false, help = false}
    }
end

return escToolsPage
