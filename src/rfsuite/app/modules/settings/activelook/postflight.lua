--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local modePage = assert(loadfile("app/modules/settings/activelook/mode.lua"))()

return modePage.create("postflight", "Postflight")
