--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local escMspV2 = assert(loadfile("app/modules/esc_tools/tools/esc_msp_v2.lua"))()
local lcd = lcd

local function loadMask(path)
    local ui = rfsuite.app and rfsuite.app.ui
    if ui and ui.loadMask then return ui.loadMask(path) end
    return lcd.loadMask(path)
end

local mspSignature
local mspBytes
local simulatorResponse
local escDetails = {}
local foundESC = false
local foundESCupdateTag = false
local ESC
local findTimeoutClock = os.clock()
local findTimeoutDefault = math.floor(rfsuite.tasks.msp.protocol.pageReqTimeout * 0.5)
local findTimeout = findTimeoutDefault

local modelLine
local modelText
local modelTextPos = {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}

local waitingTailMode = false
local pendingTailModeResolve = false
local inSelector = false
local lastOpts
local renderLoading
local renderToolPage
local openSelector
local switchState
local escReadReadyAt
local pendingChildOpen
local switchLoadingActive = false
local esc2Available = nil
local esc2CheckPending = false
local esc2CheckLastAttempt = 0
local esc2CheckRetryDelay = 0.6
local selectorPostConnectReady = nil
local selectorGuardPending = false
local selectorGuardOk = nil
local selectorGuardNeedsReset = false
local selectorGuardStartedAt = 0
local selectorGuardTimeout = 2.5
local selectorGuardRetryAt = 0
local selectorGuardRetryDelayDefault = 0.75
local writeSeq = 0
local lastWriteSeq = 0
local last4WayWriteTarget
local last4WayWriteOk
local escReadRecoverRequested = false
local escReadRecoverAt = 0
local escReadRecoverCount = 0
local escDetailsNextReadAt = 0
local escSwitchReadFlushPending = false
local escDetailsApiName
local escDetailsApi
local escSwitchApi
local escDetailsHandlersApi
local escHeaderV2
local esc2CheckApi
local esc2CheckHandlersApi
local selectorButtonsReadyState
local selectorButtonsEsc2State
local toolButtonMeta = {}
local toolButtonHandlers = {}
local selectorButtonMeta = {}
local selectorButtonHandlers = {}

local function noop() end

local function trimText(value)
    if type(value) ~= "string" then return value end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function escInitPathForFolder(folder)
    return "app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"
end

local function escFolderExists(folder)
    if type(folder) ~= "string" or folder == "" then return false end
    return os.stat(escInitPathForFolder(folder)) ~= nil
end

local function resolveEscFolder(folder, title)
    if escFolderExists(folder) then return folder end

    if type(title) == "string" then
        local tail = trimText(title:match("([^/]+)$"))
        if escFolderExists(tail) then return tail end
        if type(tail) == "string" and tail ~= "" then
            local lowerTail = tail:lower()
            if escFolderExists(lowerTail) then return lowerTail end
            local compactTail = lowerTail:gsub("%s+", "")
            if escFolderExists(compactTail) then return compactTail end
        end
    end

    if lastOpts and escFolderExists(lastOpts.folder) then
        return lastOpts.folder
    end
    return nil
end

-- Update the model/version header without creating overlapping widgets.
-- Ethos keeps old widgets; re-adding at the same position can overlay text (e.g. "UNKNOWN" over the real value).
local function setModelHeaderText(text)
    if not modelLine then return end
    if not modelText then
        modelText = form.addStaticText(modelLine, modelTextPos, text or "")
        return
    end
    local ok = pcall(function() modelText:value(text or "") end)
    if not ok then
        -- Fallback for older widget types: recreate once
        modelText = form.addStaticText(modelLine, modelTextPos, text or "")
    end
end

local function updateEscHeaderText()
    if escDetails.model ~= nil and escDetails.version ~= nil and escDetails.firmware ~= nil then
        local prefix = ""
        local target = rfsuite.session and rfsuite.session.esc4WayTarget or 0
        local _, esc2Target = getEsc4WayTargets()
        if target == esc2Target then
            prefix = "ESC2 - "
        else
            prefix = "ESC1 - "
        end

        local text = prefix .. escDetails.model .. " " .. escDetails.version .. " " .. escDetails.firmware
        rfsuite.escHeaderLineText = text
        setModelHeaderText(text)
    end
end

local function resetUiState()
    foundESC = false
    foundESCupdateTag = false
    findTimeoutClock = os.clock()
    escDetailsNextReadAt = 0
end

local function getEscDetailsPollInterval()
    local interval = tonumber(ESC and ESC.escDetailsPollInterval)
    if interval == nil then interval = 0.35 end
    if interval < 0 then interval = 0 end
    return interval
end

local function getEscDetailsRetryInterval()
    local interval = tonumber(ESC and ESC.escDetailsRetryInterval)
    if interval == nil then interval = 0.9 end
    if interval < 0 then interval = 0 end
    return interval
end

local function getInitialConnectTimeout()
    local timeout = tonumber(ESC and ESC.initialConnectTimeout)
    if timeout == nil then timeout = findTimeoutDefault end
    if timeout < 0 then timeout = 0 end
    return timeout
end

local function getEsc4WayTargets()
    local esc1Target = tonumber(ESC and ESC.esc4wayEsc1Target)
    local esc2Target = tonumber(ESC and ESC.esc4wayEsc2Target)
    if esc1Target == nil then esc1Target = 0 end
    if esc2Target == nil then esc2Target = 1 end
    esc1Target = math.floor(esc1Target)
    esc2Target = math.floor(esc2Target)
    if esc2Target == esc1Target then
        esc2Target = (esc1Target == 0) and 1 or 0
    end
    return esc1Target, esc2Target
end

local function getSelectorGuardRetryDelay()
    local delay = tonumber(ESC and ESC.selectorGuardRetryDelay)
    if delay == nil then delay = selectorGuardRetryDelayDefault end
    if delay < 0 then delay = 0 end
    return delay
end

