local wrapper = {}

local renders = rfsuite.widgets.dashboard.renders
local folder = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/objects/dial/"
local utils = rfsuite.widgets.dashboard.utils

function wrapper.paint(x, y, w, h, box)
    local subtype = box.subtype or "image"
    local render = renders[subtype]
    if not render then return end
    render.paint(x, y, w, h, box)
end

function wrapper.wakeup(box)

    -- Ensure model preferences and telemetry are available
    if not utils.isModelPrefsReady() then
        utils.resetBoxCache(box)
    end

    -- Wakeup interval control using optional parameter (wakeupinterval)
    if box.wakeupinterval ~= nil then
        local now      = os.clock()

        -- initialize on first use
        box._wakeupInterval = box._wakeupInterval
        box._lastWakeup     = box._lastWakeup     or 0

        -- if not enough time has passed, bail out
        if now - box._lastWakeup < box._wakeupInterval then
            return
        end

        -- record this wakeup
        box._lastWakeup = now
    end

    local subtype = box.subtype or "image"

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
    render.wakeup(box)
end

function wrapper.dirty(box)
    if not utils.isModelPrefsReady() then return false end
    local subtype = box.subtype or "flight"
    local render = renders[subtype]
    return render and render.dirty and render.dirty(box) or false
end

return wrapper
