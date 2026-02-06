--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local engodash = {}

function engodash.create()
    return {}
end

function engodash.build(context)
    context.layout = glasses.createLayout({bitmap={id=10, x=10, y=10}, text={x=10, y=100}, border=true})
end

function engodash.wakeup(context)

        glasses.layoutClearAndDisplay(context.layout, "ROTORFLIGHT")
        context.armed = true
end


return engodash
