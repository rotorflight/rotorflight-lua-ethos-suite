--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local app = rfsuite.app
local formFields = app.formFields
local formLines = app.formLines
local radio = rfsuite.app.radio

local enableWakeup = false
local haveData = false
local isDirty = false
local triggerSave = false
local activeFieldIndex = nil

local APIDATA = {}

local FORMDATA = {}

local function saveData()
    local snap = APIDATA["GOVERNOR_CONFIG"]
    local form = FORMDATA["GOVERNOR_CONFIG"]
    if not snap or not snap.values or not form then
        rfsuite.utils.log("Save failed: missing GOVERNOR_CONFIG snapshot", "error")
        rfsuite.app.triggers.closeProgressLoader = true
        return
    end

    local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
    API.setRebuildOnWrite(true)

    -- restore snapshot values
    for k, v in pairs(snap.values) do
        API.setValue(k, v)
    end

    -- copy UI → payload (scale back to MSP units)
    for i = 1, 9 do
        local k = "gov_bypass_throttle_curve_" .. i
        local v = tonumber(form[k]) or 0
        if v < 0 then v = 0 end
        if v > 100 then v = 100 end
        snap.values[k] = math.floor(v * 2 + 0.5)
        API.setValue(k, snap.values[k])
    end

    API.setCompleteHandler(function()
        -- EEPROM commit
        local EAPI = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
        EAPI.setCompleteHandler(function()
            rfsuite.app.triggers.closeProgressLoader = true
        end)
        EAPI.write()
    end)

    API.write()
end

local function loadData()

        -- shallow-copy helper (snapshots tables so API internals can’t mutate our cache)
        local function copyTable(src)
            if type(src) ~= "table" then return src end
            local dst = {}
            for k, v in pairs(src) do
            dst[k] = v
            end
            return dst
        end

        local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
        API.setCompleteHandler(function(self, buf)

            -- store form data
            FORMDATA["GOVERNOR_CONFIG"] = {}
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_1 = math.floor(API.readValue("gov_bypass_throttle_curve_1") / 2)
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_2 = math.floor(API.readValue("gov_bypass_throttle_curve_2") / 2)
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_3 = math.floor(API.readValue("gov_bypass_throttle_curve_3") / 2)
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_4 = math.floor(API.readValue("gov_bypass_throttle_curve_4") / 2)
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_5 = math.floor(API.readValue("gov_bypass_throttle_curve_5") / 2)
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_6 = math.floor(API.readValue("gov_bypass_throttle_curve_6") / 2)
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_7 = math.floor(API.readValue("gov_bypass_throttle_curve_7") / 2)
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_8 = math.floor(API.readValue("gov_bypass_throttle_curve_8") / 2)
            FORMDATA["GOVERNOR_CONFIG"].gov_bypass_throttle_curve_9 = math.floor(API.readValue("gov_bypass_throttle_curve_9") / 2)

            -- store API data snapshot
            local d = API.data()
            APIDATA["GOVERNOR_CONFIG"] = {}
            APIDATA["GOVERNOR_CONFIG"]['values']             = copyTable(d.parsed)
            APIDATA["GOVERNOR_CONFIG"]['structure']          = copyTable(d.structure)
            APIDATA["GOVERNOR_CONFIG"]['buffer']             = copyTable(d.buffer)
            APIDATA["GOVERNOR_CONFIG"]['receivedBytesCount'] = d.receivedBytesCount
            APIDATA["GOVERNOR_CONFIG"]['positionmap']        = copyTable(d.positionmap)
            APIDATA["GOVERNOR_CONFIG"]['other']              = copyTable(d.other)


            rfsuite.utils.log("Governor Bypass Throttle Curves loaded", "info")   
            haveData = true
            isDirty = true
            
        end)
        API.setUUID("e2a1c5b3-7f4a-4c8e-9d2a-3b6f8e2dca12")
        API.read()
end


local function openPage(idx, title, script)

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages
    rfsuite.app.triggers.isReady = false

    rfsuite.app.lastIdx = idx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script
    rfsuite.session.lastPage = script

    rfsuite.app.uiState = rfsuite.app.uiStatus.pages

    local longPage = false

    form.clear()

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.governor.menu_curves_long)@")


    local res = system.getVersion()
    local LCD_W = res.lcdWidth
    local LCD_H = res.lcdHeight

    local FIELD_COUNT = 9
    local MARGIN = radio.buttonPadding
    local GAP = 5
    local FIELD_H = radio.navbuttonHeight

    local usableW = LCD_W - (MARGIN * 2)
    local denom = FIELD_COUNT
    local fieldW = math.floor((usableW - (GAP * (FIELD_COUNT - 1))) / denom)

    for i = 1, FIELD_COUNT do

        local X_OFFSET = -radio.buttonPadding/2
        local x = MARGIN + (i - 1) * (fieldW + GAP) + X_OFFSET
        local y = LCD_H - radio.buttonHeightSmall - 10

        -- ensure we never exceed the window; clamp the last field width if needed
        local maxRight = LCD_W - MARGIN - 20
        local w = fieldW
        if x + w > maxRight then
            w = maxRight - x
        end
        if w < 1 then
            w = 1
        end

        formFields[i] = form.addNumberField(
            nil,
            { x=x, y=y, w=w, h=FIELD_H },
            0,
            100,
            function()
                if not haveData then return 0 end
                return FORMDATA["GOVERNOR_CONFIG"]["gov_bypass_throttle_curve_" .. i] or 0
            end,
            function(value)
                if not haveData then return end
                if not FORMDATA["GOVERNOR_CONFIG"] then return end
                activeFieldIndex = i
                FORMDATA["GOVERNOR_CONFIG"]["gov_bypass_throttle_curve_" .. i] = value
                isDirty = true
            end
        )
        -- highlight curve point on focus change (not only on value edit)
        formFields[i]:onFocus(function(state)
            if state then
                activeFieldIndex = i
                isDirty = true
            end
        end)        
    end
      

    -- fetch data
    loadData()

    -- finalise
    app.triggers.closeProgressLoader = true
    enableWakeup = true

