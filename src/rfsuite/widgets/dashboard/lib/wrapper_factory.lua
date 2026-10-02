--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

if package.loaded["rfsuite.widgets.dashboard.wrapper_factory"] then
    return package.loaded["rfsuite.widgets.dashboard.wrapper_factory"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local clock = os.clock
local utils = rfsuite.widgets.dashboard.utils
local LOAD_RETRY_SECONDS = 1.0

local factory = {}

-- Builds the standard paint/wakeup/dirty wrapper shared by all dashboard
-- object types (dial, gauge, text, image, time, navigation, func). Each
-- object type loads its subtype renderer on demand from its own folder.
function factory.createObjectWrapper(objectType, defaultSubtype)
    local wrapper = {}

    local renders = rfsuite.widgets.dashboard.renders
    local folder = "widgets/dashboard/objects/" .. objectType .. "/"
    local loadFailedAt = {}

    function wrapper.paint(x, y, w, h, box)
        local subtype = box.subtype or defaultSubtype
        local render = renders[subtype]
        if not render then return end
        render.paint(x, y, w, h, box)
    end

    function wrapper.wakeup(box)

        if not utils.isModelPrefsReady() then utils.resetBoxCache(box) end

        if box.wakeupinterval ~= nil then
            local now = clock()

            box._wakeupInterval = box._wakeupInterval or box.wakeupinterval

            -- The first call always runs: measured from 0, os.clock() can
            -- still be below the interval just after boot, which skipped a
            -- box's very first wakeup and left it with nothing to paint.
            if box._lastWakeup and now - box._lastWakeup < box._wakeupInterval then return end

            box._lastWakeup = now
        end

        local subtype = box.subtype or defaultSubtype

        -- `false` tells the engine this box was NOT woken (engine.lua's
        -- wakeOne()), so it keeps painting the box's placeholder shell and
        -- retries it, instead of painting a renderer that never built the
        -- box's cache -- an empty box until some later wake pass came round.
        -- Seen once on the first run after a deploy. A failed load is not
        -- retried for LOAD_RETRY_SECONDS, so a missing file cannot turn into a
        -- loadfile() on every tick.
        if not renders[subtype] then
            local failedAt = loadFailedAt[subtype]
            if failedAt and clock() - failedAt < LOAD_RETRY_SECONDS then return false end
            local path = folder .. subtype .. ".lua"
            local loader = loadfile(path)
            if not loader then
                loadFailedAt[subtype] = clock()
                return false
            end
            renders[subtype] = loader()
            loadFailedAt[subtype] = nil
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
end

package.loaded["rfsuite.widgets.dashboard.wrapper_factory"] = factory
return factory
