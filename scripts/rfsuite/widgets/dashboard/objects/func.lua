local render = {}


-- Function box
function render.func(x, y, w, h, box)

    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    local v = box.value
    if type(v) == "function" then
        -- In case someone set value = function() return actual_function end
        v = v(x, y, w, h) or v
        if type(v) == "function" then
            v(x, y, w, h)
        end
    end
end

return render