local wrapper = {}

local renders = {}
local folder = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/objects/time/"

function wrapper.paint(x, y, w, h, box)
    local subtype = box.subtype or "flight"
    local render = renders[subtype]
    if not render then return end
    render.paint(x, y, w, h, box)
end

function wrapper.wakeup(box, telemetry)

    -- Ensure telemetry is available
    if not telemetry then
        return
    end

    -- Wakeup interval control using optional parameter (wakeupinterval)
    local now = rfsuite.clock
    box._wakeupInterval = box._wakeupInterval or (box.wakeupinterval or 0.025)
    box._lastWakeup = box._lastWakeup or 0

    if now - box._lastWakeup < box._wakeupInterval then
        return -- Throttle wakeup
    end      

    local subtype = box.subtype or "flight"

    if not renders[subtype] then
        local path = folder .. subtype .. ".lua"
        local loader = rfsuite.compiler.loadfile(path)
        if loader then
            renders[subtype] = loader()
        else
            return -- silently fail or log error
        end
    end

    local render = renders[subtype]
    render.wakeup(box, telemetry)
end

function wrapper.dirty(box)
    local subtype = box.subtype or "flight"
    local render = renders[subtype]
    return render and render.dirty and render.dirty(box) or false
end

return wrapper
