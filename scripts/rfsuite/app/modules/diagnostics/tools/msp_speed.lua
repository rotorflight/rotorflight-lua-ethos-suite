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
local line = {}
local fields = {}

local formLoaded = false
local startTestTime = os.clock()
local startTestLength = 0

local testLoader = nil

local mspQueryStartTime
local mspQueryTimeCount = 0
local getMSPCount = 0
local doNextMsp = true

local mspSpeedTestStats

local maxQueryTime = 0
local minQueryTime = 1000

local function resetStats()
    getMSPCount = 0
    mspQueryTimeCount = 0

    mspSpeedTestStats = {total = 0, success = 0, retries = 0, timeouts = 0, checksum = 0}
end

resetStats()

local RateLimit = os.clock()
local Rate = 0.25 -- how many times per second we can call msp 

local function getMSPPidBandwidth()
    local message = {
        command = 94, -- MSP_STATUS
        processReply = function(self, buf)
            doNextMsp = true
        end,
        simulatorResponse = {3, 25, 250, 0, 12, 0, 1, 30, 30, 45, 50, 50, 100, 15, 15, 20, 2, 10, 10, 15, 100, 100, 5, 0, 30, 0, 25, 0, 40, 55, 40, 75, 20, 25, 0, 15, 45, 45, 15, 15, 20}
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function getMSPServos()
    local message = {
        command = 120, -- MSP_STATUS
        processReply = function(self, buf)
            doNextMsp = true
        end,
        simulatorResponse = {4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0}
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function getMSPPids()
    local message = {
        command = 112, -- MSP_STATUS
        processReply = function(self, buf)
            doNextMsp = true
        end,
        simulatorResponse = {70, 0, 225, 0, 90, 0, 120, 0, 100, 0, 200, 0, 70, 0, 120, 0, 100, 0, 125, 0, 83, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 25, 0}
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function getMSP()
    -- three diff msp queries. 
    if getMSPCount == 0 then
        getMSPPidBandwidth()
        getMSPCount = 1
    elseif getMSPCount == 1 then
        getMSPServos()
        getMSPCount = 2
    else
        getMSPPids()
        getMSPCount = 0
    end

    local avgQueryTime = rfsuite.utils.round(mspQueryTimeCount / mspSpeedTestStats['total'], 2) .. "s"

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

    local avgQueryTime = rfsuite.utils.round(mspQueryTimeCount / mspSpeedTestStats['total'], 2) .. "s"
    fields['time']:value(tostring(avgQueryTime))

end

local function startTest(duration)
    startTestLength = duration
    startTestTime = os.clock()

    testLoader = form.openProgressDialog({
        title = "@i18n(app.modules.msp_speed.testing)@",
        message = "@i18n(app.modules.msp_speed.testing_performance)@",
        close = function()
            updateStats()
            testLoader = nil
        end,
        wakeup = function()
            local now = os.clock()

            -- kill if we loose link - but not in sim mode
            if rfsuite.session.telemetryState == false and startTest == true and system:getVersion().simulation ~= true then
                if testLoader then
                    testLoader:close()
                    testLoader = nil
                end
            end

            if formLoaded == true then
                rfsuite.app.triggers.closeProgressLoader = true
                formLoaded = false
            end

            testLoader:value((now - startTestTime) * 100 / startTestLength)

            -- close progress box
            if (now - startTestLength) > startTestTime then
                testLoader:close()
                testLoader = nil
                updateStats()
            end

            -- do msp query
            if rfsuite.tasks.msp.mspQueue:isProcessed() and ((now - RateLimit) >= Rate) then
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

    resetStats()

    doNextMsp = true
end

local function openSpeedTestDialog()
    local buttons = {{
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
    }}
    form.openDialog({title = "@i18n(app.modules.msp_speed.start)@", message = "@i18n(app.modules.msp_speed.start_prompt)@", buttons = buttons, options = TEXT_LEFT})
end

local function openPage(pidx, title, script)
    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script
    rfsuite.app.triggers.closeProgressLoader = true

    local w, h = lcd.getWindowSize()

    local y = rfsuite.app.radio.linePaddingTop

    form.clear()

    local titleline = form.addLine("@i18n(app.modules.diagnostics.name)@" .. " / " .. "@i18n(app.modules.msp_speed.name)@")

    local buttonW = 100
    local buttonWs = buttonW - (buttonW * 20) / 100
    local x = w - 10

    rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {x = x - 5 - buttonW - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "@i18n(app.navigation_menu)@",
        icon = nil,
        options = FONT_S,
        press = function()
            rfsuite.app.ui.openPage(
                pageIdx,
                "@i18n(app.modules.diagnostics.name)@",
                "diagnostics/diagnostics.lua"
            )
        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    -- ACTION BUTTON
    rfsuite.app.formNavigationFields['tool'] = form.addButton(line, {x = x - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = buttonWs, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "*",
        icon = nil,
        options = FONT_S,
        press = function()
            openSpeedTestDialog()
        end
    })

    local posText = {x = x - 5 - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 200, h = rfsuite.app.radio.navbuttonHeight}

    line['rf'] = form.addLine("@i18n(app.modules.msp_speed.rf_protocol)@")
    fields['rf'] = form.addStaticText(line['rf'], posText, string.upper(rfsuite.tasks.msp.protocol.mspProtocol))

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

function mspSuccess(self)
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

function mspTimeout(self)
    if testLoader then mspSpeedTestStats['timeouts'] = mspSpeedTestStats['timeouts'] + 1 end
end

function mspRetry(self)
    if testLoader then mspSpeedTestStats['retries'] = mspSpeedTestStats['retries'] + (self.retryCount - 1) end
end

function mspChecksum(self)
    if testLoader then mspSpeedTestStats['checksum'] = mspSpeedTestStats['checksum'] + 1 end
end

function close()
    if testLoader then
        testLoader:close()
        testLoader = nil
    end
end

local function event(widget, category, value, x, y)
    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(
            pageIdx,
            "@i18n(app.modules.diagnostics.name)@",
            "diagnostics/diagnostics.lua"
        )
        return true
    end
end


return {
    openPage = openPage,
    onNavMenu = onNavMenu,
    mspRetry = mspRetry,
    mspSuccess = mspSuccess,
    mspTimeout = mspTimeout,
    mspChecksum = mspChecksum,
    event = event,
    close = close,
    API = {},
}
