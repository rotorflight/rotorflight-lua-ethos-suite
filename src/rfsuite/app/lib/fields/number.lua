return function(ctx)
    local ui = ctx.ui
    local app = ctx.app
    local form = form
    local rfutils = ctx.rfutils

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

        formFields[i] = form.addNumberField(formLines[app.formLineCnt], posField, minValue, maxValue, function()
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

        if f.default then
            if f.offset then f.default = f.default + f.offset end
            local default = f.default * rfutils.decimalInc(f.decimals)
            if f.mult then default = default * f.mult end
            local str = tostring(default)
            if str:match("%.0$") then default = math.ceil(default) end
            currentField:default(default)
        else
            currentField:default(0)
        end

        if f.decimals then currentField:decimals(f.decimals) end
        if f.unit then currentField:suffix(f.unit) end
        if f.step then currentField:step(f.step) end
        if f.disable then currentField:enable(false) end

        if f.help or f.apikey then
            if not f.help and f.apikey then f.help = f.apikey end
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
