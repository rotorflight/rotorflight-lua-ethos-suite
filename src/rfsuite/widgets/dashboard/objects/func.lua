--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local clock = os.clock

local wrapper = {}

local renders = rfsuite.widgets.dashboard.renders
local folder = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/objects/func/"
local utils = rfsuite.widgets.dashboard.utils

function wrapper.paint(x, y, w, h, box)
    local subtype = box.subtype or "func"
    local render = renders[subtype]
    if not render then return end
    render.paint(x, y, w, h, box)
end

function wrapper.wakeup(box)

    if not utils.isModelPrefsReady() then utils.resetBoxCache(box) end

    if box.wakeupinterval ~= nil then
        local now = clock()

        box._wakeupInterval = box._wakeupInterval
        box._lastWakeup = box._lastWakeup or 0

        if now - box._lastWakeup < box._wakeupInterval then return end

        box._lastWakeup = now
    end

    local subtype = box.subtype or "func"

    if not renders[subtype] then
        local path = folder .. subtype .. ".lua"
        local loader = loadfile(path)
        if loader then
            renders[subtype] = loader()
        else
            return
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
