local render = {}

function render.wakeup(box)
    local utils = rfsuite.widgets.dashboard.utils
    local getParam = utils.getParam
    local resolveColor = utils.resolveColor

    local displayValue = nil
    local totalSize = rfsuite.session.bblSize
    local usedSize = rfsuite.session.bblUsed
    if totalSize and usedSize then
        displayValue = string.format(
            "%.1f/%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"),
            usedSize / (1024 * 1024),
            totalSize / (1024 * 1024)
        )
    end
    if displayValue == nil then
        displayValue = getParam(box, "novalue") or "-"
    end

    box._cache = {
        displayValue       = displayValue,
        bgcolor            = resolveColor(getParam(box, "bgcolor")),
        textcolor          = resolveColor(getParam(box, "textcolor")),
        titlecolor         = resolveColor(getParam(box, "titlecolor")),
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
        unit               = nil,
    }
end

function render.paint(x, y, w, h, box)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)
    local c = box._cache or {}

    rfsuite.widgets.dashboard.utils.box(
        x, y, w, h,
        c.title, c.displayValue, c.unit, c.bgcolor,
        c.titlealign, c.valuealign, c.titlecolor, c.titlepos,
        c.titlepadding, c.titlepaddingleft, c.titlepaddingright,
        c.titlepaddingtop, c.titlepaddingbottom,
        c.valuepadding, c.valuepaddingleft, c.valuepaddingright,
        c.valuepaddingtop, c.valuepaddingbottom,
        c.font, c.textcolor
    )
end

return render