local function scheduleSelectorGuardRetry(reason)
    selectorGuardNeedsReset = true
    selectorGuardPending = false
    selectorGuardStartedAt = 0
    selectorGuardRetryAt = os.clock() + getSelectorGuardRetryDelay()
    if reason and rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log("ESC 4WIF selector guard retry: " .. tostring(reason), "info")
    end
end

local function scheduleEscDetailsReadAt(delaySeconds)
    local delay = tonumber(delaySeconds) or 0
    if delay < 0 then delay = 0 end
    local nextAt = os.clock() + delay
    if nextAt > escDetailsNextReadAt then
        escDetailsNextReadAt = nextAt
    end
end

local function clearEscSession()
    if rfsuite.session then
        rfsuite.session.escDetails = nil
        rfsuite.session.escBuffer = nil
    end
    escDetails = {}
end

local function clearEscQueueEntries(apiName)
    if type(apiName) ~= "string" or apiName == "" then return end
    local queue = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if queue and type(queue.removeQueuedBy) == "function" then
        queue:removeQueuedBy(function(msg)
            return msg and msg.apiname == apiName
        end)
    end
end

local function clearApiCacheEntry(apiName)
    if type(apiName) ~= "string" or apiName == "" then return end
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if api and type(api.clearEntry) == "function" then
        api.clearEntry(apiName)
        return
    end

    local apidata = api and api.apidata
    if type(apidata) ~= "table" then return end
    if apidata.values then apidata.values[apiName] = nil end
    if apidata.structure then apidata.structure[apiName] = nil end
    if apidata.receivedBytes then apidata.receivedBytes[apiName] = nil end
    if apidata.receivedBytesCount then apidata.receivedBytesCount[apiName] = nil end
    if apidata.positionmap then apidata.positionmap[apiName] = nil end
    if apidata.other then apidata.other[apiName] = nil end
    if apidata._lastReadMode then apidata._lastReadMode[apiName] = nil end
    if apidata._lastWriteMode then apidata._lastWriteMode[apiName] = nil end
end

local function clearEscApiCache()
    clearApiCacheEntry(ESC and ESC.mspapi)
end

local function clearEscMaskCache()
    local ui = rfsuite.app and rfsuite.app.ui
    local cache = ui and ui._maskCache
    local order = ui and ui._maskCacheOrder
    if type(cache) ~= "table" then return end

    local prefix = "app/modules/esc_tools/tools/escmfg/"
    local removed = false
    for path in pairs(cache) do
        if type(path) == "string" and path:sub(1, #prefix) == prefix then
            cache[path] = nil
            removed = true
        end
    end
    if not removed or type(order) ~= "table" then return end

    local writeIdx = 1
    for i = 1, #order do
        local path = order[i]
        if cache[path] ~= nil then
            order[writeIdx] = path
            writeIdx = writeIdx + 1
        end
    end
    for i = writeIdx, #order do
        order[i] = nil
    end
end

local function resetEscReadRecovery()
    escReadRecoverRequested = false
    escReadRecoverAt = 0
    escReadRecoverCount = 0
end

local function clearEscState(preserveReadRecovery)
    clearEscSession()
    clearEscApiCache()
    resetUiState()
    escSwitchReadFlushPending = false
    if preserveReadRecovery ~= true then
        resetEscReadRecovery()
    end
end

local function scheduleEscReadRecovery()
    if not (ESC and ESC.retrySwitchOnReadFail == true) then return end
    if inSelector then return end
    local maxRetries = tonumber(ESC.readSwitchRetryCount) or 2
    if maxRetries < 1 then return end
    if escReadRecoverCount >= maxRetries then return end
    escReadRecoverCount = escReadRecoverCount + 1
    escReadRecoverRequested = true
    local delay = tonumber(ESC.readSwitchRetryDelay) or 0.25
    if delay < 0 then delay = 0 end
    escReadRecoverAt = os.clock() + delay
    if rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log("ESC 4WIF read retry re-arm #" .. tostring(escReadRecoverCount), "info")
    end
end

local mspBusy = false

local function getEscDetailsAPI()
    if not ESC or not ESC.mspapi then return nil end
    if escDetailsApi and escDetailsApiName == ESC.mspapi then
        return escDetailsApi
    end
    escDetailsApi = rfsuite.tasks.msp.api.load(ESC.mspapi)
    if escDetailsApi then
        escDetailsApiName = ESC.mspapi
    else
        escDetailsApiName = nil
    end
    return escDetailsApi
end

local function detachEscApiHandlers(api)
    if not api then return end
    if api.setCompleteHandler then pcall(api.setCompleteHandler, noop) end
    if api.setErrorHandler then pcall(api.setErrorHandler, noop) end
end

local function clearButtonMeta(meta)
    for k in pairs(meta) do
        meta[k] = nil
    end
end

local function clearButtonCache(meta, handlers)
    clearButtonMeta(meta)
    for k in pairs(handlers) do
        handlers[k] = nil
    end
end

local function onEscDetailsReadComplete(_, buf)
    if escSwitchReadFlushPending then
        escSwitchReadFlushPending = false
        clearEscSession()
        scheduleEscDetailsReadAt(0.2)
        mspBusy = false
        return
    end

    local API = escDetailsApi
    if not API then
        scheduleEscDetailsReadAt(getEscDetailsRetryInterval())
        mspBusy = false
        return
    end

    local signature = API.readValue("esc_signature")
    local valid = signature == mspSignature and #buf >= mspBytes

    if valid then
        escDetails.model = ESC.getEscModel(buf)
        escDetails.version = ESC.getEscVersion(buf)
        escDetails.firmware = ESC.getEscFirmware(buf)

        rfsuite.session.escDetails = escDetails

        if ESC.mspBufferCache == true then rfsuite.session.escBuffer = buf end

        if escDetails.model ~= nil then
            foundESC = true
            resetEscReadRecovery()
            escDetailsNextReadAt = 0
        end
    else
        scheduleEscDetailsReadAt(getEscDetailsRetryInterval())
        scheduleEscReadRecovery()
    end
    mspBusy = false
end

local function onEscDetailsReadError()
    scheduleEscDetailsReadAt(getEscDetailsRetryInterval())
    scheduleEscReadRecovery()
    mspBusy = false
end

local function fetchEscHeaderV2()
    if not escHeaderV2 or not escHeaderV2.isAvailable() or escHeaderV2.pending() or escHeaderV2.requested() or foundESC ~= true then
        return
    end

    escHeaderV2.fetch(function(data)
        if type(data.model) == "string" and data.model ~= "" then
            escDetails.model = data.model
        end
        if type(data.version) == "string" then
            escDetails.version = data.version
        end
        if type(data.firmware) == "string" then
            escDetails.firmware = data.firmware
        end

        rfsuite.session.escDetails = escDetails

        if foundESCupdateTag then
            updateEscHeaderText()
        end
    end)
end

local function installEscDetailsHandlers(api)
    if not api or escDetailsHandlersApi == api then return end
    api.setCompleteHandler(onEscDetailsReadComplete)
    api.setErrorHandler(onEscDetailsReadError)
    escDetailsHandlersApi = api
end

local function pressToolButton(childIdx)
    local meta = toolButtonMeta[childIdx]
    if not meta then return end

    rfsuite.preferences.menulastselected["esctool"] = childIdx
    rfsuite.app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.DEFAULT)

    local childOpts = {
        idx = childIdx,
        title = meta.childTitle,
        script = meta.script,
        returnContext = {
            idx = meta.parentIdx,
            title = meta.title,
            folder = meta.folder,
            script = "esc_tools/tools/esc_tool_4way.lua"
        }
    }

    if switchState then
        pendingChildOpen = childOpts
        renderLoading(meta.childTitle)
        return
    end
    if escReadReadyAt and os.clock() < escReadReadyAt then
        pendingChildOpen = childOpts
        renderLoading(meta.childTitle)
        return
    end
    if escSwitchReadFlushPending then
        pendingChildOpen = childOpts
        renderLoading(meta.childTitle)
        return
    end

    if rfsuite.session then
        rfsuite.session.esc4WaySkipEntrySwitchOnce = true
    end
    rfsuite.app.ui.openPage(childOpts)
