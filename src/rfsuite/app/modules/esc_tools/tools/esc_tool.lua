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
local showPowerCycleLoader = false
local showPowerCycleLoaderInProgress = false
local ESC
local powercycleLoader
local powercycleLoaderCounter = 0
local powercycleLoaderRateLimit = 2
local showPowerCycleLoaderFinished = false
local powercycleLoaderBaseMessage
local findTimeoutClock = os.clock()
local findTimeout = math.floor(rfsuite.tasks.msp.protocol.pageReqTimeout * 0.5)

local modelLine
local modelText
local modelTextPos = {x = 0, y = rfsuite.app.radio.linePaddingTop, w = rfsuite.app.lcdWidth, h = rfsuite.app.radio.navbuttonHeight}

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

local mspBusy = false

local function getESCDetails()
    if not ESC then return end
    if not ESC.mspapi then return end
    if not mspSignature then return end
    if not mspBytes then return end
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

    local API = rfsuite.tasks.msp.api.load(ESC.mspapi)
    API.setCompleteHandler(function(self, buf)

        local signature = API.readValue("esc_signature")

        if signature == mspSignature and #buf >= mspBytes then
            escDetails.model = ESC.getEscModel(buf)
            escDetails.version = ESC.getEscVersion(buf)
            escDetails.firmware = ESC.getEscFirmware(buf)

            rfsuite.session.escDetails = escDetails

            if ESC.mspBufferCache == true then rfsuite.session.escBuffer = buf end

            if escDetails.model ~= nil then 
                foundESC = true 
            end
        end
        mspBusy = false

    end)

    API.setErrorHandler(function(self, err)
        mspBusy = false
    end)

    API.setUUID("550e8400-e29b-41d4-a716-546a55340500")
    API.read()

end

local function updatePowercycleLoaderMessage()
    if not powercycleLoader or not powercycleLoaderBaseMessage then return end
    if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.updateProgressDialogMessage then
        rfsuite.app.ui.updateProgressDialogMessage()
    end
end

local function clearPowercycleLoader()
    if powercycleLoader then
        pcall(function() powercycleLoader:close() end)
        if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.clearProgressDialog then
            rfsuite.app.ui.clearProgressDialog(powercycleLoader)
        end
    end
    powercycleLoader = nil
    powercycleLoaderBaseMessage = nil
    showPowerCycleLoader = false
    showPowerCycleLoaderInProgress = false
    showPowerCycleLoaderFinished = false
end

local function clearEscSessionCache()
    if rfsuite.session then
        rfsuite.session.escDetails = nil
        rfsuite.session.escBuffer = nil
    end
end

local function openPage(opts)

    local parentIdx = opts.idx
    local title = opts.title
    local folder = opts.folder
    local script = opts.script

    if type(folder) ~= "string" or folder == "" then
        folder = title
    end

    ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()

    if rfsuite.app and rfsuite.app.Page and ESC and ESC.mspapi then
        rfsuite.app.Page.apidata = rfsuite.app.Page.apidata or {}
        rfsuite.app.Page.apidata.api = {ESC.mspapi}
    end

    if ESC.mspapi ~= nil then

        local API = rfsuite.tasks.msp.api.load(ESC.mspapi)
        mspSignature = API.mspSignature
        simulatorResponse = API.simulatorResponse or {0}
        mspBytes = #simulatorResponse
    else

        mspSignature = ESC.mspSignature
        simulatorResponse = ESC.simulatorResponse
        mspBytes = ESC.mspBytes
    end

    local app = rfsuite.app
    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    local y = rfsuite.app.radio.linePaddingTop

    form.clear()

    local headerTitle = title
    if type(headerTitle) ~= "string" or headerTitle == "" then
        headerTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. ESC.toolName
    end
    rfsuite.app.ui.fieldHeader(headerTitle)

    ESC.pages = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/pages.lua"))()

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

                    rfsuite.app.ui.openPage({
                        idx = childIdx,
                        title = childTitle,
                        script = "esc_tools/tools/escmfg/" .. folder .. "/pages/" .. pvalue.script,
                        returnContext = {
                            idx = parentIdx,
                            title = title,
                            folder = folder,
                            script = "esc_tools/tools/esc_tool.lua"
                        }
                    })

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