end    

local function wakeup()
    if enableWakeup == false then return end

    -- we can now do anything we need to as data has been loaded
    if haveData then
        if isDirty then
            lcd.invalidate()
            isDirty = false
        end
    end

    if triggerSave then
        rfsuite.app.ui.progressDisplay(
            "@i18n(app.msg_saving_settings)@",
            "@i18n(app.msg_saving_to_fbl)@"
        )
        saveData()
        triggerSave = false
    end    

end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pidx, title, "governor/governor.lua")
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay()
    rfsuite.app.ui.openPage(pidx, title, "governor/governor.lua")
    return true
end

local function paint()
    local res = system.getVersion()
    local LCD_W = res.lcdWidth
    local LCD_H = res.lcdHeight
    local OFFSET_Y = LCD_H - radio.buttonHeightSmall - 10

    local FIELD_COUNT = 9
    local MARGIN = radio.buttonPadding
    local GAP = 5
    local X_OFFSET = -radio.buttonPadding / 2

    local usableW = LCD_W - (MARGIN * 2)
    local fieldW = math.floor((usableW - (GAP * (FIELD_COUNT - 1))) / FIELD_COUNT)

    local CURVE_X = MARGIN + X_OFFSET
    local CURVE_W = (fieldW * FIELD_COUNT) + (GAP * (FIELD_COUNT - 1)) - 15
    local CURVE_Y = radio.logGraphMenuOffset
    local CURVE_H = OFFSET_Y - CURVE_Y - 10

    local isDark = lcd.darkMode()

    -- =========================
    -- DRAW GRAPH
    -- =========================

    local pad = 4
    local gx = CURVE_X + pad
    local gy = CURVE_Y + pad
    local gw = CURVE_W - (pad * 2)
    local gh = CURVE_H - (pad * 2)

    if gw < 2 or gh < 2 then return end

    -- grid (optional but helps readability)
    lcd.color(isDark and lcd.GREY(80) or lcd.GREY(180))
    -- horizontal grid at 0/25/50/75/100
    for i = 0, 4 do
        local y = gy + math.floor((gh * i) / 4 + 0.5)
        lcd.drawLine(gx, y, gx + gw, y)
    end
    -- vertical grid for each point column
    for i = 0, FIELD_COUNT - 1 do
        local x = gx + math.floor((gw * i) / (FIELD_COUNT - 1) + 0.5)
        lcd.drawLine(x, gy, x, gy + gh)
    end

    if not haveData then return end

    -- collect + map points
    local pts = {}
    for i = 1, FIELD_COUNT do
        local v = FORMDATA["GOVERNOR_CONFIG"]["gov_bypass_throttle_curve_" .. i] or 0
        if v < 0 then v = 0 end
        if v > 100 then v = 100 end

        local nx = (i - 1) / (FIELD_COUNT - 1)          -- 0..1
        local ny = 1.0 - (v / 100.0)                    -- invert: 100 at top

        local px = gx + math.floor(nx * gw + 0.5)
        local py = gy + math.floor(ny * gh + 0.5)

        pts[i] = {x = px, y = py}
    end

    -- curve line
    lcd.color(isDark and lcd.RGB(255, 255, 255) or lcd.RGB(0, 0, 0))
    for i = 1, FIELD_COUNT - 1 do
        local a = pts[i]
        local b = pts[i + 1]
        lcd.drawLine(a.x, a.y, b.x, b.y)
    end

    -- point markers
    local r = 2
    for i = 1, FIELD_COUNT do
        local p = pts[i]

        if activeFieldIndex == i then
            -- highlighted (currently edited)
            lcd.color(isDark and lcd.RGB(255, 200, 0) or lcd.RGB(0, 120, 255))
            lcd.drawFilledCircle(p.x, p.y, r + 1)
        else
            -- normal
            lcd.color(isDark and lcd.RGB(220, 220, 220) or lcd.RGB(0, 0, 0))
            lcd.drawFilledCircle(p.x, p.y, r)
        end
    end
end

local function onSaveMenu()

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        triggerSave = true
        return
    end   

    form.openDialog({
        title   = "@i18n(app.modules.profile_select.save_settings)@",
        message = "@i18n(app.modules.profile_select.save_prompt)@",
        buttons = {
            {
                label = "@i18n(app.btn_ok_long)@",
                action = function()
                    triggerSave = true
                    return true
                end
            },
            {
                label = "@i18n(app.btn_cancel)@",
                action = function()
                    triggerSave = false
                    return true
                end
            }
        },
        options = TEXT_LEFT
    })
end

local function onReloadMenu()
    rfsuite.app.triggers.triggerReloadFull = true
end

return {apidata = apidata, reboot = true, onSaveMenu = onSaveMenu, onReloadMenu = onReloadMenu, eepromWrite = true, paint = paint, openPage = openPage, postSave = postSave, onNavMenu = onNavMenu, event = event, wakeup = wakeup, navButtons = {menu = true, save = true, reload = true, tool = false, help = false}}