end

local function getToolButtonHandler(childIdx)
    local handler = toolButtonHandlers[childIdx]
    if handler then return handler end
    handler = function()
        pressToolButton(childIdx)
    end
    toolButtonHandlers[childIdx] = handler
    return handler
end

local function getESCDetails()
    if not ESC then return end
    if not ESC.mspapi then return end
    if not mspSignature then return end
    if not mspBytes then return end
    if os.clock() < escDetailsNextReadAt then return end
    if mspBusy == true then
       if rfsuite.tasks.msp.mspQueue:isProcessed() then
           mspBusy = false
       end
       return
    end
    if not rfsuite.tasks.msp.mspQueue:isProcessed() then return end

    if rfsuite.session.escDetails ~= nil then
        escDetails = rfsuite.session.escDetails
        foundESC = true
        return
    end

    if foundESC == true then return end

    mspBusy = true

    local API = getEscDetailsAPI()
    if not API then
        mspBusy = false
        scheduleEscDetailsReadAt(getEscDetailsRetryInterval())
        return
    end
    installEscDetailsHandlers(API)

    API.setUUID("550e8400-e29b-41d4-a716-546a55340500")
    local ok = API.read()
    if ok then
        scheduleEscDetailsReadAt(getEscDetailsPollInterval())
    else
        mspBusy = false
        scheduleEscDetailsReadAt(getEscDetailsRetryInterval())
    end

end

local function ensureTailMode(callback)
    local helpers = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers
    if helpers and helpers.mixerConfig then
        waitingTailMode = true
        helpers.mixerConfig(function(tailMode)
            waitingTailMode = false
            pendingTailModeResolve = true
            if callback then callback(tailMode) end
        end)
        return
    end
    if callback then callback(rfsuite.session and rfsuite.session.tailMode or nil) end
end

local function isPostConnectComplete()
    return rfsuite.session and rfsuite.session.postConnectComplete == true
end

local function applySelectorButtonStates()
    if not inSelector then return end
    local fields = rfsuite.app and rfsuite.app.formFields
    if not fields then return end
    local ready = isPostConnectComplete() and selectorGuardOk == true
    local esc2Ready = ready and esc2Available == true
    local fieldEsc1 = fields[1]
    local fieldEsc2 = fields[2]
    if fieldEsc1 and fieldEsc1.enable and selectorButtonsReadyState ~= ready then
        fieldEsc1:enable(ready)
    end
    if fieldEsc2 and fieldEsc2.enable and selectorButtonsEsc2State ~= esc2Ready then
        fieldEsc2:enable(esc2Ready)
    end
    selectorButtonsReadyState = ready
    selectorButtonsEsc2State = esc2Ready
end

local function updateEsc2AvailabilityFromCount(count)
    local n = tonumber(count)
    if n == nil then return false end
    if rfsuite.session then rfsuite.session.esc4WayMotorCount = n end
    esc2Available = n >= 2
    return true
end

local function resolveEsc2AvailabilityFromSession()
    if rfsuite.session and updateEsc2AvailabilityFromCount(rfsuite.session.esc4WayMotorCount) then
        return true
    end
    return false
end

local function onEsc2AvailabilityComplete()
    esc2CheckPending = false
    local API = esc2CheckApi
    local count = API and API.readValue and API.readValue("motor_count_blheli")
    if not updateEsc2AvailabilityFromCount(count) then
        esc2Available = false
    end
    applySelectorButtonStates()
end

local function onEsc2AvailabilityError()
    esc2CheckPending = false
end

