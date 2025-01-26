--[[

 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 *
 * Usage Example:
 * ---------------------------
 * local function servoCenterFocusOn(self)
 *     local message = {
 *         command = 193, -- MSP_SET_SERVO_OVERRIDE
 *         payload = {servoIndex},
 *         uuid = os.time() -- Unique identifier to prevent duplicate messages (time is not a good one - may be use a uuid)
 *     }
 *     rfsuite.bg.msp.mspHelper.writeU16(message.payload, 0)
 *     rfsuite.bg.msp.mspQueue:add(message)
 *     rfsuite.app.triggers.isReady = true
 *     rfsuite.app.triggers.closeProgressLoader = true
 * end
]] --


-- MspQueueController class
local MspQueueController = {}
MspQueueController.__index = MspQueueController

function MspQueueController.new()
    local self = setmetatable({}, MspQueueController)
    self.messageQueue = {}
    self.currentMessage = nil
    self.lastTimeCommandSent = nil
    self.retryCount = 0
    self.maxRetries = rfsuite.config.maxRetries or 3
    self.messageTimestamps = {}
    return self
end

function MspQueueController:isProcessed()
    return not self.currentMessage and #self.messageQueue == 0
end

function MspQueueController:processQueue()
    if self:isProcessed() then
        rfsuite.app.triggers.mspBusy = false
        return
    end
    rfsuite.app.triggers.mspBusy = true

    if rfsuite.rssiSensor then
        local module = model.getModule(rfsuite.rssiSensor:module())
        if module and module.muteSensorLost then
            module:muteSensorLost(2.0) -- mute for 2s
        end
    end

    self:checkMessageDelays()

    if not self.currentMessage then
        self.currentMessage = table.remove(self.messageQueue, 1)
        self.retryCount = 0
    end

    local lastTimeInterval = rfsuite.bg.msp.protocol.mspIntervalOverride or 1
    if lastTimeInterval == nil then lastTimeInterval = 1 end

    if not system:getVersion().simulation then
        if not self.lastTimeCommandSent or self.lastTimeCommandSent + lastTimeInterval < os.clock() then
            self:sendCurrentMessage()
        end

        mspProcessTxQ()
        local cmd, buf, err = mspPollReply()
        self:handleReply(cmd, buf, err)
    else
        self:simulateResponse()
    end
end

function MspQueueController:sendCurrentMessage()
    if self.currentMessage.payload then
        rfsuite.bg.msp.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload)
    else
        rfsuite.bg.msp.protocol.mspWrite(self.currentMessage.command, {})
    end
    self.lastTimeCommandSent = os.clock()
    self.retryCount = self.retryCount + 1
    if rfsuite.app.Page and rfsuite.app.Page.mspRetry then
        rfsuite.app.Page.mspRetry(self)
    end
end

function MspQueueController:handleReply(cmd, buf, err)
    if cmd then
        self.lastTimeCommandSent = nil
        if self.currentMessage.command == cmd and not err then
            if self.currentMessage.processReply then
                self.currentMessage:processReply(buf)
            end
            self.currentMessage = nil
        elseif self.retryCount > self.maxRetries then
            self.messageQueue = {}
            if self.currentMessage.errorHandler then
                self.currentMessage:errorHandler()
            end
            self:clear()
        end
    end
end

function MspQueueController:simulateResponse()
    if not self.currentMessage.simulatorResponse then
        rfsuite.utils.log("No simulator response for command " .. tostring(self.currentMessage.command))
        self.currentMessage = nil
        return
    end
    self:handleReply(self.currentMessage.command, self.currentMessage.simulatorResponse, nil)
end

function MspQueueController:clear()
    self.messageQueue = {}
    self.currentMessage = nil
    self.messageTimestamps = {}
    mspClearTxBuf()
end

function MspQueueController:add(message)
    if not rfsuite.bg.telemetry.active() then return end

    if message and message.uuid then
        if self:hasUUID(message.uuid) then
            rfsuite.utils.log("Message with UUID " .. message.uuid .. " already exists in the queue. Skipping.")
            return
        end
    end

    if message then
        local copiedMessage = self:deepCopy(message)
        table.insert(self.messageQueue, copiedMessage)
        self.messageTimestamps[#self.messageQueue] = os.clock()
    else
        rfsuite.utils.log("Unable to queue - nil message. Check function is callable")
    end
end

function MspQueueController:hasUUID(uuid)
    for _, msg in ipairs(self.messageQueue) do
        if msg.uuid == uuid then
            return true
        end
    end
    return false
end

function MspQueueController:checkMessageDelays()
    local currentTime = os.clock()
    for i = #self.messageQueue, 1, -1 do
        if currentTime - self.messageTimestamps[i] > 1 then  -- Timeout set to 1 second
            table.remove(self.messageQueue, i)
            table.remove(self.messageTimestamps, i)
        end
    end
end

function MspQueueController:deepCopy(original)
    if type(original) == "table" then
        local copy = {}
        for key, value in pairs(original) do
            copy[key] = self:deepCopy(value)
        end
        return copy
    else
        return original
    end
end

return MspQueueController.new()
