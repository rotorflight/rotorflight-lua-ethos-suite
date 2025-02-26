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

local arg = {...}
local config = arg[1]

-- used to take tables from format used in pages
-- and convert them to an ethos forms format
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

-- GET FIELD VALUE FOR ETHOS FORMS.  FUNCTION TAKES THE VALUE AND APPLIES RULES BASED
-- ON THE PARAMETERS ON THE rfsuite.pages TABLE
function utils.getFieldValue(f)
    local v = f.value or 0

    if f.decimals then
        v = rfsuite.utils.round(v * rfsuite.app.utils.decimalInc(f.decimals))
    end

    if f.offset then
        v = v + f.offset
    end

    if f.mult then
        v = math.floor(v * f.mult + 0.5)
    end

    return v
end

-- SAVE FIELD VALUE FOR ETHOS FORMS.  FUNCTION TAKES THE VALUE AND APPLIES RULES BASED
-- ON THE PARAMETERS ON THE rfsuite.pages TABLE
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

function utils.scaleValue(value, f)
    if not value then return nil end
    local v = value * app.utils.decimalInc(f.decimals)
    if f.scale then v = v / f.scale end
    return utils.round(v)
end


function utils.decimalInc(dec)
    
    local decTable = {10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000, 10000000000, 100000000000}

    if dec == nil or dec == 0 then
        return 1
    else
        return decTable[dec]
    end
end


-- set positions of form elements
function utils.getInlinePositions(f, lPage)
    -- Compute inline size in one step.
    local inline_size = utils.getInlineSize(f.label, lPage) * rfsuite.app.radio.inlinesize_mult

    -- Get LCD dimensions.
    local w, h = rfsuite.utils.getWindowSize()

    local padding = 5
    local fieldW = (w * inline_size) / 100
    local eW = fieldW - padding
    local eH = rfsuite.app.radio.navbuttonHeight
    local eY = rfsuite.app.radio.linePaddingTop

    -- Set default text and compute its dimensions.
    f.t = f.t or ""
    lcd.font(FONT_STD)
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


-- find size of elements
function utils.getInlineSize(id, lPage)
    if not id then return nil end
    for i = 1, #lPage.labels do
        local v = lPage.labels[i]
        if v.label == id then
            return v.inline_size or 13.6
        end
    end
    return nil
end

return utils