local function onNavMenu()
    clearPowercycleLoader()
    clearEscSessionCache()
    pageRuntime.openMenuContext({defaultSection = "system"})
    return true
end

local function onReloadMenu()
    rfsuite.app.Page = nil
    foundESC = false
    foundESCupdateTag = false
    clearPowercycleLoader()
    clearEscSessionCache()
    powercycleLoaderCounter = 0
    rfsuite.app.triggers.triggerReloadFull = true
    return true
end

local function wakeup()

    if foundESC == false then
        getESCDetails()
    end

    if foundESC == true and foundESCupdateTag == false then
        foundESCupdateTag = true

        if escDetails.model ~= nil and escDetails.model ~= nil and escDetails.firmware ~= nil then
            local text = escDetails.model .. " " .. escDetails.version .. " " .. escDetails.firmware
            rfsuite.escHeaderLineText = text
            setModelHeaderText(text)
        end

        for i, v in ipairs(rfsuite.app.formFields) do rfsuite.app.formFields[i]:enable(true) end

        if ESC and ESC.powerCycle == true and showPowerCycleLoader == true then
            powercycleLoader:close()
            rfsuite.app.ui.clearProgressDialog(powercycleLoader)
            powercycleLoaderCounter = 0
            showPowerCycleLoaderInProgress = false
            showPowerCycleLoader = false
            showPowerCycleLoaderFinished = true
            rfsuite.app.triggers.isReady = true
            powercycleLoaderBaseMessage = nil
        end

        rfsuite.app.triggers.closeProgressLoader = true

    end

    if showPowerCycleLoaderFinished == false and foundESCupdateTag == false and showPowerCycleLoader == false and ((findTimeoutClock <= os.clock() - findTimeout) or rfsuite.app.dialogs.progressCounter >= 101) then
        rfsuite.app.dialogs.progress:close()
        rfsuite.app.dialogs.progressDisplay = false
        rfsuite.app.triggers.isReady = true

        if ESC and ESC.powerCycle ~= true then setModelHeaderText("@i18n(app.modules.esc_tools.unknown)@") end

        if ESC and ESC.powerCycle == true then showPowerCycleLoader = true end

    end

    if showPowerCycleLoaderInProgress == true then

        rfsuite.app.escPowerCycleLoader = true

        local now = os.clock()
        if (now - powercycleLoaderRateLimit) >= 2 then

            powercycleLoaderRateLimit = now
            powercycleLoaderCounter = powercycleLoaderCounter + 5
            powercycleLoader:value(powercycleLoaderCounter)
            updatePowercycleLoaderMessage()

            if powercycleLoaderCounter >= 100 then
                powercycleLoader:close()
                rfsuite.app.ui.clearProgressDialog(powercycleLoader)
                setModelHeaderText("@i18n(app.modules.esc_tools.unknown)@")
                showPowerCycleLoaderInProgress = false
                rfsuite.app.triggers.disableRssiTimeout = false
                showPowerCycleLoader = false
                rfsuite.app.audio.playTimeout = true
            showPowerCycleLoaderFinished = true
            rfsuite.app.triggers.isReady = false
            powercycleLoaderBaseMessage = nil
        end

    end
    else
        rfsuite.app.escPowerCycleLoader = false
    end

    if showPowerCycleLoader == true then
        if showPowerCycleLoaderInProgress == false then
            showPowerCycleLoaderInProgress = true
            rfsuite.app.audio.playEscPowerCycle = true
            rfsuite.app.triggers.disableRssiTimeout = true
            powercycleLoader = openProgressDialog("@i18n(app.modules.esc_tools.searching)@", "@i18n(app.modules.esc_tools.please_powercycle)@")
            powercycleLoader:value(0)
            powercycleLoader:closeAllowed(false)
            powercycleLoaderBaseMessage = "@i18n(app.modules.esc_tools.please_powercycle)@"
            updatePowercycleLoaderMessage()
            rfsuite.app.ui.registerProgressDialog(powercycleLoader, powercycleLoaderBaseMessage)
        end
    end

end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = function()
        clearPowercycleLoader()
        clearEscSessionCache()
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
