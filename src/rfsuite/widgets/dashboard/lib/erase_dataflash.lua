--[[
  Dataflash erase helper for dashboard
]] --

local M = {}

local function openProgressDialog(rfsuite, ...)
    if rfsuite.utils.ethosVersionAtLeast({1, 7, 0}) and form.openWaitDialog then
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

local function updateProgressMessage(dashboard, rfsuite)
    if not dashboard._eraseProgress or not dashboard._eraseProgressBaseMessage then return end
    local showMsp = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.mspstatusdialog
    local mspStatus = (showMsp and rfsuite.session and rfsuite.session.mspStatusMessage) or nil
    if showMsp then
        local msg = mspStatus or "MSP Waiting"
        if msg ~= dashboard._eraseProgressMspStatusLast then
            dashboard._eraseProgress:message(msg)
            dashboard._eraseProgressMspStatusLast = msg
        end
    else
        if dashboard._eraseProgressMspStatusLast ~= nil then
            dashboard._eraseProgress:message(dashboard._eraseProgressBaseMessage)
            dashboard._eraseProgressMspStatusLast = nil
        end
    end
end

local function doErase(dashboard, rfsuite)
    if not (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue) then return end
    logInfo("Dataflash erase: queue MSP erase command")
    dashboard._eraseProgress = openProgressDialog(rfsuite, "@i18n(app.msg_saving)@", "@i18n(app.msg_saving_to_fbl)@")
    dashboard._eraseProgress:value(0)
    dashboard._eraseProgress:closeAllowed(false)
    dashboard._eraseProgressCounter = 0
    dashboard._eraseProgressBaseMessage = "@i18n(app.msg_saving_to_fbl)@"
    dashboard._eraseProgressMspStatusLast = nil
    rfsuite.app.ui.registerProgressDialog(dashboard._eraseProgress, dashboard._eraseProgressBaseMessage)

    local function readDataflashSummary()
        if not (rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.load) then return end
        local API = rfsuite.tasks.msp.api.load("DATAFLASH_SUMMARY")
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
            if dashboard._eraseProgress then
                dashboard._eraseProgress:close()
                rfsuite.app.ui.clearProgressDialog(dashboard._eraseProgress)
            end
            dashboard._eraseProgress = nil
            dashboard._eraseProgressBaseMessage = nil
            dashboard._eraseProgressMspStatusLast = nil
            dashboard._eraseProgressCounter = nil
            readDataflashSummary()
        end
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

function M.ask(dashboard, rfsuite)
    local buttons = {
        {label = "@i18n(app.btn_ok)@", action = function() doErase(dashboard, rfsuite); return true end},
        {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }
    form.openDialog({title = "@i18n(widgets.bbl.erase_dataflash)@", message = "@i18n(widgets.bbl.erase_dataflash)@" .. "?", buttons = buttons, options = TEXT_LEFT})
end

function M.wakeup(dashboard, rfsuite)
    if not dashboard._eraseProgress then return end
    updateProgressMessage(dashboard, rfsuite)
    dashboard._eraseProgressCounter = (dashboard._eraseProgressCounter or 0) + 20
    dashboard._eraseProgress:value(dashboard._eraseProgressCounter)
    if dashboard._eraseProgressCounter >= 100 then
        dashboard._eraseProgress:close()
        rfsuite.app.ui.clearProgressDialog(dashboard._eraseProgress)
        dashboard._eraseProgress = nil
        dashboard._eraseProgressBaseMessage = nil
        dashboard._eraseProgressMspStatusLast = nil
        dashboard._eraseProgressCounter = nil
    end
end

return M
