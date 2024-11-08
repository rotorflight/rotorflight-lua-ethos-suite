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

local function resetStats()
    getMSPCount = 0
    mspQueryTimeCount = 0

    mspSpeedTestStats = {total = 0, success = 0, total = 0, retries = 0, timeouts = 0, checksum = 0}
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
    rfsuite.bg.msp.mspQueue:add(message)
end

local function getMSPServos()
    local message = {
        command = 120, -- MSP_STATUS
        processReply = function(self, buf)
            doNextMsp = true
        end,
        simulatorResponse = {
            4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0,
            120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0
        }
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

local function getMSPPids()
    local message = {
        command = 112, -- MSP_STATUS
        processReply = function(self, buf)
            doNextMsp = true
        end,
        simulatorResponse = {70, 0, 225, 0, 90, 0, 120, 0, 100, 0, 200, 0, 70, 0, 120, 0, 100, 0, 125, 0, 83, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 25, 0}
    }
    rfsuite.bg.msp.mspQueue:add(message)
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

    fields['memory']:value(rfsuite.utils.round(system.getMemoryUsage().luaRamAvailable / 1000, 2) .. 'kB')

    fields['total']:value(tostring(mspSpeedTestStats['total']))

    fields['retries']:value(tostring(mspSpeedTestStats['retries']))

    fields['timeouts']:value(tostring(mspSpeedTestStats['timeouts']))

    fields['checksum']:value(tostring(mspSpeedTestStats['checksum']))

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
        title = "Testing",
        message = "Testing MSP performance...",
        close = function()
            updateStats()
            testLoader = nil
        end,
        wakeup = function()
            local now = os.clock()

            -- kill if we loose link - but not in sim mode
            if rfsuite.bg.telemetry.active() == false and startTest == true and system:getVersion().simulation ~= true then
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
            if rfsuite.bg.msp.mspQueue:isProcessed() and ((now - RateLimit) >= Rate) then
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
    local buttons = {
        {
            label = "  600S  ",
            action = function()
                startTest(600)
                return true
            end
        }, {
            label = "  300S  ",
            action = function()
                startTest(300)
                return true
            end
        }, {
            label = "  120S  ",
            action = function()
                startTest(120)
                return true
            end
        }, {
            label = "  30S  ",
            action = function()
                startTest(30)
                return true
            end
        }
    }
    form.openDialog({title = "Start", message = "Would you like to start the test? Choose the test run time below.", buttons = buttons, options = TEXT_LEFT})
end

local function openPage(pidx, title, script)
    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script
    rfsuite.app.triggers.closeProgressLoader = true

    local w, h = rfsuite.utils.getWindowSize()

    local y = rfsuite.app.radio.linePaddingTop

    form.clear()

    local titleline = form.addLine("MSP Speed")

    local buttonW = 100
    local buttonWs = buttonW - (buttonW * 20) / 100
    local x = w - 10

    rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {
        x = x - 5 - buttonW - buttonWs - 5 - buttonWs,
        y = rfsuite.app.radio.linePaddingTop,
        w = buttonW,
        h = rfsuite.app.radio.navbuttonHeight
    }, {
        text = "MENU",
        icon = nil,
        options = FONT_S,
        press = function()
            rfsuite.app.ui.openMainMenu()
        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    -- ACTION BUTTON
    rfsuite.app.formNavigationFields['tool'] = form.addButton(line, {x = x - 5 - buttonWs - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = buttonWs, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "*",
        icon = nil,
        options = FONT_S,
        press = function()
            openSpeedTestDialog()
        end
    })

    -- HELP BUTTON
    local help = assert(compile.loadScript("app/help/pages.lua"))()
    local section = string.gsub(rfsuite.app.lastScript, ".lua", "") -- remove .lua
    rfsuite.app.formNavigationFields['help'] = form.addButton(line, {x = x - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = buttonWs, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "?",
        icon = nil,
        options = FONT_S,
        paint = function()
        end,
        press = function()
            if rfsuite.app.Page and rfsuite.app.Page.onHelpMenu then
                rfsuite.app.Page.onHelpMenu(rfsuite.app.Page)
            else
                rfsuite.app.ui.openPagehelp(help.data, section)
            end
        end
    })

    local posText = {x = x - 5 - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 200, h = rfsuite.app.radio.navbuttonHeight}

    line['rf'] = form.addLine("RF protocol")
    fields['rf'] = form.addStaticText(line['rf'], posText, string.upper(rfsuite.bg.msp.protocol.mspProtocol))

    line['memory'] = form.addLine("Memory free")
    fields['memory'] = form.addStaticText(line['memory'], posText, rfsuite.utils.round(system.getMemoryUsage().luaRamAvailable / 1000, 2) .. 'kB')

    line['runtime'] = form.addLine("Test length")
    fields['runtime'] = form.addStaticText(line['runtime'], posText, "-")

    line['total'] = form.addLine("Total queries")
    fields['total'] = form.addStaticText(line['total'], posText, "-")

    line['success'] = form.addLine("Successful queries")
    fields['success'] = form.addStaticText(line['success'], posText, "-")

    line['timeouts'] = form.addLine("Timeouts")
    fields['timeouts'] = form.addStaticText(line['timeouts'], posText, "-")

    line['retries'] = form.addLine("Retries")
    fields['retries'] = form.addStaticText(line['retries'], posText, "-")

    line['checksum'] = form.addLine("Checksum errors")
    fields['checksum'] = form.addStaticText(line['checksum'], posText, "-")

    line['time'] = form.addLine("Average query time")
    fields['time'] = form.addStaticText(line['time'], posText, "-")

    formLoaded = true
end

function mspSuccess(self)
    if testLoader then
        mspQueryTimeCount = mspQueryTimeCount + os.clock() - mspQueryStartTime
        mspSpeedTestStats['success'] = mspSpeedTestStats['success'] + 1
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

return {title = title, openPage = openPage, mspRetry = mspRetry, mspSuccess = mspSuccess, mspTimeout = mspTimeout, mspChecksum = mspChecksum, event = event, close = close}
