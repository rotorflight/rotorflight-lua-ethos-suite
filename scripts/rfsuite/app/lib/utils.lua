--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local utils = {}
local app   = rfsuite.app
local session = rfsuite.session
local rfutils = rfsuite.utils
local tasks = rfsuite.tasks


local arg     = { ... }
local config  = arg[1]

--[[
    Function: app.utils.getRSSI
    Description:
        Retrieves the RSSI (Received Signal Strength Indicator) value.

        - Returns 0 if simulation RF link is active.
        - Returns 100 if the app is in offline mode.
        - Otherwise, returns 100 if telemetry is active, and 0 if it is not.

    Returns:
        number - The RSSI value (100 or 0).
]]
function utils.getRSSI()
    if rfsuite.simevent.rflink == 1 then
        return 0
    end

    if app.offlineMode == true then
        return 100
    end

    if session.telemetryState then
        return 100
    else
        return 0
    end
end

--[[
    Converts a table of values into a table of tables, where each inner table
    contains the original value and an incremented index.

    @param tbl (table) The input table of values.
    @param inc (number) Optional increment to add to each index. Defaults to 0.

    @return (table) A new table where each entry is { value, index+inc }.
]]
function utils.convertPageValueTable(tbl, inc)
    local thetable = {}

    if inc == nil then inc = 0 end

    if tbl[0] ~= nil then
        thetable[0] = {}
        thetable[0][1] = tbl[0]
        thetable[0][2] = 0
    end

    for idx, value in ipairs(tbl) do
        thetable[idx]    = {}
        thetable[idx][1] = value
        thetable[idx][2] = idx + inc
    end

    return thetable
end

--[[
    Retrieves the value of a field, applying optional transformations.

    @param f (table) Field with optional keys:
        - value (number)   Base value (default 0).
        - decimals (number) Number of decimal places to consider.
        - offset (number)   Value to add after decimals handling.
        - mult (number)     Multiplier applied, rounded to nearest int.

    @return (number) Transformed field value.
]]
function utils.getFieldValue(f)
    local v = f.value or 0

    if f.decimals then
        v = rfutils.round(v * app.utils.decimalInc(f.decimals), 2)
    end

    if f.offset then
        v = v + f.offset
    end

    if f.mult then
        v = math.floor(v * f.mult + 0.5)
    end

    return v
end

--[[
    Saves the given value to the specified field after applying transformations.

    @param f (table) Field to save to. Optional keys:
        - offset (number)   Subtracted from input value before saving.
        - decimals (number) Divisor via decimalInc(decimals) before save.
        - postEdit (func)   Called as postEdit(app.Page) after save.
        - mult (number)     If present, divides the stored value before return.
    @param value (number) Value to save.

    @return (number) Final value stored in f.value (after mult division if set).
]]
function utils.saveFieldValue(f, value)
    if value then
        if f.offset   then value  = value - f.offset end
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

--[[
    Scales a given value based on the provided factor.

    @param value (number) Value to be scaled.
    @param f (table) Parameters:
        - decimals (number) Number of decimal places to consider.
        - scale (number|nil) Optional divisor.
    @return (number|nil) Scaled value, rounded, or nil if value is nil.
]]
function utils.scaleValue(value, f)
    if not value then return nil end
    local v = value * app.utils.decimalInc(f.decimals)
    if f.scale then v = v / f.scale end
    return rfutils.round(v)
end

--[[
    Increments the decimal place value.

    @param dec (number|nil) Decimal places (1 => 10, 2 => 100, ...).
    @return (number|nil) 10^dec, 1 if dec is nil, or nil if invalid input.
]]
function utils.decimalInc(dec)
    if dec == nil then
        return 1
    elseif dec > 0 and dec <= 10 then
        return 10 ^ dec
    else
        return nil
    end
end

