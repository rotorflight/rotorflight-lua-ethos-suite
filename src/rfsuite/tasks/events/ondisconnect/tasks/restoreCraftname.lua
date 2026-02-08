--[[
    Copyright (C) 2025 Rotorflight Project
    GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local restoreCraftname = {}

function restoreCraftname.wakeup()
    if rfsuite.session.originalModelName and model.name then
        rfsuite.utils.log("Restoring model name to: " .. rfsuite.session.originalModelName, "info")
        model.name(rfsuite.session.originalModelName)
        rfsuite.session.originalModelName = nil
        lcd.invalidate()
    end
end

return restoreCraftname
