--[[
  Toolbar action: erase blackbox / dataflash
]] --

local rfsuite = require("rfsuite")
local M = {}

local function openProgressDialog(...)
    if rfsuite.utils.ethosVersionAtLeast({26, 1, 0}) and form.openWaitDialog then
        local arg1 = select(1, ...)
        if type(arg1) == "table" then
            arg1.progress = true
            return form.openWaitDialog(arg1)
        end
        local title = arg1
        local message = select(2, ...)
        return form.openWaitDialog({title = title, message = message, progress = true})
    end
    return form.openProgressDialog(...)
end

local function logInfo(msg)
    if rfsuite and rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log(msg, "info")
    end
end

local eraseProgress
local eraseProgressBaseMessage
local eraseProgressMspStatusLast
local eraseProgressCounter
local eraseProgressStart

local function updateProgressMessage()
    if not eraseProgress or not eraseProgressBaseMessage then return end
    local showMsp = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.mspstatusdialog
    local mspStatus = (showMsp and rfsuite.session and rfsuite.session.mspStatusMessage) or nil
    if showMsp then
        local msg = mspStatus or "MSP Waiting"
        if msg ~= eraseProgressMspStatusLast then
            eraseProgress:message(msg)
            eraseProgressMspStatusLast = msg
        end
    else
        if eraseProgressMspStatusLast ~= nil then
            eraseProgress:message(eraseProgressBaseMessage)
            eraseProgressMspStatusLast = nil
        end
    end
end

local function doErase()
    if not (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue) then
        logInfo("Dataflash erase: MSP queue not available")
        return
    end
    logInfo("Dataflash erase: queue MSP erase command")
    eraseProgress = openProgressDialog("@i18n(app.msg_saving)@", "@i18n(app.msg_saving_to_fbl)@")
    eraseProgress:value(0)
    eraseProgress:closeAllowed(false)
    eraseProgressCounter = 0
    eraseProgressStart = os.clock()
    eraseProgressBaseMessage = "@i18n(app.msg_saving_to_fbl)@"
    eraseProgressMspStatusLast = nil
    local function readDataflashSummary()
        if not (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.load) then return end
        local API = rfsuite.tasks.msp.api.load("DATAFLASH_SUMMARY")
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        if not API then return end
        API.setCompleteHandler(function()
            local total = API.readValue("total")
            local used = API.readValue("used")
            local flags = API.readValue("flags")
            if total ~= nil then rfsuite.session.bblSize = total end
            if used ~= nil then rfsuite.session.bblUsed = used end
            if flags ~= nil then rfsuite.session.bblFlags = flags end
            logInfo(string.format("Dataflash summary: total=%s used=%s flags=%s", tostring(total), tostring(used), tostring(flags)))
        end)
        API.read()
    end

    local message = {
        command = 72,
        processReply = function()
            logInfo("Dataflash erase: MSP erase reply received")
            if eraseProgress then
                eraseProgress:close()
            end
            eraseProgress = nil
            eraseProgressBaseMessage = nil
            eraseProgressMspStatusLast = nil
            eraseProgressCounter = nil
            readDataflashSummary()
        end
    }
    local ok, reason = rfsuite.tasks.msp.mspQueue:add(message)
    if ok == false then
        logInfo("Dataflash erase: MSP queue rejected message (" .. tostring(reason) .. ")")
    end
end

function M.eraseBlackboxAsk()
    local buttons = {
        {label = "@i18n(app.btn_ok)@", action = function() doErase(); return true end},
        {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }
    form.openDialog({title = "@i18n(widgets.bbl.erase_dataflash)@", message = "@i18n(widgets.bbl.erase_dataflash)@" .. "?", buttons = buttons, options = TEXT_LEFT})
end

function M.wakeup()
    if not eraseProgress then return end
    updateProgressMessage()
    local start = eraseProgressStart or os.clock()
    local elapsed = os.clock() - start
    local pct = math.min(100, math.floor((elapsed / 5.0) * 100))
    eraseProgressCounter = pct
    eraseProgress:value(pct)
    if pct >= 100 then
        eraseProgress:close()
        eraseProgress = nil
        eraseProgressBaseMessage = nil
        eraseProgressMspStatusLast = nil
        eraseProgressCounter = nil
        eraseProgressStart = nil
    end
end

function M.reset()
    if eraseProgress then
        eraseProgress:close()
    end
    eraseProgress = nil
    eraseProgressBaseMessage = nil
    eraseProgressMspStatusLast = nil
    eraseProgressCounter = nil
    eraseProgressStart = nil
end

return M
