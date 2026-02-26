--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local clocksync = {}

function clocksync.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end

    if rfsuite.session.clockSet == nil then

        local API = rfsuite.tasks.msp.api.load("RTC", 1)
        if API and API.enableDeltaCache then API.enableDeltaCache(false) end
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.clockSet = true
            rfsuite.utils.log("Sync clock: " .. os.date("%c"), "info")
            rfsuite.utils.log("Sync clock: " .. os.date("%c"), "connect")
        end)
        API.setUUID("eaeb0028-219b-4cec-9f57-3c7f74dd49ac")
        API.setValue("seconds", os.time())
        API.setValue("milliseconds", 0)
        API.write()
    end

end

function clocksync.reset() rfsuite.session.clockSet = nil end

function clocksync.isComplete() if rfsuite.session.clockSet ~= nil then return true end end

return clocksync
