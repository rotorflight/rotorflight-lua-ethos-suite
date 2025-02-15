local pages = {}

local mspSignature
local mspHeaderBytes
local mspBytes
local simulatorResponse
local escDetails = {}
local foundESC = false
local foundESCupdateTag = false
local showPowerCycleLoader = false
local showPowerCycleLoaderInProgress = false
local ESC
local powercycleLoader
local powercycleLoaderCounter = 0
local powercycleLoaderRateLimit = 2
local showPowerCycleLoaderFinished = false

local modelField
local versionField
local firmwareField

local findTimeoutClock = os.clock()
local findTimeout = math.floor(rfsuite.bg.msp.protocol.pageReqTimeout * 0.5)

local modelLine
local modelText
local modelTextPos = {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.config.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}

local function getESCDetails()

    local message = {
        command = 217, -- MSP_STATUS
        processReply = function(self, buf)

            local mspBytesCheck = 2 -- we query 2 only unless the flack to cache the init buffer is set
            if ESC.mspBufferCache == true then
                mspBytesCheck = mspBytes
            end
 
            if #buf >= mspBytesCheck and buf[1] == mspSignature then

                escDetails.model = ESC.getEscModel(buf)
                escDetails.version = ESC.getEscVersion(buf)
                escDetails.firmware = ESC.getEscFirmware(buf)

                if ESC.mspBufferCache == true then
                    rfsuite.escBuffer = buf 
                end    

                foundESC = true

            end

        end,
        simulatorResponse = simulatorResponse
    }

    rfsuite.bg.msp.mspQueue:add(message)
end

