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
local utils = {}
local i18n = rfsuite.i18n.get

local arg = {...}
local config = arg[1]


--[[
    Function: app.utils.getRSSI
    Description: Retrieves the RSSI (Received Signal Strength Indicator) value.
    Returns 100 if the system is in simulation mode, the RSSI sensor check is skipped, or the app is in offline mode.
    Otherwise, returns 100 if telemetry is active, and 0 if it is not.
    Returns:
        number - The RSSI value (100 or 0).
]]
function utils.getRSSI()

    if rfsuite.simevent.rflink == 1 then
        return 0
    end

    if rfsuite.app.offlineMode == true then return 100 end


    if rfsuite.session.telemetryState then
        return 100
    else
        return 0
    end
end


--[[
    Converts a table of values into a table of tables, where each inner table contains the original value and an incremented index.

    @param tbl (table) The input table of values.
    @param inc (number) Optional increment to add to each index. Defaults to 0 if not provided.

    @return (table) A new table where each entry is a table containing the original value and the incremented index.
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
        thetable[idx] = {}
        thetable[idx][1] = value
        thetable[idx][2] = idx + inc
    end

    return thetable
end


--[[
    Retrieves the value of a field, applying optional transformations.

    @param f (table) The field table containing the value and optional transformation parameters:
        - value (number) The base value of the field.
        - decimals (number, optional) The number of decimal places to consider.
        - offset (number, optional) A value to add to the base value.
        - mult (number, optional) A multiplier to apply to the value.

    @return (number) The transformed field value.
]]
function utils.getFieldValue(f)
    local v = f.value or 0

    if f.decimals then
        v = rfsuite.utils.round(v * rfsuite.app.utils.decimalInc(f.decimals),2)
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
    Saves the given value to the specified field after applying necessary transformations.

    @param f (table) The field to save the value to. Expected to have the following optional properties:
        - offset (number): A value to subtract from the input value before saving.
        - decimals (number): The number of decimal places to consider for the value.
        - postEdit (function): A function to call after the value is saved.
        - mult (number): A multiplier to divide the final value by before returning.
    @param value (number) The value to save to the field.

    @return (number) The final value saved to the field.
]]
function utils.saveFieldValue(f, value)
    if value then
        if f.offset then value = value - f.offset end
        if f.decimals then
            f.value = value / rfsuite.app.utils.decimalInc(f.decimals)
        else
            f.value = value
        end
        if f.postEdit then f.postEdit(rfsuite.app.Page) end
    end

    if f.mult then f.value = f.value / f.mult end

    return f.value
end

-- Scales a given value based on the provided factor.
-- @param value The value to be scaled.
-- @param f A table containing scaling parameters:
--   - decimals: The number of decimal places to consider.
--   - scale: (optional) A scaling factor to divide the value by.
-- @return The scaled value, rounded to the nearest integer, or nil if the input value is nil.
function utils.scaleValue(value, f)
    if not value then return nil end
    local v = value * rfsuite.app.utils.decimalInc(f.decimals)
    if f.scale then v = v / f.scale end
    return rfsuite.utils.round(v)
end


-- Increments the decimal place value.
-- @param dec The current decimal place value (1 for 10, 2 for 100, etc.).
-- @return The next decimal place value or 1 if the input is nil or 0.
function utils.decimalInc(dec)
    if dec == nil then
        return 1
    elseif dec > 0 and dec <= 10 then
        return 10 ^ dec  -- Use dynamic exponentiation
    else
        return nil  -- Return nil for invalid inputs (optional, you can adjust behavior)
    end
end


--[[
    Computes the positions for inline elements on the LCD screen.

    @param f (table) - A table containing the label and inline properties.
        - label (string) - The label text.
        - inline (number) - The inline multiplier (1 to 5).
        - t (string) - Optional text to display.
    @param lPage (number) - The page number for inline size calculation.

    @return (table) - A table containing the positions for text and field elements.
        - posText (table) - Position and size of the text element.
            - x (number) - X-coordinate of the text.
            - y (number) - Y-coordinate of the text.
            - w (number) - Width of the text.
            - h (number) - Height of the text.
        - posField (table) - Position and size of the field element.
            - x (number) - X-coordinate of the field.
            - y (number) - Y-coordinate of the field.
            - w (number) - Width of the field.
            - h (number) - Height of the field.
]]
function utils.getInlinePositions(f, lPage)
    -- Compute inline size in one step.
    local inline_size = utils.getInlineSize(f.label, lPage) * rfsuite.app.radio.inlinesize_mult

    -- Get LCD dimensions.
    local w, h = lcd.getWindowSize()

    local padding = 5
    local fieldW = (w * inline_size) / 100
    local eW = fieldW - padding
    local eH = rfsuite.app.radio.navbuttonHeight
    local eY = rfsuite.app.radio.linePaddingTop

    -- Set default text and compute its dimensions.
    f.t = f.t or ""
    lcd.font(FONT_M)
    local tsizeW, tsizeH = lcd.getTextSize(f.t)

    -- Map inline values to multipliers.
    local multipliers = { [1] = 1, [2] = 3, [3] = 5, [4] = 7, [5] = 9 }
    local m = multipliers[f.inline] or 1

    -- For inline==1, extra padding is applied to the text.
    local textPadding = (f.inline == 1) and (2 * padding) or padding

    local posTextX = w - fieldW * m - tsizeW - textPadding
    local posFieldX = w - fieldW * m - ((f.inline == 1) and padding or 0)

    local posText = { x = posTextX, y = eY, w = tsizeW, h = eH }
    local posField = { x = posFieldX, y = eY, w = eW, h = eH }

    return { posText = posText, posField = posField }
end



--[[
    Retrieves the inline size for a given label ID from the provided page.

    @param id (string|nil) The ID of the label to find the inline size for. If nil, a default size is returned.
    @param lPage (table) The page object containing labels with their respective inline sizes.

    @return (number) The inline size of the label if found, otherwise returns a default size of 13.6.
]]
function utils.getInlineSize(id, lPage)
    if not id then return 13.6 end  -- Prevent nil size issues
    for i = 1, #lPage.labels do
        if lPage.labels[i].label == id then
            return lPage.labels[i].inline_size or 13.6
        end
    end
    return 13.6  -- Use default if label is missing
end

-- to grab activeProfile or activeRateProfile in tmp var
-- you MUST set it to nil after you get it!
function utils.getCurrentProfile()


    local pidProfile = rfsuite.tasks.telemetry.getSensor("pid_profile")
    local rateProfile = rfsuite.tasks.telemetry.getSensor("rate_profile")

    if (pidProfile ~= nil and rateProfile ~= nil) then

        rfsuite.session.activeProfileLast = rfsuite.session.activeProfile
        local p = pidProfile
        if p ~= nil then
            rfsuite.session.activeProfile = math.floor(p)
        else
            rfsuite.session.activeProfile = nil
        end

        rfsuite.session.activeRateProfileLast = rfsuite.session.activeRateProfile
        local r = rateProfile
        if r ~= nil then
            rfsuite.session.activeRateProfile = math.floor(r)
        else
            rfsuite.session.activeRateProfile = nil
        end

    end
end

function utils.titleCase(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

function utils.stringInArray(array, s)
    for i, value in ipairs(array) do if value == s then return true end end
    return false
end

return utils


