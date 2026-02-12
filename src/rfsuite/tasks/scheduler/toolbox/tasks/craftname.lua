--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local craftname = {}

function craftname.wakeup()
    local session = rfsuite.session
    if not session then return end
    session.toolbox.craftname = session.craftName or model.name()
end

return craftname
