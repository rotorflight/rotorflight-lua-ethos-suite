--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
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
local findTimeout = math.floor(rfsuite.tasks.msp.protocol.pageReqTimeout * 0.5)

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
local writeSeq = 0
local lastWriteSeq = 0
local last4WayWriteTarget
local last4WayWriteOk
local escReadRecoverRequested = false
local escReadRecoverAt = 0
local escReadRecoverCount = 0
local escDetailsNextReadAt = 0
local escDetailsApiName
local escDetailsApi
local escSwitchApi

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

local function resetEscReadRecovery()
    escReadRecoverRequested = false
    escReadRecoverAt = 0
    escReadRecoverCount = 0
end

local function clearEscState(preserveReadRecovery)
    clearEscSession()
    resetUiState()
    if preserveReadRecovery ~= true then
        resetEscReadRecovery()
    end
end

local function scheduleEscReadRecovery()
    if not (ESC and ESC.esc4way and ESC.retrySwitchOnReadFail == true) then return end
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
    API.setCompleteHandler(function(self, buf)

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

    end)

    API.setErrorHandler(function(self, err)
        scheduleEscDetailsReadAt(getEscDetailsRetryInterval())
        scheduleEscReadRecovery()
        mspBusy = false
    end)

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
    local fieldEsc1 = fields[1]
    local fieldEsc2 = fields[2]
    if fieldEsc1 and fieldEsc1.enable then
        fieldEsc1:enable(ready)
    end
    if fieldEsc2 and fieldEsc2.enable then
        fieldEsc2:enable(ready and esc2Available == true)
    end
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

    esc2CheckPending = true
    API.setCompleteHandler(function(self, buf)
        esc2CheckPending = false
        local count = API.readValue("motor_count_blheli")
        if not updateEsc2AvailabilityFromCount(count) then
            esc2Available = false
        end
        applySelectorButtonStates()
    end)
    API.setErrorHandler(function(self, err)
        esc2CheckPending = false
    end)
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
    if target ~= 1 then target = 0 end
    return target
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

            rfsuite.app.formFields[childIdx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = pvalue.title,
                icon = rfsuite.app.gfx_buttons["esctool"][pvalue.image],
                options = FONT_S,
                paint = function() end,
                press = function()
                    rfsuite.preferences.menulastselected["esctool"] = childIdx
                    rfsuite.app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.DEFAULT)
                    local childTitle = title .. " / " .. pvalue.title

                    local childOpts = {
                        idx = childIdx,
                        title = childTitle,
                        script = "esc_tools/tools/escmfg/" .. folder .. "/pages/" .. pvalue.script,
                        returnContext = {
                            idx = parentIdx,
                            title = title,
                            folder = folder,
                            script = "esc_tools/tools/esc_tool_4way.lua"
                        }
                    }

                    if switchState then
                        pendingChildOpen = childOpts
                        renderLoading(childTitle)
                        return
                    end
                    if escReadReadyAt and os.clock() < escReadReadyAt then
                        pendingChildOpen = childOpts
                        renderLoading(childTitle)
                        return
                    end

                    if rfsuite.session then
                        rfsuite.session.esc4WaySkipEntrySwitchOnce = true
                    end
                    rfsuite.app.ui.openPage(childOpts)

                end
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

    local items = {
        {title = "ESC1", image = "basic.png", target = 0},
        {title = "ESC2", image = "advanced.png", target = 1},
    }
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

        rfsuite.app.formFields[childIdx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = item.title,
            icon = rfsuite.app.gfx_buttons["esc4way"][childIdx],
            options = FONT_S,
            paint = function() end,
            press = function()
                if selectorGuardOk ~= true then return end
                if not isPostConnectComplete() then return end
                if item.target == 1 and esc2Available ~= true then return end
                inSelector = false
                rfsuite.preferences.menulastselected["esc4way"] = childIdx
                local loaderSpeed = ((rfsuite.app.loaderSpeed and rfsuite.app.loaderSpeed.VSLOW) or 0.5) * 0.25
                rfsuite.app.ui.progressDisplay(nil, nil, loaderSpeed)
                beginEscSwitch(item.target)
                return
            end
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

    if ESC and ESC.esc4way then
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
    end

    renderToolPage(lastOpts)
end

local function onNavMenu()
    if rfsuite.session then
        rfsuite.session.esc4WaySkipEntrySwitchOnce = nil
    end
    if ESC and ESC.esc4way then
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
    end
    pageRuntime.openMenuContext({defaultSection = "system"})
    return true
end

local function onReloadMenu()
    rfsuite.app.Page = nil
    resetUiState()
    if rfsuite.session then
        rfsuite.session.esc4WaySkipEntrySwitchOnce = nil
    end
    rfsuite.session.esc4WaySelected = nil
    rfsuite.session.esc4WaySet = nil
    rfsuite.session.esc4WaySetComplete = nil
    rfsuite.app.triggers.triggerReloadFull = true
    return true
end

local function wakeup()

    if processEscSwitch() then return end
    if processEscReadRecovery() then return end
    if inSelector then
        if selectorGuardNeedsReset and not selectorGuardPending then
            selectorGuardNeedsReset = false
            local modeResetRequested = setESC4WayMode(100)
            if modeResetRequested then
                selectorGuardPending = true
                selectorGuardStartedAt = os.clock()
            else
                selectorGuardOk = false
            end
            applySelectorButtonStates()
        end
        if selectorGuardPending then
            local now = os.clock()
            if last4WayWriteTarget == 100 and last4WayWriteOk ~= nil then
                selectorGuardOk = (last4WayWriteOk == true)
                selectorGuardPending = false
                selectorGuardStartedAt = 0
                last4WayWriteOk = nil
                applySelectorButtonStates()
            elseif selectorGuardStartedAt > 0 and (now - selectorGuardStartedAt) >= selectorGuardTimeout then
                selectorGuardOk = false
                selectorGuardPending = false
                selectorGuardStartedAt = 0
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
        if (not switchState) and (not escReadReadyAt or os.clock() >= escReadReadyAt) then
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
        if ESC and ESC.esc4way and not rfsuite.session.esc4WaySelected then
            if not inSelector then openSelector() end
            return
        end
        renderToolPage(lastOpts)
        return
    end

    if waitingTailMode then return end

    if foundESC == false then
        if ESC and ESC.esc4way then
            if not rfsuite.session.esc4WaySelected then
                if not inSelector then openSelector() end
                return
            end
            if rfsuite.session.esc4WaySet == true and rfsuite.session.esc4WaySetComplete == true then
                if escReadReadyAt and os.clock() < escReadReadyAt then return end
                getESCDetails()
            end
        else
            getESCDetails()
        end
    end

    if foundESC == true and foundESCupdateTag == false then
        foundESCupdateTag = true

        if escDetails.model ~= nil and escDetails.model ~= nil and escDetails.firmware ~= nil then
            local prefix = ""
            if ESC and ESC.esc4way then
                local target = rfsuite.session and rfsuite.session.esc4WayTarget or 0
                if target == 1 then
                    prefix = "ESC2 - "
                else
                    prefix = "ESC1 - "
                end
            end
            local text = prefix .. escDetails.model .. " " .. escDetails.version .. " " .. escDetails.firmware
            rfsuite.escHeaderLineText = text
            setModelHeaderText(text)
        end

        for i, v in ipairs(rfsuite.app.formFields) do rfsuite.app.formFields[i]:enable(true) end

        if switchLoadingActive then
            switchLoadingActive = false
        end
        rfsuite.app.triggers.closeProgressLoader = true

    end

    if foundESCupdateTag == false and ((findTimeoutClock <= os.clock() - findTimeout) or rfsuite.app.dialogs.progressCounter >= 101) then
        rfsuite.app.dialogs.progress:close()
        rfsuite.app.dialogs.progressDisplay = false
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
    onNavMenu = onNavMenu,
    onReloadMenu = onReloadMenu,
    navButtons = {menu = true, save = false, reload = true, tool = false, help = false},
    API = {}
}