--[[
    Computes positions for inline elements on the LCD screen.

    @param f (table)
        - label (string) Label text.
        - inline (number) Inline multiplier (1..5).
        - t (string|nil) Optional text to display.
    @param lPage (table) Page object for inline size calculation.

    @return (table)
        - posText  = { x, y, w, h }
        - posField = { x, y, w, h }
]]
function utils.getInlinePositions(f, lPage)
    -- Compute inline size in one step.
    local inline_size = utils.getInlineSize(f.label, lPage) * app.radio.inlinesize_mult

    -- Get LCD dimensions.
    local w, h = lcd.getWindowSize()

    local padding = 5
    local fieldW  = (w * inline_size) / 100
    local eW      = fieldW - padding
    local eH      = app.radio.navbuttonHeight
    local eY      = app.radio.linePaddingTop

    -- Set default text and compute its dimensions.
    f.t = f.t or ""
    lcd.font(FONT_M)
    local tsizeW, tsizeH = lcd.getTextSize(f.t)

    -- Map inline values to multipliers.
    local multipliers = { [1] = 1, [2] = 3, [3] = 5, [4] = 7, [5] = 9 }
    local m = multipliers[f.inline] or 1

    -- For inline==1, extra padding is applied to the text.
    local textPadding = (f.inline == 1) and (2 * padding) or padding

    local posTextX  = w - fieldW * m - tsizeW - textPadding
    local posFieldX = w - fieldW * m - ((f.inline == 1) and padding or 0)

    local posText  = { x = posTextX,  y = eY, w = tsizeW, h = eH }
    local posField = { x = posFieldX, y = eY, w = eW,    h = eH }

    return { posText = posText, posField = posField }
end

--[[
    Retrieves the inline size for a given label ID from the provided page.

    @param id (string|nil) Label identifier. If nil, returns default size.
    @param lPage (table)   Page object containing labels with inline sizes.

    @return (number) Inline size if found; otherwise 13.6.
]]
function utils.getInlineSize(id, lPage)
    if not id then return 13.6 end
    for i = 1, #lPage.labels do
        if lPage.labels[i].label == id then
            return lPage.labels[i].inline_size or 13.6
        end
    end
    return 13.6
end

--[[
    Capture active PID profile and rate profile into session.
    Note: If you cache activeProfile/activeRateProfile in a temp var,
    you MUST set it to nil after you get it.
]]
function utils.getCurrentProfile()
    local pidProfile  = tasks.telemetry.getSensor("pid_profile")
    local rateProfile = tasks.telemetry.getSensor("rate_profile")

    if (pidProfile ~= nil and rateProfile ~= nil) then
        session.activeProfileLast = session.activeProfile
        local p = pidProfile
        if p ~= nil then
            session.activeProfile = math.floor(p)
        else
            session.activeProfile = nil
        end

        session.activeRateProfileLast = session.activeRateProfile
        local r = rateProfile
        if r ~= nil then
            session.activeRateProfile = math.floor(r)
        else
            session.activeRateProfile = nil
        end
    end
end

--[[
    Convert a string to Title Case.
]]
function utils.titleCase(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end


-- Called when settings writes have completed (may queue EEPROM write)
function utils.settingsSaved()

-- MSP EEPROM write command descriptor
    local mspEepromWrite = {
        command = 250, -- MSP_EEPROM_WRITE (fails when armed)
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
        end,
        simulatorResponse = {}
    }

  if app.Page and app.Page.eepromWrite then
    if app.pageState ~= app.pageStatus.eepromWrite then
      app.pageState = app.pageStatus.eepromWrite
      app.triggers.closeSave = true
      if session.isArmed then
        app.triggers.showSaveArmedWarning = true
      end
      tasks.msp.mspQueue:add(mspEepromWrite)
    end
  elseif app.pageState ~= app.pageStatus.eepromWrite then
    app.utils.invalidatePages()
    app.triggers.closeSave = true
  end
  collectgarbage()
end

-- Invalidate pages after writes/reloads
function utils.invalidatePages()
  app.Page      = nil
  app.pageState = app.pageStatus.display
  app.saveTS    = 0
  collectgarbage()
end

return utils