local function installEsc2AvailabilityHandlers(api)
    if not api or esc2CheckHandlersApi == api then return end
    api.setCompleteHandler(onEsc2AvailabilityComplete)
    api.setErrorHandler(onEsc2AvailabilityError)
    esc2CheckHandlersApi = api
end

local function requestEsc2AvailabilityCheck()
    if esc2Available ~= nil or esc2CheckPending then return end
    if not isPostConnectComplete() then return end
    if selectorGuardOk ~= true then return end
    local app = rfsuite.app
    if app and app.dialogs and app.dialogs.progressDisplay then return end
    local now = os.clock()
    if esc2CheckLastAttempt > 0 and (now - esc2CheckLastAttempt) < esc2CheckRetryDelay then return end
    esc2CheckLastAttempt = now

    if resolveEsc2AvailabilityFromSession() then
        applySelectorButtonStates()
        return
    end

    local mspApi = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if not (mspApi and mspApi.load) then return end
    local API = mspApi.load("MOTOR_CONFIG")
    if not API then return end

    esc2CheckApi = API
    installEsc2AvailabilityHandlers(API)
    esc2CheckPending = true
    if rfsuite.utils and rfsuite.utils.uuid then
        API.setUUID(rfsuite.utils.uuid())
    else
        API.setUUID(tostring(os.clock()))
    end
    local ok = API.read()
    if not ok then esc2CheckPending = false end
end

local function setESC4WayMode(id)
    local target = id
    if target == nil then target = 0 end
    writeSeq = writeSeq + 1
    local seq = writeSeq
    lastWriteSeq = seq
    last4WayWriteTarget = target
    last4WayWriteOk = nil
    if not escSwitchApi then
        escSwitchApi = rfsuite.tasks.msp.api.load("4WIF_ESC_FWD_PROG")
    end
    local API = escSwitchApi
    if not API then return false, "api_missing" end
    if rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log("ESC 4WIF set target: " .. tostring(target), "info")
    end
    rfsuite.session.esc4WayTarget = target
    rfsuite.session.esc4WaySetComplete = false
    API.setValue("target", target)
    API.setCompleteHandler(function(self, buf)
        if seq == lastWriteSeq then
            last4WayWriteOk = true
        end
        rfsuite.session.esc4WaySetComplete = true
    end)
    API.setErrorHandler(function(self, err)
        if seq == lastWriteSeq then
            last4WayWriteOk = false
        end
        rfsuite.session.esc4WaySetComplete = false
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ESC 4WIF set target: " .. tostring(target) .. " failed", "info")
        end
    end)
    if rfsuite.utils and rfsuite.utils.uuid then
        API.setUUID(rfsuite.utils.uuid())
    else
        API.setUUID(tostring(os.clock()))
    end
    return API.write()
end

local function beginEscSwitch(target, opts)
    if not lastOpts then return end
    opts = opts or {}
    local isRecovery = opts.isRecovery == true
    local preTarget = opts.preSwitchTarget
    if preTarget == nil and ESC then preTarget = ESC.preSwitchTarget end
    if preTarget ~= nil then
        local asNumber = tonumber(preTarget)
        if asNumber ~= nil then preTarget = asNumber end
    end
    local preWriteCount = tonumber(opts.preSwitchWriteCount)
    if preWriteCount == nil and ESC then preWriteCount = tonumber(ESC.preSwitchWriteCount) end
    if preWriteCount == nil then
        preWriteCount = (preTarget ~= nil) and 1 or 0
    end
    if preWriteCount < 0 then preWriteCount = 0 end
    preWriteCount = math.floor(preWriteCount)
    if preTarget == nil then preWriteCount = 0 end
    local preDelay = tonumber(opts.preSwitchDelay)
    if preDelay == nil and ESC then preDelay = tonumber(ESC.preSwitchDelay) end
    if preDelay == nil then preDelay = 0.6 end
    local readDelay = tonumber(opts.readDelay)
    if readDelay == nil and ESC then readDelay = tonumber(ESC.switchReadDelay) end
    if readDelay == nil then readDelay = 2 end
    local writeCount = tonumber(opts.switchWriteCount) or tonumber(ESC and ESC.switchWriteCount) or 1
    if writeCount < 1 then writeCount = 1 end
    writeCount = math.floor(writeCount)
    if switchState and switchState.target == target then return end
    if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.progressDisplay then
        rfsuite.app.ui.progressDisplay("@i18n(app.modules.esc_tools.name)@", "@i18n(app.msg_loading)@", rfsuite.app.loaderSpeed.VSLOW)
        switchLoadingActive = true
        rfsuite.app.triggers.closeProgressLoader = false
    end
    last4WayWriteOk = nil
    last4WayWriteTarget = nil
    escSwitchReadFlushPending = false
    escReadReadyAt = nil
    if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue then
        rfsuite.tasks.msp.mspQueue:clear()
    end
    switchState = {
        target = target,
        attempts = 0,
        maxAttempts = 10,
        lastAttempt = 0,
        retryDelay = 0.8,
        readDelay = readDelay,  -- Time to wait after setting esc target before attempting to read esc details, to allow fbl time to switch esc and respond to msp
        preSwitchTarget = preTarget,
        preSwitchWriteCount = preWriteCount,
        preSwitchWritesDone = 0,
        preSwitchDelay = preDelay,
        switchWriteCount = writeCount,
        switchWritesDone = 0,
        nextPhaseReadyAt = 0,
        writeInFlight = false,
        writeStartedAt = 0,
        writeTimeout = 2.5
    }
    rfsuite.session.esc4WaySelected = false
    rfsuite.session.esc4WaySet = false
    rfsuite.session.esc4WaySetComplete = false
    clearEscState(isRecovery)
    renderLoading(lastOpts.title or "")
end

