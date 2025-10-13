--[[
    Custom Function Widget
    Configurable Arguments (box table keys):
    ----------------------------------------
    wakeupinterval    : number   -- Optional wakeup interval in seconds (set in wrapper)
    wakeup            : function   -- Custom wakeup function, called with (box, telemetry), should return a table to cache
    paint             : function   -- Custom paint function, called with (x, y, w, h, box, cache, telemetry)

    -- Note: This widget does not process colors, layout, or padding. All rendering and caching logic must be handled in the user's custom functions.
]]
local rfsuite = require("rfsuite") 

local render = {}

local utils = rfsuite.widgets.dashboard.utils

function render.dirty(box)
    return true -- Always dirty, since the user-defined functions can change at any time
end


function render.wakeup(box)

    local telemetry = rfsuite.tasks.telemetry

    if type(box.wakeup) == "function" then
        box._cache = box.wakeup(box, telemetry)
    else
        box._cache = nil
    end
end

function render.paint(x, y, w, h, box, telemetry)
    x, y = utils.applyOffset(x, y, box)
    local v = box.paint
    if type(v) == "function" then
        v(x, y, w, h, box, box._cache, telemetry)
    end
end

return render
