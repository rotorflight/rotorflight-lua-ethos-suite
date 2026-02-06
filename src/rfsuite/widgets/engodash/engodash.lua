--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local engodash = {}
local wakeupScheduler
local LCD_W, LCD_H

function engodash.create()
    return {layout=nil, armed=false}
end

function engodash.build(context)
    context.layout = glasses.createLayout({bitmap={id=10, x=10, y=10}, text={x=10, y=100}, border=true})
    context.armed = false
end

function engodash.wakeup(context)
    if context.layout ~= nil and context.armed == false then
        glasses.layoutClearAndDisplay(context.layout, "ARMED!")
        context.armed = true
    end
end

return {init=init}

engodash.title = false

return engodash