local function pressSelectorButton(childIdx)
    local item = selectorButtonMeta[childIdx]
    if not item then return end
    if selectorGuardOk ~= true then return end
    if not isPostConnectComplete() then return end
    if item.target == item.esc2Target and esc2Available ~= true then return end
    inSelector = false
    rfsuite.preferences.menulastselected["esc4way"] = childIdx
    local loaderSpeed = ((rfsuite.app.loaderSpeed and rfsuite.app.loaderSpeed.VSLOW) or 0.5) * 0.15
    rfsuite.app.ui.progressDisplay(nil, nil, loaderSpeed)
    beginEscSwitch(item.target)
end

local function getSelectorButtonHandler(childIdx)
    local handler = selectorButtonHandlers[childIdx]
    if handler then return handler end
    handler = function()
        pressSelectorButton(childIdx)
    end
    selectorButtonHandlers[childIdx] = handler
    return handler
end

local function processEscSwitch()
    if not switchState then return false end
    local now = os.clock()
    local inPrePhase = switchState.preSwitchTarget ~= nil and switchState.preSwitchWritesDone < switchState.preSwitchWriteCount
    local expectedTarget = inPrePhase and switchState.preSwitchTarget or switchState.target

    local writeResult = nil
    if switchState.writeInFlight then
        if last4WayWriteTarget == expectedTarget and last4WayWriteOk ~= nil then
            writeResult = (last4WayWriteOk == true)
            last4WayWriteOk = nil
            switchState.writeInFlight = false
            switchState.writeStartedAt = 0
        elseif switchState.writeStartedAt > 0 and (now - switchState.writeStartedAt) >= switchState.writeTimeout then
            writeResult = false
            switchState.writeInFlight = false
            switchState.writeStartedAt = 0
        else
            return true
        end
    end

    if writeResult == true then
        if inPrePhase then
            switchState.preSwitchWritesDone = (switchState.preSwitchWritesDone or 0) + 1
            if switchState.preSwitchWritesDone < (switchState.preSwitchWriteCount or 0) then
                switchState.nextPhaseReadyAt = now + (switchState.retryDelay or 0.8)
                return true
            end
            switchState.attempts = 0
            switchState.lastAttempt = now
            switchState.nextPhaseReadyAt = now + (switchState.preSwitchDelay or 0.6)
            return true
        end
        switchState.switchWritesDone = (switchState.switchWritesDone or 0) + 1
        if switchState.switchWritesDone < (switchState.switchWriteCount or 1) then
            switchState.nextPhaseReadyAt = now + (switchState.retryDelay or 0.8)
            return true
        end
        rfsuite.session.esc4WayTarget = switchState.target
        rfsuite.session.esc4WaySelected = true
        rfsuite.session.esc4WaySet = true
        escSwitchReadFlushPending = (ESC and ESC.flushFirstReadAfterSwitch == true) and true or false
        escReadReadyAt = now + (switchState.readDelay or 2)
        switchState = nil
        renderToolPage(lastOpts)
        return true
    end

    if switchState.attempts >= switchState.maxAttempts then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ESC 4WIF set target failed after retries", "info")
        end
        switchState = nil
        if switchLoadingActive then
            switchLoadingActive = false
            rfsuite.app.triggers.closeProgressLoader = true
        end
        openSelector()
        return true
    end

    local phaseReady = (switchState.nextPhaseReadyAt == 0 or now >= switchState.nextPhaseReadyAt)
    if not switchState.writeInFlight and phaseReady and (switchState.lastAttempt == 0 or (now - switchState.lastAttempt) >= switchState.retryDelay) then
        inPrePhase = switchState.preSwitchTarget ~= nil and switchState.preSwitchWritesDone < switchState.preSwitchWriteCount
        expectedTarget = inPrePhase and switchState.preSwitchTarget or switchState.target
        switchState.attempts = switchState.attempts + 1
        switchState.lastAttempt = now
        rfsuite.session.esc4WaySet = true
        rfsuite.session.esc4WaySetComplete = false
        switchState.writeInFlight = true
        switchState.writeStartedAt = now
        setESC4WayMode(expectedTarget)
    end

    return true
end

local function getSelectedEsc4WayTarget()
    local target = tonumber(rfsuite.session and rfsuite.session.esc4WayTarget)
    local esc1Target, esc2Target = getEsc4WayTargets()
    if target == esc2Target then return esc2Target end
    if target == esc1Target then return esc1Target end
    return esc1Target
end

local function processEscReadRecovery()
    if not escReadRecoverRequested then return false end
    if inSelector then return false end
    if switchState then return false end
    if os.clock() < escReadRecoverAt then return false end
    escReadRecoverRequested = false
    beginEscSwitch(getSelectedEsc4WayTarget(), {
        isRecovery = true,
        preSwitchTarget = ESC and ESC.preSwitchTarget,
        preSwitchWriteCount = ESC and ESC.preSwitchWriteCount,
        preSwitchDelay = ESC and ESC.preSwitchDelay,
        switchWriteCount = ESC and ESC.switchWriteCount
    })
    return true
end

local function getButtonLayout()
    local buttonW
    local buttonH
    local padding
    local numPerRow

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    if rfsuite.preferences.general.iconsize == 1 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end

    if rfsuite.preferences.general.iconsize == 2 then
        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    return buttonW, buttonH, padding, numPerRow
end

local function loadEscConfig(folder)
    local initPath = escInitPathForFolder(folder)
    local chunk, err = loadfile(initPath)
    if not chunk then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ESC config load failed: " .. tostring(initPath) .. " (" .. tostring(err) .. ")", "info")
        end
        return false
    end
    local ok, moduleOrErr = pcall(chunk)
    if not ok or type(moduleOrErr) ~= "table" then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ESC config init failed: " .. tostring(initPath) .. " (" .. tostring(moduleOrErr) .. ")", "info")
        end
        return false
    end
    ESC = moduleOrErr
    escDetailsApi = nil
    escDetailsApiName = nil
    if not escHeaderV2 then
        escHeaderV2 = escMspV2.new()
    else
        escHeaderV2.reset()
    end
    findTimeout = getInitialConnectTimeout()

    if ESC.mspapi ~= nil then
        local API = getEscDetailsAPI()
        if not API then return false end
        mspSignature = API.mspSignature
        simulatorResponse = API.simulatorResponse or {0}
        mspBytes = #simulatorResponse
    else
        mspSignature = ESC.mspSignature
        simulatorResponse = ESC.simulatorResponse
        mspBytes = ESC.mspBytes
    end
    return true
