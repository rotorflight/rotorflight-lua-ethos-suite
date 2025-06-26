local wrapper = {}

local renders = {}
local folder = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/objects/image/"

function wrapper.paint(x, y, w, h, box)
    local subtype = box.subtype or "model"
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
    if box.wakeupinterval ~= nil then
        local now      = rfsuite.clock

        -- initialize on first use
        box._wakeupInterval = box._wakeupInterval or interval
        box._lastWakeup     = box._lastWakeup     or 0

        -- if not enough time has passed, bail out
        if now - box._lastWakeup < box._wakeupInterval then
            return
        end

        -- record this wakeup
        box._lastWakeup = now
    end   

    local subtype = box.subtype or "model"

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
