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

        formFields[i] = form.addTextField(formLines[app.formLineCnt], posField, function()
            local active = ui._guardField(fields, i)
            if not active then return nil end
            return app.utils.getFieldValue(active)
        end, function(value)
            ui.markPageDirty()
            if f.postEdit then f.postEdit(page) end
            if f.onChange then f.onChange(page) end
            f.value = app.utils.saveFieldValue(fields[i], value)
        end)

        local currentField = formFields[i]
        if f.onFocus then currentField:onFocus(function() f.onFocus(page) end) end
        if f.disable then currentField:enable(false) end

        if f.help then
            local fieldHelpTxt = ui.getFieldHelpTxt()
            if fieldHelpTxt and fieldHelpTxt[f.help] and fieldHelpTxt[f.help].t then currentField:help(fieldHelpTxt[f.help].t) end
        end

        if f.instantChange == false then
            currentField:enableInstantChange(false)
        else
            currentField:enableInstantChange(true)
        end
    end
end
