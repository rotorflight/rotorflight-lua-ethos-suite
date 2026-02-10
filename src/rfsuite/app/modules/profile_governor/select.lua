--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local pidxLegacy
local titleLegacy


local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script

    if rfsuite.utils.apiVersionCompare(">=", "12.09") then
        rfsuite.app.ui.openPage({idx = pidx, title = title, script = "profile_governor/governor.lua"})
    else    
        pidxLegacy = pidx
        titleLegacy = title
    end

end

local function wakeup()
     if rfsuite.session.governorMode == nil then
        if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then
            rfsuite.tasks.msp.helpers.governorMode(function(governorMode)
                rfsuite.utils.log("Received governor mode: " .. tostring(governorMode), "info")
            end)
        end
    end

    if rfsuite.utils.apiVersionCompare("<", "12.09") and rfsuite.session.governorMode ~= nil then
        rfsuite.app.ui.openPage({idx = pidxLegacy, title = titleLegacy, script = "profile_governor/governor_legacy.lua"})
    end

end

return {pages = nil, openPage = openPage, event = nil, wakeup = wakeup}
