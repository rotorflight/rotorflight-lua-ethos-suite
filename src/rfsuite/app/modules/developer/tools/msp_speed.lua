--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd
local app = rfsuite.app
local tasks = rfsuite.tasks
local rfutils = rfsuite.utils
local session = rfsuite.session

local line = {}
local fields = {}

local formLoaded = false
local startTestTime = os.clock()
local startTestLength = 0

local testLoader = nil
local testLoaderBaseMessage
local testLoaderMspStatusLast
local function openProgressDialog(...)
    if rfutils.ethosVersionAtLeast({1, 7, 0}) and form.openWaitDialog then
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

local mspQueryStartTime
local mspQueryTimeCount = 0
local getMSPCount = 0
local doNextMsp = true

local mspSpeedTestStats
local pageIdx

local maxQueryTime = 0
local minQueryTime = 1000

local function resetStats()
    getMSPCount = 0
    mspQueryTimeCount = 0

    mspSpeedTestStats = {total = 0, success = 0, retries = 0, timeouts = 0, checksum = 0}
end

resetStats()

local RateLimit = os.clock()
local Rate = 0.25

local function updateTestLoaderMessage()
    if not testLoader or not testLoaderBaseMessage then return end
    if app and app.ui and app.ui.updateProgressDialogMessage then
        app.ui.updateProgressDialogMessage()
    end
end

local function getMSPBattery()
    local API = tasks.msp.api.load("BATTERY_CONFIG")
    API.setCompleteHandler(function(self, buf) doNextMsp = true end)
    API.setUUID("a3f9c2b4-5d7e-4e8a-9c3b-2f6d8e7a1b2d")
    API.read()
end

local function getMSPGovernor()
    local API = tasks.msp.api.load("GOVERNOR_CONFIG")
    API.setCompleteHandler(function(self, buf) doNextMsp = true end)
    API.setUUID("e2a1c5b3-7f4a-4c8e-9d2a-3b6f8e2d9a1c")
    API.read()
end

local function getMSPMixer()
    local API = tasks.msp.api.load("MIXER_CONFIG")
    API.setCompleteHandler(function(self, buf) doNextMsp = true end)
    API.setUUID("fbccd634-c9b7-4b48-8c02-08ef560dc515")
    API.read()
end

local function getMSP()

    if getMSPCount == 0 then
        getMSPBattery()
        getMSPCount = 1
    elseif getMSPCount == 1 then
        getMSPGovernor()
        getMSPCount = 2
    else
        getMSPMixer()
        getMSPCount = 0
    end

    local avgQueryTime = rfutils.round(mspQueryTimeCount / mspSpeedTestStats['total'], 2) .. "s"

end

local function updateStats()

    fields['runtime']:value(startTestLength)

    fields['total']:value(tostring(mspSpeedTestStats['total']))

    fields['retries']:value(tostring(mspSpeedTestStats['retries']))

    fields['timeouts']:value(tostring(mspSpeedTestStats['timeouts']))

    fields['checksum']:value(tostring(mspSpeedTestStats['checksum']))

    fields['mintime']:value(tostring(minQueryTime) .. "s")
    fields['maxtime']:value(tostring(maxQueryTime) .. "s")

    if (mspSpeedTestStats['success'] == mspSpeedTestStats['total'] - 1) and mspSpeedTestStats['timeouts'] == 0 then
        fields['success']:value(tostring(mspSpeedTestStats['success']))
    else
        fields['success']:value(tostring(mspSpeedTestStats['success']))
    end

    local avgQueryTime = rfutils.round(mspQueryTimeCount / mspSpeedTestStats['total'], 2) .. "s"
    fields['time']:value(tostring(avgQueryTime))

end

local function startTest(duration)
    startTestLength = duration
    startTestTime = os.clock()

    testLoader = openProgressDialog({
        title = "@i18n(app.modules.msp_speed.testing)@",
        message = "@i18n(app.modules.msp_speed.testing_performance)@",
        close = function()
            updateStats()
            testLoader = nil
            testLoaderBaseMessage = nil
            testLoaderMspStatusLast = nil
            app.ui.clearProgressDialog(testLoader)
        end,
        wakeup = function()
            local now = os.clock()

            if session.telemetryState == false and startTest == true and system:getVersion().simulation ~= true then
                if testLoader then
                    testLoader:close()
                    testLoader = nil
                end
            end

            if formLoaded == true then
                app.triggers.closeProgressLoader = true
                formLoaded = false
            end

            testLoader:value((now - startTestTime) * 100 / startTestLength)
            updateTestLoaderMessage()

            if (now - startTestLength) > startTestTime then
                testLoader:close()
                app.ui.clearProgressDialog(testLoader)
                testLoader = nil
                updateStats()
            end

            if tasks.msp.mspQueue:isProcessed() and ((now - RateLimit) >= Rate) then
                RateLimit = now
                mspSpeedTestStats['total'] = mspSpeedTestStats['total'] + 1
                mspQueryStartTime = os.clock()

                if doNextMsp == true then
                    doNextMsp = false
                    getMSP()
                end
            end
        end
    })

    testLoader:value(0)
    testLoaderBaseMessage = "@i18n(app.modules.msp_speed.testing_performance)@"
    testLoaderMspStatusLast = nil
    updateTestLoaderMessage()
    app.ui.registerProgressDialog(testLoader, testLoaderBaseMessage)

    resetStats()

    doNextMsp = true
