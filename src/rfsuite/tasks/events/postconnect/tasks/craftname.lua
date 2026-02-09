--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local craftname = {}

local mspCallMade = false

function craftname.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end

    if (rfsuite.session.craftName == nil) and (mspCallMade == false) then
        mspCallMade = true
        local API = rfsuite.tasks.msp.api.load("NAME")
        API.setCompleteHandler(function(self, buf)
            rfsuite.session.craftName = API.readValue("name")
            if rfsuite.preferences.general.syncname == true and model.name and rfsuite.session.craftName ~= nil then
                if not rfsuite.session.originalModelName then
                    rfsuite.session.originalModelName = model.name()
                end
                rfsuite.utils.log("Setting model name to: " .. rfsuite.session.craftName, "info")
                model.name(rfsuite.session.craftName)
                lcd.invalidate()
            end
            if rfsuite.session.craftName and rfsuite.session.craftName ~= "" then
                rfsuite.utils.log("Craft name: " .. rfsuite.session.craftName, "info")
                rfsuite.utils.log("Craft name: " .. rfsuite.session.craftName, "connect")
            else
                rfsuite.session.craftName = model.name()
            end
        end)
        API.setUUID("37163617-1486-4886-8b81-6a1dd6d7edd1")
        API.read()
    end

end

function craftname.reset()
    rfsuite.session.craftName = nil
    mspCallMade = false
end

function craftname.isComplete() if rfsuite.session.craftName ~= nil then return true end end

return craftname