end

renderLoading = function(title)
    form.clear()
    modelLine = nil
    modelText = nil
    rfsuite.app.ui.fieldHeader(title)
    local line = form.addLine("")
    form.addStaticText(line, nil, "@i18n(app.msg_loading)@")
    if not switchLoadingActive then
        rfsuite.app.triggers.closeProgressLoader = true
    end
end

renderToolPage = function(opts)
    if type(opts) ~= "table" then return end

    local parentIdx = opts.idx
    local title = opts.title
    local folder = opts.folder
    local script = opts.script
    inSelector = false

    rfsuite.app.lastIdx = parentIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    resetUiState()

    local app = rfsuite.app
    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end

    local y = rfsuite.app.radio.linePaddingTop

    form.clear()
    modelLine = nil
    modelText = nil

    local headerTitle = title
    if type(headerTitle) ~= "string" or headerTitle == "" then
        headerTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. ESC.toolName
    end
    rfsuite.app.ui.fieldHeader(headerTitle)

    ESC.pages = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/pages.lua"))()

    modelLine = form.addLine("")
    modelText = form.addStaticText(modelLine, modelTextPos, "")
    clearButtonMeta(toolButtonMeta)

    local buttonW, buttonH, padding, numPerRow = getButtonLayout()

    local lc = 0
    local bx = 0

    if rfsuite.app.gfx_buttons["esctool"] == nil then rfsuite.app.gfx_buttons["esctool"] = {} end
    if rfsuite.preferences.menulastselected["esctool"] == nil then rfsuite.preferences.menulastselected["esctool"] = 1 end

    for childIdx, pvalue in ipairs(ESC.pages) do

        local section = pvalue
        local hideSection = (section.ethosversion and rfsuite.session.ethosRunningVersion < section.ethosversion) or (section.mspversion and rfsuite.utils.apiVersionCompare("<", section.mspversion))

        if not pvalue.disablebutton or (pvalue and pvalue.disablebutton(mspBytes) == false) or not hideSection then

            if lc == 0 then
                if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
            end

            if lc >= 0 then bx = (buttonW + padding) * lc end

            if rfsuite.preferences.general.iconsize ~= 0 then
                if rfsuite.app.gfx_buttons["esctool"][pvalue.image] == nil then rfsuite.app.gfx_buttons["esctool"][pvalue.image] = loadMask("app/modules/esc_tools/tools/escmfg/" .. folder .. "/gfx/" .. pvalue.image) end
            else
                rfsuite.app.gfx_buttons["esctool"][pvalue.image] = nil
            end

            toolButtonMeta[childIdx] = {
                parentIdx = parentIdx,
                title = title,
                folder = folder,
                childTitle = title .. " / " .. pvalue.title,
                script = "esc_tools/tools/escmfg/" .. folder .. "/pages/" .. pvalue.script
            }

            rfsuite.app.formFields[childIdx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = pvalue.title,
                icon = rfsuite.app.gfx_buttons["esctool"][pvalue.image],
                options = FONT_S,
                paint = noop,
                press = getToolButtonHandler(childIdx)
            })

            if rfsuite.preferences.menulastselected["esctool"] == childIdx then rfsuite.app.formFields[childIdx]:focus() end

            if rfsuite.app.triggers.escToolEnableButtons == true then
                rfsuite.app.formFields[childIdx]:enable(true)
            else
                rfsuite.app.formFields[childIdx]:enable(false)
            end

            lc = lc + 1

            if lc == numPerRow then lc = 0 end
        end

    end

    rfsuite.app.triggers.escToolEnableButtons = false
end

