--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local S_PAGES

if rfsuite.utils.apiVersionCompare(">=", "12.09") then              -- we start this disabled and only enable if we mixers are compatible
    S_PAGES = {
        [1] = { name = "@i18n(app.modules.mixer.swash)@", script = "swash.lua", image = "swash.png" , disabled = true },
        [2] = { name = "@i18n(app.modules.mixer.geometry)@", script = "swashgeometry.lua", image = "geometry.png", disabled = true },    
        [3] = { name = "@i18n(app.modules.mixer.tail)@", script = "tail.lua", image = "tail.png", disabled = true },
        [4] = { name = "@i18n(app.modules.mixer.trims)@", script = "trims.lua", image = "trims.png", disabled = true },
    }
else
    S_PAGES = {
        [1] = { name = "@i18n(app.modules.mixer.swash)@", script = "swash_legacy.lua", image = "swash.png" },
        [2] = { name = "@i18n(app.modules.mixer.tail)@", script = "tail_legacy.lua", image = "tail.png" },
        [3] = { name = "@i18n(app.modules.mixer.trims)@", script = "trims.lua", image = "trims.png" },    
    }   
end


local enableWakeup = false
local prevConnectedState = nil
local initTime = os.clock()
local mixerCompatibilityStatus = false

-- hold mixer input values
local MIXER_PITCH_RATE
local MIXER_PITCH_MIN
local MIXER_PITCH_MAX

local MIXER_ROLL_RATE
local MIXER_ROLL_MIN
local MIXER_ROLL_MAX

local MIXER_COLLECTIVE_RATE
local MIXER_COLLECTIVE_MIN
local MIXER_COLLECTIVE_MAX

-- MSP transports these fields as unsigned (u16) even though their meaning is signed (s16).
-- swashgeometry.lua already treats them as u16-encoded s16, so mirror that here.
local function u16_to_s16(u)
    if u == nil then return nil end
    if u >= 0x8000 then
        return u - 0x10000
    end
    return u
end

local function getMixerCompatibilityStatus()

        -- pitch
        local PAPI = rfsuite.tasks.msp.api.load("GET_MIXER_INPUT_PITCH")
        PAPI.setCompleteHandler(function(self, buf)
                MIXER_PITCH_RATE = u16_to_s16(PAPI.readValue("rate_stabilized_pitch"))
                MIXER_PITCH_MIN  = u16_to_s16(PAPI.readValue("min_stabilized_pitch"))
                MIXER_PITCH_MAX  = u16_to_s16(PAPI.readValue("max_stabilized_pitch"))
        end)
        PAPI.setUUID("d8163617-1496-4886-8b81-" .. "GET_MIXER_INPUT_PITCH")
        PAPI.read()

        -- roll
        local RAPI = rfsuite.tasks.msp.api.load("GET_MIXER_INPUT_ROLL")
        RAPI.setCompleteHandler(function(self, buf)
                MIXER_ROLL_RATE = u16_to_s16(RAPI.readValue("rate_stabilized_roll"))
                MIXER_ROLL_MIN  = u16_to_s16(RAPI.readValue("min_stabilized_roll"))
                MIXER_ROLL_MAX  = u16_to_s16(RAPI.readValue("max_stabilized_roll"))
        end)
        RAPI.setUUID("d8163617-1496-4886-8b81-" .. "GET_MIXER_INPUT_ROLL")
        RAPI.read()

        -- collective
        local CAPI = rfsuite.tasks.msp.api.load("GET_MIXER_INPUT_COLLECTIVE")
        CAPI.setCompleteHandler(function(self, buf)
                MIXER_COLLECTIVE_RATE = u16_to_s16(CAPI.readValue("rate_stabilized_collective"))
                MIXER_COLLECTIVE_MIN  = u16_to_s16(CAPI.readValue("min_stabilized_collective"))
                MIXER_COLLECTIVE_MAX  = u16_to_s16(CAPI.readValue("max_stabilized_collective"))
        end)        
        CAPI.setUUID("d8163617-1496-4886-8b81-" .. "GET_MIXER_INPUT_COLLECTIVE")
        CAPI.read()


