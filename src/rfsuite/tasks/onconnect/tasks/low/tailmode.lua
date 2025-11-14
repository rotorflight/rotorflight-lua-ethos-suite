--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local tailmode = {}

local mspCallMade = false

function tailmode.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end

    if (rfsuite.session.tailMode == nil or rfsuite.session.swashMode == nil) and mspCallMade == false then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load("MIXER_CONFIG")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.tailMode = API.readValue("tail_rotor_mode")
            rfsuite.session.swashMode = API.readValue("swash_type")
            if rfsuite.session.tailMode and rfsuite.session.swashMode then
                rfsuite.utils.log("Tail mode: " .. rfsuite.session.tailMode, "info")
                rfsuite.utils.log("Swash mode: " .. rfsuite.session.swashMode, "info")
            end
        end)
        API.setUUID("fbccd634-c9b7-4b48-8c02-08ef560dc515")
        API.read()
    end

end

function tailmode.reset()
    rfsuite.session.tailMode = nil
    rfsuite.session.swashMode = nil
    mspCallMade = false
end

function tailmode.isComplete() if rfsuite.session.tailMode ~= nil and rfsuite.session.swashMode ~= nil then return true end end

return tailmode
