--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local M = {}

function M.queueApiWrite(apiName, uuid, values)
    local API = rfsuite.tasks.msp.api.loadPage(apiName)
    if not API then return false, "api_unavailable" end

    if uuid and API.setUUID then API.setUUID(uuid) end
    if values then
        for field, value in pairs(values) do
            API.setValue(field, value)
        end
    end

    return API.write()
end

function M.queueServoOverride(index, value, uuid)
    return M.queueApiWrite("SERVO_OVERRIDE", uuid, {
        servo_id = index,
        value = value
    })
end

function M.applyFlags(config)
    config.reverse = (config.flags == 1 or config.flags == 3) and 1 or 0
    config.geometry = (config.flags == 2 or config.flags == 3) and 1 or 0
end

function M.applyServoConfig(configs, servoTable, index, data)
    if not data then return false end

    local config = configs[index] or {}
    local row = servoTable and servoTable[index + 1]
    config.name = row and row.title or config.name
    config.mid = data.mid
    config.min = data.min
    config.max = data.max
    config.scaleNeg = data.rneg
    config.scalePos = data.rpos
    config.rate = data.rate
    config.speed = data.speed
    config.flags = data.flags
    M.applyFlags(config)
    configs[index] = config
    return true
end

function M.completeServoLoad(onEnableWakeup)
    if onEnableWakeup then onEnableWakeup() end

    local app = rfsuite.app
    local triggers = app and app.triggers
    if triggers then
        triggers.isReady = true
        triggers.closeProgressLoader = true
    end
    if app and app.ui and app.ui.setPageDirty then
        app.ui.setPageDirty(false)
    end
end

return M
