--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local utils = {}
local app = rfsuite.app
local rfutils = rfsuite.utils
local tasks = rfsuite.tasks
local session = rfsuite.session
local simevent = rfsuite.simevent

local arg = {...}
local config = arg[1]

function utils.getRSSI()
    if simevent.rflink == 1 then return 0 end

    if app.offlineMode == true then return 100 end

    if session.telemetryState then
        return 100
    else
        return 0
    end
end

function utils.convertPageValueTable(tbl, inc)
    local thetable = {}

    if inc == nil then inc = 0 end

    if tbl[0] ~= nil then
        thetable[0] = {}
        thetable[0][1] = tbl[0]
        thetable[0][2] = 0
    end

    for idx, value in ipairs(tbl) do
        thetable[idx] = {}
        thetable[idx][1] = value
        thetable[idx][2] = idx + inc
    end

    return thetable
end


function utils.getFieldValue(f)
    local v = f.value or 0

    if f.decimals then v = rfutils.round(v * app.utils.decimalInc(f.decimals), 2) end

    if f.offset then v = v + f.offset end

    if f.mult then v = math.floor(v * f.mult + 0.5) end

    return v
end

function utils.saveFieldValue(f, value)
    if value then
        if f.offset then value = value - f.offset end
        if f.decimals then
            f.value = value / app.utils.decimalInc(f.decimals)
        else
            f.value = value
        end
        if f.postEdit then f.postEdit(app.Page) end
    end

    if f.mult then f.value = f.value / f.mult end

    return f.value
end

function utils.scaleValue(value, f)
    if not value then return nil end
    local v = value * app.utils.decimalInc(f.decimals)
    if f.scale then v = v / f.scale end
    return rfutils.round(v)
end

function utils.decimalInc(dec)
    if dec == nil then
        return 1
    elseif dec > 0 and dec <= 10 then
        return 10 ^ dec
    else
        return nil
    end
end

function utils.getInlinePositions(f)

    local lPage = rfsuite.app.Page.apidata.formdata

    local function getInlineSize(id)
        if not id then return 13.6 end
        for i = 1, #lPage.labels do if lPage.labels[i].label == id then return lPage.labels[i].inline_size or 13.6 end end
        return 13.6
    end

    local inline_size = getInlineSize(f.label) * app.radio.inlinesize_mult

    local w, h = lcd.getWindowSize()

    local padding = 5
    local fieldW = (w * inline_size) / 100
    local eW = fieldW - padding
    local eH = app.radio.navbuttonHeight
    local eY = app.radio.linePaddingTop

    f.t = f.t or ""
    lcd.font(FONT_STD)
    local tsizeW, tsizeH = lcd.getTextSize(f.t)

    local multipliers = {[1] = 1, [2] = 3, [3] = 5, [4] = 7, [5] = 9}
    local m = multipliers[f.inline] or 1

    local textPadding = (f.inline == 1) and (2 * padding) or padding

    local posTextX = w - fieldW * m - tsizeW - textPadding
    local posFieldX = w - fieldW * m - ((f.inline == 1) and padding or 0)

    local posText = {x = posTextX, y = eY, w = tsizeW, h = eH}
    local posField = {x = posFieldX, y = eY, w = eW, h = eH}

    return {posText = posText, posField = posField}
end

function utils.getCurrentProfile()
    local pidProfile = tasks.telemetry.getSensor("pid_profile")
    if pidProfile ~= nil then
        session.activeProfileLast = session.activeProfile
        local p = pidProfile
        if p ~= nil then
            session.activeProfile = math.floor(p)
        else
            session.activeProfile = nil
        end
    end
end

function utils.getCurrentRateProfile()
    local rateProfile = tasks.telemetry.getSensor("rate_profile")

    if rateProfile ~= nil then
        session.activeRateProfileLast = session.activeRateProfile
        local r = rateProfile
        if r ~= nil then
            session.activeRateProfile = math.floor(r)
        else
            session.activeRateProfile = nil
        end
    end
end

function utils.titleCase(str) return str:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest:lower() end) end

function utils.settingsSaved()
    local mspEepromWrite = {
        command = 250,
        processReply = function(self, buf)
            app.triggers.closeSave = true
            if app.Page.postEepromWrite then app.Page.postEepromWrite() end
            if app.Page.reboot then
                app.ui.rebootFc()
            else
                app.utils.invalidatePages()
            end
        end,
        errorHandler = function(self) 
            app.triggers.closeSave = true 
            app.triggers.showSaveArmedWarning = true
        end,
        simulatorResponse = {}
    }

    if app.Page and app.Page.eepromWrite then
        if app.pageState ~= app.pageStatus.eepromWrite then
            app.pageState = app.pageStatus.eepromWrite
            app.triggers.closeSave = true
            if session.isArmed then app.triggers.showSaveArmedWarning = true end
            local ok, reason = tasks.msp.mspQueue:add(mspEepromWrite)
            if not ok then
                utils.log("EEPROM enqueue rejected: " .. tostring(reason), "info")
                app.pageState = app.pageStatus.display
                app.triggers.closeSaveFake = true
                app.triggers.isSaving = false
                app.triggers.saveFailed = true
            end
        end
    elseif app.pageState ~= app.pageStatus.eepromWrite then
        app.utils.invalidatePages()
        app.triggers.closeSave = true
    end

end

function utils.invalidatePages()
    app.Page = nil
    app.pageState = app.pageStatus.display
    app.saveTS = 0

end

return utils
