--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local governor = {}

local mspCallMade = false

function governor.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end

    if (rfsuite.session.governorMode == nil and mspCallMade == false) then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local governorMode = API.readValue("gov_mode")
            if governorMode then rfsuite.utils.log("Governor mode: " .. governorMode, "info") end
            rfsuite.session.governorMode = governorMode
        end)
        API.setUUID("e2a1c5b3-7f4a-4c8e-9d2a-3b6f8e2d9a1c")
        API.read()
    end
end

function governor.reset()
    rfsuite.session.governorMode = nil
    mspCallMade = false
end

function governor.isComplete() if rfsuite.session.governorMode ~= nil then return true end end

return governor