openSelector = function()
    if not lastOpts then return end
    local parentIdx = lastOpts.idx
    local title = lastOpts.title
    local folder = lastOpts.folder
    local script = lastOpts.script
    local prevTarget = rfsuite.session and rfsuite.session.esc4WayTarget or nil

    inSelector = true
    selectorPostConnectReady = isPostConnectComplete()
    if switchLoadingActive then
        switchLoadingActive = false
        rfsuite.app.triggers.closeProgressLoader = true
    end
    rfsuite.session.esc4WaySelected = false
    rfsuite.session.esc4WaySet = nil
    rfsuite.session.esc4WaySetComplete = nil

    clearEscState()
    selectorGuardPending = false
    selectorGuardOk = nil
    selectorGuardNeedsReset = false
    selectorGuardStartedAt = 0
    selectorGuardRetryAt = 0
    selectorButtonsReadyState = nil
    selectorButtonsEsc2State = nil
    if ESC and ESC.skipSelectorGuardModeReset == true then
        selectorGuardOk = true
    else
        selectorGuardOk = false
        selectorGuardNeedsReset = true
    end

    rfsuite.app.lastIdx = parentIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    local app = rfsuite.app
    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end
    app.formFields = app.formFields or {}
    app.formLines = app.formLines or {}

    form.clear()
    modelLine = nil
    modelText = nil

    rfsuite.app.ui.fieldHeader(title)

    local buttonW, buttonH, padding, numPerRow = getButtonLayout()
    local esc1Target, esc2Target = getEsc4WayTargets()

    local items = {
        {title = "ESC1", image = "basic.png", target = esc1Target},
        {title = "ESC2", image = "advanced.png", target = esc2Target},
    }
    clearButtonMeta(selectorButtonMeta)
    if esc2Available == nil then
        resolveEsc2AvailabilityFromSession()
    end

    if rfsuite.app.gfx_buttons["esc4way"] == nil then rfsuite.app.gfx_buttons["esc4way"] = {} end
    if rfsuite.preferences.menulastselected["esc4way"] == nil then rfsuite.preferences.menulastselected["esc4way"] = 1 end
    if esc2Available ~= true and rfsuite.preferences.menulastselected["esc4way"] == 2 then
        rfsuite.preferences.menulastselected["esc4way"] = 1
    end

    local lc = 0
    local bx = 0
    local y = 0

    for childIdx, item in ipairs(items) do

        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.preferences.general.iconsize ~= 0 then
            if rfsuite.app.gfx_buttons["esc4way"][childIdx] == nil then
                rfsuite.app.gfx_buttons["esc4way"][childIdx] = loadMask("app/modules/esc_tools/tools/escmfg/" .. folder .. "/gfx/" .. item.image)
            end
        else
            rfsuite.app.gfx_buttons["esc4way"][childIdx] = nil
        end

        selectorButtonMeta[childIdx] = {
            target = item.target,
            esc2Target = esc2Target
        }

        rfsuite.app.formFields[childIdx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = item.title,
            icon = rfsuite.app.gfx_buttons["esc4way"][childIdx],
            options = FONT_S,
            paint = noop,
            press = getSelectorButtonHandler(childIdx)
        })

        if rfsuite.preferences.menulastselected["esc4way"] == childIdx then rfsuite.app.formFields[childIdx]:focus() end

        lc = lc + 1
        if lc == numPerRow then lc = 0 end
    end

    applySelectorButtonStates()
    requestEsc2AvailabilityCheck()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function openPage(opts)

    local parentIdx = opts.idx
    local title = opts.title
    local folder = opts.folder
    local script = opts.script

    folder = resolveEscFolder(folder, title)
    if not folder then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ESC folder resolution failed for title: " .. tostring(title), "info")
        end
        rfsuite.app.triggers.closeProgressLoader = true
        return
    end

    lastOpts = {idx = parentIdx, title = title, folder = folder, script = script}

    rfsuite.app.lastIdx = parentIdx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    if not loadEscConfig(folder) then
        rfsuite.app.triggers.closeProgressLoader = true
        return
    end

    local skipEntrySwitchOnce = false
    if rfsuite.session and rfsuite.session.esc4WaySkipEntrySwitchOnce == true then
        skipEntrySwitchOnce = true
    end
    if rfsuite.session then
        rfsuite.session.esc4WaySkipEntrySwitchOnce = nil
    end

    if not rfsuite.session.esc4WaySelected then
        openSelector()
        return
    end
    if ESC.force4WaySwitchOnEntry == true and not skipEntrySwitchOnce then
        beginEscSwitch(getSelectedEsc4WayTarget(), {
            switchWriteCount = ESC.switchWriteCount
        })
        return
    end

    renderToolPage(lastOpts)
end

local function onNavMenu()
    if rfsuite.session then
        rfsuite.session.esc4WaySkipEntrySwitchOnce = nil
    end
    if ESC then
        if not inSelector then
            rfsuite.session.esc4WaySelected = nil
            rfsuite.session.esc4WaySet = nil
            rfsuite.session.esc4WaySetComplete = nil
            rfsuite.session.esc4WayTarget = nil
            openSelector()
            return true
        end
        rfsuite.session.esc4WaySelected = nil
        rfsuite.session.esc4WaySet = nil
        rfsuite.session.esc4WaySetComplete = nil
        rfsuite.session.esc4WayTarget = nil
        clearEscSession()
    end
    pageRuntime.openMenuContext({defaultSection = "system"})
    return true
end

local function closePage()
    local keepEscSessionHot = rfsuite.session and rfsuite.session.esc4WaySkipEntrySwitchOnce == true

    if switchLoadingActive then
        switchLoadingActive = false
        if rfsuite.app and rfsuite.app.triggers then
            rfsuite.app.triggers.closeProgressLoader = true
        end
    end

    if rfsuite.app and rfsuite.app.gfx_buttons then
        rfsuite.app.gfx_buttons["esctool"] = nil
        rfsuite.app.gfx_buttons["esc4way"] = nil
    end

    detachEscApiHandlers(escSwitchApi)
    detachEscApiHandlers(escDetailsApi)
    detachEscApiHandlers(esc2CheckApi)
    clearEscQueueEntries(ESC and ESC.mspapi)
    clearEscQueueEntries("ESC_NAME")
    clearEscQueueEntries("ESC_DETAILS")
    clearEscQueueEntries("4WIF_ESC_FWD_PROG")
    clearEscQueueEntries("MOTOR_CONFIG")
    clearApiCacheEntry("ESC_NAME")
    clearApiCacheEntry("ESC_DETAILS")
    clearApiCacheEntry("4WIF_ESC_FWD_PROG")
    clearApiCacheEntry("MOTOR_CONFIG")

    waitingTailMode = false
    pendingTailModeResolve = false
    inSelector = false
    lastOpts = nil
    pendingChildOpen = nil
    switchState = nil
    escReadReadyAt = nil
    selectorPostConnectReady = nil
    selectorGuardPending = false
    selectorGuardOk = nil
    selectorGuardNeedsReset = false
    selectorGuardStartedAt = 0
    selectorGuardRetryAt = 0
    selectorButtonsReadyState = nil
    selectorButtonsEsc2State = nil
    esc2CheckPending = false
    esc2CheckLastAttempt = 0
    esc2Available = nil

    mspBusy = false
    mspSignature = nil
    mspBytes = nil
    simulatorResponse = nil
    escDetailsApi = nil
    escDetailsApiName = nil
    escDetailsHandlersApi = nil
    if escHeaderV2 then
        escHeaderV2.reset()
    end
    escSwitchApi = nil
    esc2CheckApi = nil
    esc2CheckHandlersApi = nil
    ESC = nil
    findTimeout = findTimeoutDefault
    modelLine = nil
    modelText = nil
    last4WayWriteTarget = nil
    last4WayWriteOk = nil
    writeSeq = 0
    lastWriteSeq = 0
    clearButtonCache(toolButtonMeta, toolButtonHandlers)
    clearButtonCache(selectorButtonMeta, selectorButtonHandlers)

    if keepEscSessionHot then
        resetUiState()
        resetEscReadRecovery()
    else
        clearEscState()
        clearEscMaskCache()
    end