end

local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script

    rfsuite.tasks.msp.protocol.mspIntervalOveride = nil

    rfsuite.app.triggers.isReady = false
    rfsuite.app.uiState = rfsuite.app.uiStatus.mainMenu

    form.clear()

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    for i in pairs(rfsuite.app.gfx_buttons) do if i ~= "mixer" then rfsuite.app.gfx_buttons[i] = nil end end

    if rfsuite.preferences.general.iconsize == nil or rfsuite.preferences.general.iconsize == "" then
        rfsuite.preferences.general.iconsize = 1
    else
        rfsuite.preferences.general.iconsize = tonumber(rfsuite.preferences.general.iconsize)
    end

    local w, h = lcd.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = rfsuite.app.radio.buttonPadding

    local sc
    local panel

    local buttonW = 100
    local x = windowWidth - buttonW - 10

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.mixer.name)@")

    local buttonW
    local buttonH
    local padding
    local numPerRow

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

    if rfsuite.app.gfx_buttons["mixer"] == nil then rfsuite.app.gfx_buttons["mixer"] = {} end
    local lastSelected = tonumber(rfsuite.preferences.menulastselected["mixer"]) or 1
    if lastSelected < 1 then lastSelected = 1 end
    if lastSelected > #S_PAGES then lastSelected = #S_PAGES end
    rfsuite.preferences.menulastselected["mixer"] = lastSelected
    rfsuite.app._mixer_focused = false

    local Menu = assert(loadfile("app/modules/" .. script))()
    local pages = S_PAGES
    local lc = 0
    local bx = 0
    local y = 0

    for pidx, pvalue in ipairs(S_PAGES) do

        if lc == 0 then
            if rfsuite.preferences.general.iconsize == 0 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 1 then y = form.height() + rfsuite.app.radio.buttonPaddingSmall end
            if rfsuite.preferences.general.iconsize == 2 then y = form.height() + rfsuite.app.radio.buttonPadding end
        end

        if lc >= 0 then bx = (buttonW + padding) * lc end

        if rfsuite.preferences.general.iconsize ~= 0 then
            if rfsuite.app.gfx_buttons["mixer"][pidx] == nil then rfsuite.app.gfx_buttons["mixer"][pidx] = lcd.loadMask("app/modules/mixer/gfx/" .. pvalue.image) end
        else
            rfsuite.app.gfx_buttons["mixer"][pidx] = nil
        end

        rfsuite.app.formFields[pidx] = form.addButton(line, {x = bx, y = y, w = buttonW, h = buttonH}, {
            text = pvalue.name,
            icon = rfsuite.app.gfx_buttons["mixer"][pidx],
            options = FONT_S,
            paint = function() end,
            press = function()
                rfsuite.preferences.menulastselected["mixer"] = pidx
                rfsuite.app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.DEFAULT)
                local name = "@i18n(app.modules.mixer.name)@" .. " / " .. pvalue.name
                rfsuite.app.ui.openPage({idx = pidx, title = name, script = "mixer/tools/" .. pvalue.script})
            end
        })

        -- keep disabled until we know mixer session vars exist
        rfsuite.app.formFields[pidx]:enable(false) 

        local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false


        lc = lc + 1

        if lc == numPerRow then lc = 0 end

    end

    enableWakeup = true

    if rfsuite.utils.apiVersionCompare(">=", "12.09") then 
        getMixerCompatibilityStatus()
    end    

    return
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openMainMenuSub(rfsuite.app.lastMenu)
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openMainMenuSub('hardware')
    return true
end

