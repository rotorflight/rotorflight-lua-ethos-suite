--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local shortcuts = assert(loadfile("app/lib/shortcuts.lua"))()

local function getPages()
    local prefs = rfsuite.preferences and rfsuite.preferences.shortcuts or {}
    return shortcuts.buildSelectedPages(prefs)
end

return {getPages = getPages}
