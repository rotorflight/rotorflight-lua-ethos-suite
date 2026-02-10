--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script

    if rfsuite.utils.apiVersionCompare(">=", "12.09") then

        rfsuite.app.ui.openPage({idx = pidx, title = title, script = "governor/governor.lua"})
    else

        rfsuite.app.ui.openPage({idx = pidx, title = title, script = "governor/governor_legacy.lua"})
    end

end

return {pages = nil, openPage = openPage, event = nil, wakeup = nil}