local function mixerInputsAreCompatible()

    -- ensure all values are present
    if  MIXER_ROLL_RATE       == nil or MIXER_ROLL_MIN       == nil or MIXER_ROLL_MAX       == nil or
        MIXER_PITCH_RATE      == nil or MIXER_PITCH_MIN      == nil or MIXER_PITCH_MAX      == nil or
        MIXER_COLLECTIVE_RATE == nil or MIXER_COLLECTIVE_MIN == nil or MIXER_COLLECTIVE_MAX == nil then
        return false
    end

    local customConfig = false

    -- rate compatibility: roll vs pitch must be equal OR exact opposite
    if (MIXER_ROLL_RATE ~= MIXER_PITCH_RATE) and
       (MIXER_ROLL_RATE ~= -MIXER_PITCH_RATE) then
        customConfig = true
    end

    -- roll/pitch min/max must match each other
    if MIXER_ROLL_MAX ~= MIXER_PITCH_MAX then customConfig = true end
    if MIXER_ROLL_MIN ~= MIXER_PITCH_MIN then customConfig = true end

    -- each axis must be symmetric: max == -min
    if MIXER_ROLL_MAX       ~= -MIXER_ROLL_MIN       then customConfig = true end
    if MIXER_PITCH_MAX      ~= -MIXER_PITCH_MIN      then customConfig = true end
    if MIXER_COLLECTIVE_MAX ~= -MIXER_COLLECTIVE_MIN then customConfig = true end

    return not customConfig
end


local function wakeup()
    if not enableWakeup then return end

    if os.clock() - initTime < 0.25 then return end


    if rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil then
        if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then
            rfsuite.tasks.msp.helpers.mixerConfig(function(tailMode, swashMode)
                rfsuite.utils.log("Received tail mode: " .. tostring(tailMode), "info")
                rfsuite.utils.log("Received swash mode: " .. tostring(swashMode), "info")
            end)
        end
    end

    -- enable the buttons once we have servo info
    if rfsuite.session.tailMode ~= nil and rfsuite.session.swashMode ~= nil then
        for i, v in pairs(rfsuite.app.formFields) do
            if v.enable then
                v:enable(true)
            end    
        end

        if not rfsuite.app._mixer_focused then
            rfsuite.app._mixer_focused = true
            local idx = tonumber(rfsuite.preferences.menulastselected["mixer"]) or 1
            local btn = rfsuite.app.formFields and rfsuite.app.formFields[idx] or nil
            if btn and btn.focus then btn:focus() end
        end
        -- close progress loader
        rfsuite.app.triggers.closeProgressLoader = true
    end


    local currState = (rfsuite.session.isConnected and rfsuite.session.mcu_id) and true or false

    if currState ~= prevConnectedState then

        if not currState then rfsuite.app.formNavigationFields['menu']:focus() end

        prevConnectedState = currState
    end


    -- Once we have all mixer inputs, decide if the "simple" mixer pages can be enabled.
    if (MIXER_PITCH_RATE ~= nil and MIXER_PITCH_MIN ~= nil and MIXER_PITCH_MAX ~= nil) and
       (MIXER_ROLL_RATE ~= nil and MIXER_ROLL_MIN ~= nil and MIXER_ROLL_MAX ~= nil) and
       (MIXER_COLLECTIVE_RATE ~= nil and MIXER_COLLECTIVE_MIN ~= nil and MIXER_COLLECTIVE_MAX ~= nil) then

        local ok = mixerInputsAreCompatible()

        -- Only update UI state once (or if it changes due to reconnect / profile swap)
        if ok ~= mixerCompatibilityStatus then
            mixerCompatibilityStatus = ok

            -- If we're on API >= 12.09 we start pages disabled; enable when compatible.
            if rfsuite.utils.apiVersionCompare(">=", "12.09") and rfsuite.app.formFields then
                local enable = ok and currState
                for i = 1, #S_PAGES do
                    local f = rfsuite.app.formFields[i]
                    if f then f:enable(enable) end
                end
            end

            if not ok then
                print("Mixer inputs are NOT compatible")
            end
        end
    end


end

rfsuite.app.uiState = rfsuite.app.uiStatus.pages

return {pages = pages, openPage = openPage, onNavMenu = onNavMenu, event = event, wakeup = wakeup, API = {}, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}}
