local render = {}

function render.wakeup(box, telemetry)
    -- If the user has provided a custom wakeup function, call it.
    -- Save any results in box._cache so paint can access.
    if type(box.wakeup) == "function" then
        -- Provide telemetry for advanced use
        box._cache = box.wakeup(box, telemetry)
    end
end

function render.paint(x, y, w, h, box, telemetry)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    -- Pass the cache (from wakeup) to the user's function, if present
    local v = box.paint
    if type(v) == "function" then
        -- Pass x, y, w, h, box, cache, telemetry
        v(x, y, w, h, box, box._cache, telemetry)
    end
end

return render
