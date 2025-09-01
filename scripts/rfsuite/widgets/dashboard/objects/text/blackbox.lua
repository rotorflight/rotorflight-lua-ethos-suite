--[[
    Blackbox Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if not present
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function) on used MB
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local eraseDataflashGo = false
local lastDisplayValue = nil


function render.dirty(box)
    if not rfsuite.session.telemetryState then return false end

    if box._lastDisplayValue == nil then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end

    if box._lastDisplayValue ~= box._currentDisplayValue then
        box._lastDisplayValue = box._currentDisplayValue
        return true
    end

    return false
end


local function eraseBlackboxAsk()
    local buttons = {{
        label = rfsuite.i18n.get("app.btn_ok"),
        action = function()

            -- we push this to the background task to do its job
            eraseDataflashGo = true
            return true
        end
    }, {
        label = rfsuite.i18n.get("app.btn_cancel"),
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = nil,
        title =  rfsuite.i18n.get("widgets.bbl.erase_dataflash"),
        message = rfsuite.i18n.get("widgets.bbl.erase_dataflash") .. "?",
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })
end

-- Trigger erase command
local function eraseDataflash()
    isErase = true
    progress = form.openProgressDialog(rfsuite.i18n.get("app.msg_saving"), rfsuite.i18n.get("app.msg_saving_to_fbl"))
    progress:value(0)
    progress:closeAllowed(false)
    progressCounter = 0

    local message = {
        command = 72,
        processReply = function()
            isErase = false
        end
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

function render.wakeup(box)
    -- Value extraction
    local totalSize = rfsuite.session.bblSize
    local usedSize  = rfsuite.session.bblUsed

    -- Set displayValue, Fallback if no value
    local displayValue
    local percentUsed
    if totalSize and usedSize then
        local usedMB  = usedSize  / (1024 * 1024)
        local totalMB = totalSize / (1024 * 1024)
        percentUsed = totalSize > 0 and (usedSize / totalSize) * 100 or 0

        local decimals = getParam(box, "decimals") or 1
        local transformedUsed  = utils.transformValue(usedMB, box)
        local transformedTotal = utils.transformValue(totalMB, box)
        displayValue = string.format("%." .. decimals .. "f/%." .. decimals .. "f %s",
            transformedUsed, transformedTotal, rfsuite.i18n.get("app.modules.fblstatus.megabyte"))
    else
        -- Show loading dots while no telemetry data is present
        if totalSize == nil and usedSize == nil then
            local maxDots = 3
            if box._dotCount == nil then box._dotCount = 0 end
            box._dotCount = (box._dotCount + 1) % (maxDots + 1)
            displayValue = string.rep(".", box._dotCount)
            if displayValue == "" then displayValue = "." end
        else
            displayValue = getParam(box, "novalue") or "-"
        end
        percentUsed = nil
    end

    -- Suppress unit if we're displaying loading dots
    if type(displayValue) == "string" and displayValue:match("^%.+$") then
        unit = nil
    end
    
    -- Set box.value so dashboard/dirty can track change for redraws
    box._currentDisplayValue = displayValue
    
    -- Threshold logic (if required)
    local textcolor = percentUsed ~= nil
    and utils.resolveThresholdColor(percentUsed, box, "textcolor", "textcolor")
    or resolveThemeColor("textcolor", getParam(box, "textcolor"))

    -- inject default bbl erase system ; but allow to override it
    if not box.onpress then
        box.onpress = eraseBlackboxAsk
    end

    -- run the erase process if requested
    if eraseDataflashGo then
        eraseDataflashGo = false
        eraseDataflash()
    end

    -- handle progress dialog if its visible
     -- draw progress bar if needed
    if progress then
        progressCounter = progressCounter + 20
        progress:value(progressCounter)
        if progressCounter >= 100 then
            progress:close()
            progress = nil
        end
    end   

    box._cache = {
        title              = getParam(box, "title"),
        titlepos           = getParam(box, "titlepos"),
        titlealign         = getParam(box, "titlealign"),
        titlefont          = getParam(box, "titlefont"),
        titlespacing       = getParam(box, "titlespacing"),
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        displayValue       = displayValue,
        unit               = nil,
        font               = getParam(box, "font"),
        valuealign         = getParam(box, "valuealign"),
        textcolor          = textcolor,
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    utils.box(
        x, y, w, h,
        c.title, c.titlepos, c.titlealign, c.titlefont, c.titlespacing,
        c.titlecolor, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.displayValue, c.unit, c.font, c.valuealign, c.textcolor,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.bgcolor
    )
end

return render
