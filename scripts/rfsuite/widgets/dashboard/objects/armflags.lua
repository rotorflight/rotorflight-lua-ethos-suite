--[[
    Arm Flags Widget
    Configurable Parameters (box table fields):
    -------------------------------------------
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
    thresholds          : table                     -- (Optional) List of thresholds: {value=..., textcolor=...} for coloring ARMED/DISARMED states.
    novalue             : string                    -- (Optional) Text shown if telemetry value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value (not used here)
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)

    -- Example thresholds:
    -- thresholds = {
    --     { value = "ARMED", textcolor = "green" },
    --     { value = "DISARMED", textcolor = "red" },
    --     { value = "Throttle high", textcolor = "orange" },
    --     { value = "Failsafe", textcolor = "orange" },
    -- }
]]

local render = {}

local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local armingDisableFlagsToString = rfsuite.app.utils.armingDisableFlagsToString

function render.wakeup(box, telemetry)
    -- Value extraction
    local value = telemetry and telemetry.getSensor("armflags")
    local disableflags = telemetry and telemetry.getSensor("armdisableflags")

    -- displayValue: rendered string (reason or ARMED/DISARMED); showReason: set true if using disable reason
    local displayValue
    local showReason = false

    -- Try to use arm disable reason, if present and not "OK"
    if disableflags ~= nil and armingDisableFlagsToString then
        disableflags = math.floor(disableflags)
        local reason = armingDisableFlagsToString(disableflags)
        if reason and reason ~= "OK" then
            displayValue = reason
            showReason = true
        end
    end

    -- Fallback to ARMED/DISARMED state if no specific disable reason
    if not showReason then
        if value ~= nil then
            if value == 1 or value == 3 then
                displayValue = rfsuite.i18n.get("ARMED")
            else
                displayValue = rfsuite.i18n.get("DISARMED")
            end
        end
    end

    -- Threshold logic (optional)
    local textcolor = utils.resolveThresholdColor(displayValue, box, "textcolor", "textcolor")

    -- If *neither* value nor disable reason is available, show novalue
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
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
