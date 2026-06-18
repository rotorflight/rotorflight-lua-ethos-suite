return function(ctx)
    local ui = ctx.ui
    local app = ctx.app
    local form = form

    return function(i, lf)
        local page = app.Page
        local fields = page and page.apidata and page.apidata.formdata.fields or lf
        local f = ui._guardField(fields, i)
        local formLines = app.formLines
        local formFields = app.formFields
        local radioText = app.radio.text

        if not f then return end

        local invert = (f.subtype == 1)
        local posField = ui._prepareFieldLine(f, radioText)

        local function decode()
            local active = ui._guardField(fields, i)
            if not active then return nil end
            local v = (active.value == 1) and 1 or 0
            if invert then v = (v == 1) and 0 or 1 end
            return (v == 1)
        end

        local function encode(b)
            local v = b and 1 or 0
            if invert then v = (v == 1) and 0 or 1 end
            return v
        end

        formFields[i] = form.addBooleanField(formLines[app.formLineCnt], posField, function() return decode() end, function(valueBool)
            ui.markPageDirty()
            local value = encode(valueBool == true)
            if f.postEdit then f.postEdit(page, value) end
            if f.onChange then f.onChange(page, value) end
            f.value = app.utils.saveFieldValue(fields[i], value)
        end)

        if f.disable then formFields[i]:enable(false) end
    end
end
