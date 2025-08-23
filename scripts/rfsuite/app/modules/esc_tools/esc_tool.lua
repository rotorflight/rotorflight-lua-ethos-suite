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

local i18n = rfsuite.i18n.get

local modelField
local versionField
local firmwareField

local findTimeoutClock = os.clock()
local findTimeout = math.floor(rfsuite.tasks.msp.protocol.pageReqTimeout * 0.5)

local modelLine
local modelText
local modelTextPos = {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}

local function getESCDetails()

    if rfsuite.session.escDetails ~= nil then
        escDetails = rfsuite.session.escDetails
        foundESC = true 
        return
    end

    if foundESC == true then 
        return
    end

    local message = {
        command = 217, -- MSP_STATUS
        processReply = function(self, buf)

            local mspBytesCheck = 2 -- we query 2 only unless the flack to cache the init buffer is set
            if ESC and ESC.mspBufferCache == true then
                mspBytesCheck = mspBytes
            end
 
            --if #buf >= mspBytesCheck and buf[1] == mspSignature then
            if buf[1] == mspSignature then
                escDetails.model = ESC.getEscModel(buf)
                escDetails.version = ESC.getEscVersion(buf)
                escDetails.firmware = ESC.getEscFirmware(buf)

                rfsuite.session.escDetails = escDetails

                if ESC.mspBufferCache == true then
                    rfsuite.session.escBuffer = buf 
                end    

                if escDetails.model ~= nil  then
                    foundESC = true
                end

            end

        end,
        uuid = "123e4567-e89b-12d3-b456-426614174201",
        simulatorResponse = simulatorResponse
    }

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function openPage(pidx, title, script)

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    

    local folder = title

    ESC = assert(rfsuite.compiler.loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()

    if ESC.mspapi ~= nil then
        -- we are using the api so get values from that!
        local API = rfsuite.tasks.msp.api.load(ESC.mspapi)
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


    local windowWidth = rfsuite.app.lcdWidth
    local windowHeight = rfsuite.app.lcdHeight

    local y = rfsuite.app.radio.linePaddingTop

    form.clear()

    line = form.addLine(i18n("app.modules.esc_tools.name") .. ' / ' .. ESC.toolName)

    buttonW = 100
    local x = windowWidth - buttonW

    rfsuite.app.formNavigationFields['menu'] = form.addButton(line, {x = x - buttonW - 5, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = i18n("app.navigation_menu"),
        icon = nil,
        options = FONT_S,
        paint = function()
        end,
        press = function()
            rfsuite.app.ui.openPage(pidx, i18n("app.modules.esc_tools.name"), "esc_tools/esc.lua")

        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    rfsuite.app.formNavigationFields['refresh'] = form.addButton(line, {x = x, y = rfsuite.app.radio.linePaddingTop, w = buttonW, h = rfsuite.app.radio.navbuttonHeight}, {
        text = i18n("app.navigation_reload"),
        icon = nil,
        options = FONT_S,
        paint = function()
        end,
        press = function()
            rfsuite.app.Page = nil
            local foundESC = false
            local foundESCupdateTag = false
            local showPowerCycleLoader = false
            local showPowerCycleLoaderInProgress = false
            rfsuite.app.triggers.triggerReloadFull = true
        end
    })
    rfsuite.app.formNavigationFields['menu']:focus()

    ESC.pages = assert(rfsuite.compiler.loadfile("app/modules/esc_tools/mfg/" .. folder .. "/pages.lua"))()

    modelLine = form.addLine("")
    modelText = form.addStaticText(modelLine, modelTextPos, "")

    local buttonW
    local buttonH
    local padding
    local numPerRow

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    -- TEXT ICONS
    if rfsuite.preferences.general.iconsize == 0 then
        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = (rfsuite.app.lcdWidth - padding) / rfsuite.app.radio.buttonsPerRow - padding
        buttonH = rfsuite.app.radio.navbuttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end
    -- SMALL ICONS
    if rfsuite.preferences.general.iconsize == 1 then

        padding = rfsuite.app.radio.buttonPaddingSmall
        buttonW = rfsuite.app.radio.buttonWidthSmall
        buttonH = rfsuite.app.radio.buttonHeightSmall
        numPerRow = rfsuite.app.radio.buttonsPerRowSmall
    end
    -- LARGE ICONS
    if rfsuite.preferences.general.iconsize == 2 then

        padding = rfsuite.app.radio.buttonPadding
        buttonW = rfsuite.app.radio.buttonWidth
        buttonH = rfsuite.app.radio.buttonHeight
        numPerRow = rfsuite.app.radio.buttonsPerRow
    end

    local lc = 0
    local bx = 0

    if rfsuite.app.gfx_buttons["esctool"] == nil then rfsuite.app.gfx_buttons["esctool"] = {} end
    if rfsuite.preferences.menulastselected["esctool"] == nil then rfsuite.preferences.menulastselected["esctool"] = 1 end

    for pidx, pvalue in ipairs(ESC.pages) do 


        local section = pvalue
        local hideSection =
            (section.ethosversion and rfsuite.session.ethosRunningVersion < section.ethosversion) or
            (section.mspversion   and rfsuite.utils.apiVersionCompare("<", section.mspversion))
                            --or
                            --(section.developer and not rfsuite.preferences.developer.devtools)

        if not pvalue.disablebutton or (pvalue and pvalue.disablebutton(mspBytes) == false) or not hideSection then

            if lc == 0 then
                if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
                if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
            end

            if lc >= 0 then bx = (buttonW + padding) * lc end

            if rfsuite.preferences.general.iconsize ~= 0 then
                if rfsuite.app.gfx_buttons["esctool"][pvalue.image] == nil then rfsuite.app.gfx_buttons["esctool"][pvalue.image] = lcd.loadMask("app/modules/esc_tools/mfg/" .. folder .. "/gfx/" .. pvalue.image) end
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
                    rfsuite.preferences.menulastselected["esctool"] = pidx
                    rfsuite.app.ui.progressDisplay()

                    rfsuite.app.ui.openPage(pidx, title, "esc_tools/mfg/" .. folder .. "/pages/" .. pvalue.script)

                end
            })

            if rfsuite.preferences.menulastselected["esctool"] == pidx then rfsuite.app.formFields[pidx]:focus() end

            if rfsuite.app.triggers.escToolEnableButtons == true then
                rfsuite.app.formFields[pidx]:enable(true)
            else
                rfsuite.app.formFields[pidx]:enable(false)
            end

            lc = lc + 1

            if lc == numPerRow then lc = 0 end
        end

    end

    rfsuite.app.triggers.escToolEnableButtons = false
    --getESCDetails()
    collectgarbage()
end

local function wakeup()

    if foundESC == false and rfsuite.tasks.msp.mspQueue:isProcessed() then getESCDetails() end

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
        rfsuite.app.dialogs.progress:close()
        rfsuite.app.dialogs.progressDisplay = false
        rfsuite.app.triggers.isReady = true

        if ESC and ESC.powerCycle ~= true then modelText = form.addStaticText(modelLine, modelTextPos, i18n("app.modules.esc_tools.unknown")) end

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
                modelText = form.addStaticText(modelLine, modelTextPos, i18n("app.modules.esc_tools.unknown"))
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
            powercycleLoader = form.openProgressDialog(i18n("app.modules.esc_tools.searching"), i18n("app.modules.esc_tools.please_powercycle"))
            powercycleLoader:value(0)
            powercycleLoader:closeAllowed(false)
        end
    end

end

local function event(widget, category, value, x, y)

    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, i18n("app.modules.esc_tools.name"), "esc_tools/esc.lua")
        return true
    end


end

return {
    openPage = openPage,
    wakeup = wakeup,
    event = event,
    API = {}
}
