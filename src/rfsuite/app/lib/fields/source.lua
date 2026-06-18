return function(ctx)
    local ui = ctx.ui
    local app = ctx.app
    local form = form

    return function(i, lf)
        local page = app.Page
        local fields = page and page.apidata and page.apidata.formdata.fields or lf
        local f = fields[i]
        local formLines = app.formLines
        local formFields = app.formFields

        local posField = ui._prepareFieldLine(f)

        if f.offset then
            if f.min then f.min = f.min + f.offset end
            if f.max then f.max = f.max + f.offset end
        end

        local minValue = app.utils.scaleValue(f.min, f)
        local maxValue = app.utils.scaleValue(f.max, f)

        if f.mult then
            if minValue then minValue = minValue * f.mult end
            if maxValue then maxValue = maxValue * f.mult end
        end

        minValue = minValue or 0
        maxValue = maxValue or 0

        formFields[i] = form.addSourceField(formLines[app.formLineCnt], posField, function()
            local active = ui._guardField(fields, i)
            if not active then return nil end
            return app.utils.getFieldValue(active)
        end, function(value)
            ui.markPageDirty()
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(page.apidata.formdata.fields[i], value)
        end)

        local currentField = formFields[i]

        if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end
        if f.disable then currentField:enable(false) end
    end
end