local function openPage(pidx, title, script)

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.escBuffer = nil -- clear the buffer

    local folder = title

    ESC = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/init.lua"))()

    if ESC.mspapi ~= nil then
        -- we are using the api so get values from that!
        local API = rfsuite.bg.msp.api.load(ESC.mspapi)
        mspSignature = API.mspSignature
        mspHeaderBytes = API.mspHeaderBytes
        simulatorResponse = API.simulatorResponse or {0}
        mspBytes = #simulatorResponse
    else
        --legacy method
        mspSignature = ESC.mspSignature
        mspHeaderBytes = ESC.mspHeaderBytes
        simulatorResponse = ESC.simulatorResponse
        mspBytes = ESC.mspBytes
    end    

    rfsuite.app.formFields = {}
    rfsuite.app.formLines = {}


    local windowWidth = rfsuite.config.lcdWidth
    local windowHeight = rfsuite.config.lcdHeight

    local y = rfsuite.app.radio.linePaddingTop

    form.clear()

    line = form.addLine("ESC" .. ' / ' .. ESC.toolName)

    buttonW = 100
    local x = windowWidth - buttonW

    rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {x = x - buttonW - 5, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "MENU",
        icon = nil,
        options = FONT_S,
        paint = function()
        end,
        press = function()
            rfsuite.app.ui.openPage(pidx, "ESC", "esc/esc.lua")

        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    rfsuite.app.formNavigationFields['refresh'] = form.addButton(line, {x = x, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = "RELOAD",
        icon = nil,
        options = FONT_S,
        paint = function()
        end,
        press = function()
            -- rfsuite.app.ui.openPage(pidx, folder , "esc/esc_tool.lua")
            rfsuite.app.Page = nil
            local foundESC = false
            local foundESCupdateTag = false
            local showPowerCycleLoader = false
            local showPowerCycleLoaderInProgress = false
            rfsuite.app.triggers.triggerReload = true
        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    ESC.pages = assert(loadfile("app/modules/esc/mfg/" .. folder .. "/pages.lua"))()

    modelLine = form.addLine("")
    modelText = form.addStaticText(modelLine, modelTextPos, "")

    local buttonW
    local buttonH
    local padding
    local numPerRow

    if rfsuite.config.iconSize == nil or rfsuite.config.iconSize == "" then
        rfsuite.config.iconSize = 1
    else
        rfsuite.config.iconSize = tonumber(rfsuite.config.iconSize)
    end

    -- TEXT ICONS
    if rfsuite.config.iconSize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.config.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end
    -- SMALL ICONS
    if rfsuite.config.iconSize == 1 then

        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end
    -- LARGE ICONS
    if rfsuite.config.iconSize == 2 then

        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    local lc = 0
    local bx = 0

    if rfsuite.app.gfx_buttons["esctool"] == nil then rfsuite.app.gfx_buttons["esctool"] = {} end
    if rfsuite.app.menuLastSelected["esctool"] == nil then rfsuite.app.menuLastSelected["esctool"] = 1 end

    for pidx, pvalue in ipairs(ESC.pages) do

        if lc == 0 then
            if rfsuite.config.iconSize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.config.iconSize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.config.iconSize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.config.iconSize ~= 0 then
            if rfsuite.app.gfx_buttons["esctool"][pvalue.image] == nil then rfsuite.app.gfx_buttons["esctool"][pvalue.image] = lcd.loadMask("app/modules/esc/mfg/" .. folder .. "/gfx/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["esctool"][pvalue.image] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.title,
            icon = rfsuite.app.gfx_buttons["esctool"][pvalue.image],
            options = FONT_S,
            paint = function()
            end,
            press = function()
                rfsuite.app.menuLastSelected["esctool"] = pidx
                rfsuite.app.ui.progressDisplay()

                -- rfsuite.app.ui.openPage(pidx, folder, "esc_form.lua",pvalue.script)
                rfsuite.app.ui.openPage(pidx, title, "esc/mfg/" .. folder .. "/pages/" .. pvalue.script)

            end
        })

        if rfsuite.app.menuLastSelected["esctool"] == pidx then rfsuite.app.formFields[pidx]:focus() end

        if rfsuite.app.triggers.escToolEnableButtons == true then
            rfsuite.app.formFields[pidx]:enable(true)
        else
            rfsuite.app.formFields[pidx]:enable(false)
        end

        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    rfsuite.app.triggers.escToolEnableButtons = false
    getESCDetails()

end

local function wakeup()

    if foundESC == false and rfsuite.bg.msp.mspQueue:isProcessed() then getESCDetails() end

    -- enable the form
    if foundESC == true and foundESCupdateTag == false then
        foundESCupdateTag = true

        if escDetails.model ~= nil and escDetails.model ~= nil and escDetails.firmware ~= nil then
            local text = escDetails.model .. " " .. escDetails.version .. " " .. escDetails.firmware
            rfsuite.escHeaderLineText = text
            modelText = form.addStaticText(modelLine, modelTextPos, text)
        end

        for i, v in ipairs(rfsuite.app.formFields) do rfsuite.app.formFields[i]:enable(true) end

        if ESC and ESC.powerCycle == true and showPowerCycleLoader == true then
            powercycleLoader:close()
            powercycleLoaderCounter = 0
            showPowerCycleLoaderInProgress = false
            showPowerCycleLoader = false
            showPowerCycleLoaderFinished = true
            rfsuite.app.triggers.isReady = true
        end

        rfsuite.app.triggers.closeProgressLoader = true

    end

    if showPowerCycleLoaderFinished == false and foundESCupdateTag == false and showPowerCycleLoader == false and ((findTimeoutClock <= os.clock() - findTimeout) or rfsuite.app.dialogs.progressCounter >= 101) then
        rfsuite.app.ui.progressDisplayClose()
        rfsuite.app.dialogs.progressDisplay = false
        rfsuite.app.triggers.isReady = true

        if ESC and ESC.powerCycle ~= true then modelText = form.addStaticText(modelLine, modelTextPos, "UNKNOWN") end

        if ESC and ESC.powerCycle == true then showPowerCycleLoader = true end

    end

    if showPowerCycleLoaderInProgress == true then

        local now = os.clock()
        if (now - powercycleLoaderRateLimit) >= 2 then

            getESCDetails()

            powercycleLoaderRateLimit = now
            powercycleLoaderCounter = powercycleLoaderCounter + 5
            powercycleLoader:value(powercycleLoaderCounter)

            if powercycleLoaderCounter >= 100 then
                powercycleLoader:close()
                modelText = form.addStaticText(modelLine, modelTextPos, "UNKNOWN")
                showPowerCycleLoaderInProgress = false
                rfsuite.app.triggers.disableRssiTimeout = false
                showPowerCycleLoader = false
                rfsuite.app.audio.playTimeout = true
                showPowerCycleLoaderFinished = true
                rfsuite.app.triggers.isReady = false
            end

        end

    end

    if showPowerCycleLoader == true then
        if showPowerCycleLoaderInProgress == false then
            showPowerCycleLoaderInProgress = true
            rfsuite.app.audio.playEscPowerCycle = true
            rfsuite.app.triggers.disableRssiTimeout = true
            powercycleLoader = form.openProgressDialog("Searching", "Please power cycle the ESC...")
            powercycleLoader:value(0)
            powercycleLoader:closeAllowed(false)
        end
    end

end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, "ESC", "esc.lua")
        return true
    end

    return false
end

return {
    title = "ESC",
    openPage = openPage,
    wakeup = wakeup,
    event = event,
    API = {}
}
