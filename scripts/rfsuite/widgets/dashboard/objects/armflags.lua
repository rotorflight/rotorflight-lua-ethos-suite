--[[
    Arm Flags Widget

    Configurable Parameters (box table fields):
    ----------------------------------------
    thresholds          : table                     -- (Optional) List of thresholds: {value=..., textcolor=...} for coloring ARMED/DISARMED states.
    novalue             : string                    -- (Optional) Text shown if telemetry value is missing (default: "-")
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    title               : string                    -- (Optional) Title text
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value

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
            if value >= 3 then
                displayValue = rfsuite.i18n.get("ARMED")
            else
                displayValue = rfsuite.i18n.get("DISARMED")
            end
        end
    end

    -- Threshold logic (optional)
    local textcolor = utils.resolveThresholdTextColor(displayValue, box)

    -- If *neither* value nor disable reason is available, show novalue
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
    end
    
    box._cache = {
        displayValue       = displayValue,
        unit               = nil,
        bgcolor            = resolveThemeColor("bgcolor", getParam(box, "bgcolor")),
        textcolor          = textcolor,
        titlecolor         = resolveThemeColor("titlecolor", getParam(box, "titlecolor")),
        title              = getParam(box, "title"),
        titlealign         = getParam(box, "titlealign"),
        valuealign         = getParam(box, "valuealign"),
        titlepos           = getParam(box, "titlepos"),
        titlepadding       = getParam(box, "titlepadding"),
        titlepaddingleft   = getParam(box, "titlepaddingleft"),
        titlepaddingright  = getParam(box, "titlepaddingright"),
        titlepaddingtop    = getParam(box, "titlepaddingtop"),
        titlepaddingbottom = getParam(box, "titlepaddingbottom"),
        valuepadding       = getParam(box, "valuepadding"),
        valuepaddingleft   = getParam(box, "valuepaddingleft"),
        valuepaddingright  = getParam(box, "valuepaddingright"),
        valuepaddingtop    = getParam(box, "valuepaddingtop"),
        valuepaddingbottom = getParam(box, "valuepaddingbottom"),
        font               = getParam(box, "font"),
    }
end

function render.paint(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    local c = box._cache or {}

    utils.box(
        x, y, w, h,
        c.title, c.displayValue, c.unit, c.bgcolor,
        c.titlealign, c.valuealign, c.titlecolor, c.titlepos, c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom, c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom, c.font, c.textcolor
    )
end

return render
