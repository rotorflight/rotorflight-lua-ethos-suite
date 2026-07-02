--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local wrapperFactory = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/wrapper_factory.lua"))()

return wrapperFactory.createObjectWrapper("dial", "image")
