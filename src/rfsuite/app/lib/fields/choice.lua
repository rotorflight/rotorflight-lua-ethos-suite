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

        local tbldata = f.table and app.utils.convertPageValueTable(f.table, f.tableIdxInc) or {}
        if f.tableEthos then
            tbldata = f.tableEthos
        end

        formFields[i] = form.addChoiceField(formLines[app.formLineCnt], posField, tbldata, function()
            local active = ui._guardField(fields, i)
            if not active then return nil end
            return app.utils.getFieldValue(active)
        end, function(value)
            ui.markPageDirty()
            if f.postEdit then f.postEdit(page, value) end
            if f.onChange then f.onChange(page, value) end
            f.value = app.utils.saveFieldValue(fields[i], value)
        end)

        if f.disable then formFields[i]:enable(false) end
    end
end
