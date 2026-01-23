--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local craftname = {}

function craftname.wakeup() rfsuite.session.toolbox.craftname = rfsuite.session.craftName or model.name() end

return craftname