end

local function openSpeedTestDialog()
    local buttons = {
        {
            label = "@i18n(app.modules.msp_speed.seconds_600)@",
            action = function()
                startTest(600)
                return true
            end
        }, {
            label = "@i18n(app.modules.msp_speed.seconds_300)@",
            action = function()
                startTest(300)
                return true
            end
        }, {
            label = "@i18n(app.modules.msp_speed.seconds_120)@",
            action = function()
                startTest(120)
                return true
            end
        }, {
            label = "@i18n(app.modules.msp_speed.seconds_30)@",
            action = function()
                startTest(30)
                return true
            end
        }
    }
    form.openDialog({title = "@i18n(app.modules.msp_speed.start)@", message = "@i18n(app.modules.msp_speed.start_prompt)@", buttons = buttons, options = TEXT_LEFT})
end

local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script
    pageIdx = pidx
    app.lastIdx = pidx
    app.lastTitle = title
    app.lastScript = script
    app.triggers.closeProgressLoader = true

    local w, h = lcd.getWindowSize()

    form.clear()

    app.ui.fieldHeader("Developer / " .. "@i18n(app.modules.msp_speed.name)@")

    local posText = {x = w - 220, y = app.radio.linePaddingTop, w = 200, h = app.radio.navbuttonHeight}

    line['rf'] = form.addLine("@i18n(app.modules.msp_speed.rf_protocol)@")
    fields['rf'] = form.addStaticText(line['rf'], posText, string.upper(tasks.msp.protocol.mspProtocol))

    line['runtime'] = form.addLine("@i18n(app.modules.msp_speed.test_length)@")
    fields['runtime'] = form.addStaticText(line['runtime'], posText, "-")

    line['total'] = form.addLine("@i18n(app.modules.msp_speed.total_queries)@")
    fields['total'] = form.addStaticText(line['total'], posText, "-")

    line['success'] = form.addLine("@i18n(app.modules.msp_speed.successful_queries)@")
    fields['success'] = form.addStaticText(line['success'], posText, "-")

    line['timeouts'] = form.addLine("@i18n(app.modules.msp_speed.timeouts)@")
    fields['timeouts'] = form.addStaticText(line['timeouts'], posText, "-")

    line['retries'] = form.addLine("@i18n(app.modules.msp_speed.retries)@")
    fields['retries'] = form.addStaticText(line['retries'], posText, "-")

    line['checksum'] = form.addLine("@i18n(app.modules.msp_speed.checksum_errors)@")
    fields['checksum'] = form.addStaticText(line['checksum'], posText, "-")

    line['mintime'] = form.addLine("@i18n(app.modules.msp_speed.min_query_time)@")
    fields['mintime'] = form.addStaticText(line['mintime'], posText, "-")

    line['maxtime'] = form.addLine("@i18n(app.modules.msp_speed.max_query_time)@")
    fields['maxtime'] = form.addStaticText(line['maxtime'], posText, "-")

    line['time'] = form.addLine("@i18n(app.modules.msp_speed.avg_query_time)@")
    fields['time'] = form.addStaticText(line['time'], posText, "-")

    formLoaded = true
end

local function onToolMenu()
    openSpeedTestDialog()
    return true
end

local function mspSuccess(self)
    if testLoader then
        mspQueryTimeCount = mspQueryTimeCount + os.clock() - mspQueryStartTime
        mspSpeedTestStats['success'] = mspSpeedTestStats['success'] + 1

        local queryTime = os.clock() - mspQueryStartTime

        if queryTime ~= 0 then
            if queryTime > maxQueryTime then maxQueryTime = queryTime end

            if queryTime < minQueryTime then minQueryTime = queryTime end
        end

    end
end

local function mspTimeout(self) if testLoader then mspSpeedTestStats['timeouts'] = mspSpeedTestStats['timeouts'] + 1 end end

local function mspRetry(self) if testLoader then mspSpeedTestStats['retries'] = mspSpeedTestStats['retries'] + (self.retryCount - 1) end end

local function mspChecksum(self) if testLoader then mspSpeedTestStats['checksum'] = mspSpeedTestStats['checksum'] + 1 end end

local function close()
    if testLoader then
        testLoader:close()
        testLoader = nil
    end
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

return {
    openPage = openPage,
    onNavMenu = onNavMenu,
    onToolMenu = onToolMenu,
    navButtons = {menu = true, save = false, reload = false, tool = true, help = false},
    mspRetry = mspRetry,
    mspSuccess = mspSuccess,
    mspTimeout = mspTimeout,
    mspChecksum = mspChecksum,
    event = event,
    close = close,
    API = {}
}
