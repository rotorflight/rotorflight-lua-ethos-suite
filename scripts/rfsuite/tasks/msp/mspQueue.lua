--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] --
-- MspQueueController class
local MspQueueController = {}
MspQueueController.__index = MspQueueController

function MspQueueController.new()
    local DEFAULT_TIMEOUT = 2.0
    local self = setmetatable({}, MspQueueController)
    self.messageQueue = {}
    self.currentMessage = nil
    self.lastTimeCommandSent = nil
    self.retryCount = 0
    self.maxRetries = 3
    self.timeout = DEFAULT_TIMEOUT
    self.uuid = nil
    return self
end

function MspQueueController:isProcessed()
    return not self.currentMessage and #self.messageQueue == 0
end

local function popFirstElement(tbl)
    return table.remove(tbl, 1)
end

function MspQueueController:processQueue()
    if self:isProcessed() then
        rfsuite.app.triggers.mspBusy = false
        return
    end
    rfsuite.app.triggers.mspBusy = true

    if rfsuite.rssiSensor then
        local module = model.getModule(rfsuite.rssiSensor:module())
        if module and module.muteSensorLost then module:muteSensorLost(2.0) end
    end

    if not self.currentMessage then
        self.currentMessageStartTime = os.clock()
        self.currentMessage = popFirstElement(self.messageQueue)
        self.retryCount = 0
    end

    local lastTimeInterval = rfsuite.bg.msp.protocol.mspIntervalOveride or 1
    if lastTimeInterval == nil then lastTimeInterval = 1 end

    if not system:getVersion().simulation then
        if not self.lastTimeCommandSent or self.lastTimeCommandSent + lastTimeInterval < os.clock() then
            rfsuite.bg.msp.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload or {})
            self.lastTimeCommandSent = os.clock()
            self.currentMessageStartTime = os.clock()
            self.retryCount = self.retryCount + 1

            if rfsuite.app.Page and rfsuite.app.Page.mspRetry then rfsuite.app.Page.mspRetry(self) end
        end

        mspProcessTxQ()
        cmd, buf, err = mspPollReply()
    else
        if not self.currentMessage.simulatorResponse then
            rfsuite.utils.log("No simulator response for command " .. tostring(self.currentMessage.command),"debug")
            self.currentMessage = nil
            return
        end
        cmd, buf, err = self.currentMessage.command, self.currentMessage.simulatorResponse, nil
    end

    if self.currentMessage and os.clock() - self.currentMessageStartTime > (self.currentMessage.timeout or self.timeout) then
        if self.currentMessage.errorHandler then self.currentMessage:errorHandler() end
        rfsuite.utils.log("Message timeout exceeded. Flushing queue.","debug")
        self:clear()
        return
    end

    if cmd then
        self.lastTimeCommandSent = nil

        local logData = "Requesting: {" .. tostring(cmd) .. "}"
        rfsuite.utils.log(logData,"debug")

    end

    if (cmd == self.currentMessage.command and not err) or (self.currentMessage.command == 68 and self.retryCount == 2) or (self.currentMessage.command == 217 and err and self.retryCount == 2) then


            local logData = "Received: {" .. rfsuite.utils.joinTableItems(buf, ", ") .. "}"
            if #buf > 0 then rfsuite.utils.log(logData,"debug") end


        if self.currentMessage.processReply then self.currentMessage:processReply(buf) end
        self.currentMessage = nil

        if rfsuite.app.Page and rfsuite.app.Page.mspSuccess then rfsuite.app.Page.mspSuccess() end
    elseif self.retryCount > self.maxRetries then
        self.messageQueue = {}
        if self.currentMessage.errorHandler then self.currentMessage:errorHandler() end
        self:clear()

        if rfsuite.app.Page and rfsuite.app.Page.mspTimeout then rfsuite.app.Page.mspTimeout() end
    end
end

function MspQueueController:clear()
    self.messageQueue = {}
    self.currentMessage = nil
    self.uuid = {}
    mspClearTxBuf()
end

local function deepCopy(original)
    if type(original) == "table" then
        local copy = {}
        for key, value in next, original, nil do copy[key] = deepCopy(value) end
        return setmetatable(copy, getmetatable(original))
    else
        return original
    end
end

function MspQueueController:add(message)
    if not rfsuite.bg.telemetry.active() then return end
    if message then
        if message.uuid and self.uuid == message.uuid then
            rfsuite.utils.log("Skipping duplicate message with UUID " .. message.uuid,"debug")
            return
        end
        message = deepCopy(message)
        if message.uuid then self.uuid = message.uuid end
        rfsuite.utils.log("Queueing command " .. message.command .. " at position " .. #self.messageQueue + 1)
        self.messageQueue[#self.messageQueue + 1] = message
        return self
    else
        rfsuite.utils.log("Unable to queue - nil message.","debug")
    end
end

return MspQueueController.new()