end

local function onReloadMenu()
    closePage()
    rfsuite.app.Page = nil
    if rfsuite.session then
        rfsuite.session.esc4WaySkipEntrySwitchOnce = nil
        rfsuite.session.esc4WayTarget = nil
        rfsuite.session.esc4WayMotorCount = nil
        rfsuite.session.esc4WaySelected = nil
        rfsuite.session.esc4WaySet = nil
        rfsuite.session.esc4WaySetComplete = nil
    end
    rfsuite.app.triggers.triggerReloadFull = true
    return true
end

local function wakeup()

    if processEscSwitch() then return end
    if processEscReadRecovery() then return end
    if inSelector then
        if selectorGuardNeedsReset and not selectorGuardPending then
            local now = os.clock()
            if selectorGuardRetryAt > 0 and now < selectorGuardRetryAt then
                applySelectorButtonStates()
                return
            end
            selectorGuardNeedsReset = false
            local modeResetRequested = setESC4WayMode(100)
            if modeResetRequested then
                selectorGuardPending = true
                selectorGuardStartedAt = now
            else
                selectorGuardOk = false
                scheduleSelectorGuardRetry("enqueue_failed")
            end
            applySelectorButtonStates()
        end
        if selectorGuardPending then
            local now = os.clock()
            if last4WayWriteTarget == 100 and last4WayWriteOk ~= nil then
                selectorGuardOk = (last4WayWriteOk == true)
                selectorGuardPending = false
                selectorGuardStartedAt = 0
                if selectorGuardOk == true then
                    selectorGuardRetryAt = 0
                else
                    scheduleSelectorGuardRetry("write_failed")
                end
                last4WayWriteOk = nil
                applySelectorButtonStates()
            elseif selectorGuardStartedAt > 0 and (now - selectorGuardStartedAt) >= selectorGuardTimeout then
                selectorGuardOk = false
                selectorGuardPending = false
                selectorGuardStartedAt = 0
                scheduleSelectorGuardRetry("timeout")
                applySelectorButtonStates()
            end
        end
        local postConnectReady = isPostConnectComplete()
        if selectorPostConnectReady ~= postConnectReady then
            selectorPostConnectReady = postConnectReady
            applySelectorButtonStates()
        end
        if postConnectReady and selectorGuardOk == true and esc2Available == nil then
            requestEsc2AvailabilityCheck()
        end
    end

    if pendingChildOpen then
        if (not switchState) and (not escReadReadyAt or os.clock() >= escReadReadyAt) and not escSwitchReadFlushPending then
            local opts = pendingChildOpen
            pendingChildOpen = nil
            if rfsuite.session then
                rfsuite.session.esc4WaySkipEntrySwitchOnce = true
            end
            rfsuite.app.ui.openPage(opts)
            return
        end
    end

    if pendingTailModeResolve then
        pendingTailModeResolve = false
        if not rfsuite.session.esc4WaySelected then
            if not inSelector then openSelector() end
            return
        end
        renderToolPage(lastOpts)
        return
    end

    if waitingTailMode then return end

    if foundESC == false then
        if not rfsuite.session.esc4WaySelected then
            if not inSelector then openSelector() end
            return
        end
        if rfsuite.session.esc4WaySet == true and rfsuite.session.esc4WaySetComplete == true then
            if escReadReadyAt and os.clock() < escReadReadyAt then return end
            getESCDetails()
        end
    end

    if foundESC == true then
        fetchEscHeaderV2()
    end

    if foundESC == true and foundESCupdateTag == false then
        local compatible = true
        if ESC and type(ESC.isCompatibleEsc) == "function" then
            compatible = (ESC.isCompatibleEsc(rfsuite.session and rfsuite.session.escBuffer or nil, escDetailsApi) == true)
        end

        if not compatible then
            foundESCupdateTag = true
            rfsuite.app.triggers.closeProgressLoader = true
            setModelHeaderText("@i18n(app.modules.esc_tools.unknown)@")
            return
        end

        foundESCupdateTag = true

        updateEscHeaderText()

        for i, v in ipairs(rfsuite.app.formFields) do rfsuite.app.formFields[i]:enable(true) end

        if switchLoadingActive then
            switchLoadingActive = false
        end
        rfsuite.app.triggers.closeProgressLoader = true

    end

    local progressTimedOut = false
    if rfsuite.app and rfsuite.app.dialogs and rfsuite.app.dialogs.progressDisplay == true then
        progressTimedOut = (rfsuite.app.dialogs.progressCounter or 0) >= 101
    end

    if foundESCupdateTag == false and ((findTimeoutClock <= os.clock() - findTimeout) or progressTimedOut) then
        local dialogs = rfsuite.app and rfsuite.app.dialogs
        if dialogs then
            if dialogs.progress and dialogs.progress.close then
                dialogs.progress:close()
            end
            dialogs.progress = nil
            dialogs.progressDisplay = false
        end
        rfsuite.app.triggers.isReady = true

        setModelHeaderText("@i18n(app.modules.esc_tools.unknown)@")
    end

end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = function()
        onNavMenu()
    end})

end

return {
    openPage = openPage,
    wakeup = wakeup,
    event = event,
    close = closePage,
    onNavMenu = onNavMenu,
    onReloadMenu = onReloadMenu,
    navButtons = {menu = true, save = false, reload = true, tool = false, help = false},
    API = {}
}
