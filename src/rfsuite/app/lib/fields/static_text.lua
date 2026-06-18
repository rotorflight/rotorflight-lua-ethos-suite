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
        local radioText = app.radio.text

        local posField = ui._prepareFieldLine(f, radioText)
        local active = ui._guardField(fields, i)
        if not active then return end
        formFields[i] = form.addStaticText(formLines[app.formLineCnt], posField, app.utils.getFieldValue(active))

        local currentField = formFields[i]
        if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end
        if f.decimals then currentField:decimals(f.decimals) end
        if f.unit then currentField:suffix(f.unit) end
        if f.step then currentField:step(f.step) end
    end
end
