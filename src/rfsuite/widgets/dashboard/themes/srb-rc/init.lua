--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")

local init = {name = "SRB-RC", preflight = "preflight.lua", inflight = "inflight.lua", postflight = "postflight.lua", configure = "configure.lua", standalone = false}

return init
