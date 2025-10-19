--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local ini = {}

ini.api = assert(loadfile("tasks/ini/api.lua"))()

function ini.wakeup() end

function ini.reset() end

return ini
