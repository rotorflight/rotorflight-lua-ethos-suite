return function(ctx)
    local ui = ctx.ui
    local app = ctx.app

    return function(i, lf)
        local page = app.Page
        local fields = page and page.apidata and page.apidata.formdata.fields or lf
        local f = fields and fields[i] or nil
        local prevSubtype = f and f.subtype or nil
        if f then f.subtype = 1 end
        ui.fieldBoolean(i, lf)
        if f then f.subtype = prevSubtype end
    end
end
