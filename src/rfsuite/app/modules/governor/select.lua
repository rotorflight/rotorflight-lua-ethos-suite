--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local function openPage(pidx, title, script)

    if rfsuite.utils.apiVersionCompare(">=", "12.09") then

        rfsuite.app.ui.openPage(pidx, title, "governor/governor.lua")
    else

        rfsuite.app.ui.openPage(pidx, title, "governor/governor_legacy.lua")
    end

end

return {pages = nil, openPage = openPage, event = nil, wakeup = nil}
