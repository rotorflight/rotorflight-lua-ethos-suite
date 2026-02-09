--[[
    Copyright (C) 2026 Rotorflight Project
    GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local announceCraftname = {}

local taskComplete = false

function announceCraftname.wakeup()

    if taskComplete then return end

    taskComplete = true

    if not (rfsuite.preferences.events and rfsuite.preferences.events.otherModelAnnounce) then
        return
    end

    local craftName = rfsuite.session.craftName
    if not craftName or craftName == "" then return end

    -- Try exact match and underscore replacement for spaces
    local candidates = {"/audio/" .. craftName .. ".wav", "/audio/" .. string.gsub(craftName, " ", "_") .. ".wav"}

    for _, filename in ipairs(candidates) do
        local f = io.open(filename, "r")
        if f then
            io.close(f)
            system.playFile(filename)
            rfsuite.utils.log("Announcing craft name: " .. filename, "info")
            return
        end
    end
    rfsuite.utils.log("Craft announcement file not found for: " .. craftName, "info")
end

function announceCraftname.reset()
    taskComplete = false
end

function announceCraftname.isComplete()
    return taskComplete
end

return announceCraftname
