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
local lastQueueCount = 0
MspQueueController.__index = MspQueueController

--[[
    Creates a new instance of MspQueueController.
    
    @return A new MspQueueController instance.
    
    Fields:
    - messageQueue: A table to hold the messages in the queue.
    - currentMessage: The current message being processed.
    - lastTimeCommandSent: The timestamp of the last command sent.
    - retryCount: The number of retries attempted for the current message.
    - maxRetries: The maximum number of retries allowed for a message.
    - timeout: The timeout duration for a message (default is 2.0 seconds).
    - uuid: A unique identifier for the controller instance.
]]
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

--[[
Checks if the MSP queue has been processed.
@return boolean True if there are no current messages and the message queue is empty, false otherwise.
]]
function MspQueueController:isProcessed()
    return not self.currentMessage and #self.messageQueue == 0
end

--[[
    Removes and returns the first element from the given table.

    @param tbl (table): The table from which the first element will be removed.
    @return (any): The first element of the table, or nil if the table is empty.
]]
local function popFirstElement(tbl)
    return table.remove(tbl, 1)
end

--[[
    Processes the MSP (Multiwii Serial Protocol) message queue.
    
    This function handles the processing of messages in the MSP queue. It checks if the queue is already processed,
    manages the busy state, handles RSSI sensor muting, sends commands, processes replies, and handles timeouts and retries.
    
    Usage:
    - Call this function to process the next message in the MSP queue.
    - It will handle sending the command, waiting for a response, and processing the response or handling errors.
    
    Key Operations:
    - Checks if the queue is already processed and sets the busy state.
    - Mutes the RSSI sensor if available.
    - Sends the next command in the queue if the time interval has passed.
    - Processes the response or handles timeouts and retries.
    - Logs relevant information for debugging purposes.
    
    Note:
    - This function is part of the MspQueueController class.
    - It interacts with various components of the rfsuite application.
]]
function MspQueueController:processQueue()

    local mspBusyTimeout = 2.0
    self.mspBusyStart = self.mspBusyStart or os.clock()

    if rfsuite.preferences.developer.logmspQueue then
        local count = #self.messageQueue
        if count ~= lastQueueCount then
            rfsuite.utils.log("MSP Queue: " .. count .. " messages in queue","info")
            lastQueueCount = count
        end
    end

    if self:isProcessed() then
        rfsuite.app.triggers.mspBusy = false
        self.mspBusyStart = nil
        return
    end

    -- Timeout watchdog
    if self.mspBusyStart and (os.clock() - self.mspBusyStart) > mspBusyTimeout then
        rfsuite.utils.log("MSP busy timeout exceeded. Forcing clear.", "warn")
        rfsuite.app.triggers.mspBusy = false
        self.mspBusyStart = nil
        return
    end

    rfsuite.app.triggers.mspBusy = true    

    if rfsuite.session.telemetrySensor then
        local module = model.getModule(rfsuite.session.telemetrySensor:module())
        if module and module.muteSensorLost then module:muteSensorLost(2.0) end
    end

    if not self.currentMessage then
        self.currentMessageStartTime = os.clock()
        self.currentMessage = popFirstElement(self.messageQueue)
        self.retryCount = 0
    end

    local lastTimeInterval = rfsuite.tasks.msp.protocol.mspIntervalOveride or 1
    if lastTimeInterval == nil then lastTimeInterval = 1 end

    if not system:getVersion().simulation then
        -- we process on the actual radio
        if not self.lastTimeCommandSent or self.lastTimeCommandSent + lastTimeInterval < os.clock() then
            rfsuite.tasks.msp.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload or {})
            self.lastTimeCommandSent = os.clock()
            self.currentMessageStartTime = os.clock()
            self.retryCount = self.retryCount + 1

            if rfsuite.app.Page and rfsuite.app.Page.mspRetry then rfsuite.app.Page.mspRetry(self) end
        end

        rfsuite.tasks.msp.common.mspProcessTxQ()
        -- return the radio response
        cmd, buf, err = rfsuite.tasks.msp.common.mspPollReply()

        -- we dont log here - but later as this is 'polling'
        -- look further down in the script where we process the 
        -- cmd, buf, err commands

    else
        if not self.currentMessage.simulatorResponse then
            rfsuite.utils.log("No simulator response for command " .. tostring(self.currentMessage.command),"debug")
            self.currentMessage = nil
            self.uuid = nil -- Clear UUID after processing
            return
        end


        -- return the simulator response
        cmd, buf, err = self.currentMessage.command, self.currentMessage.simulatorResponse, nil

        if cmd then
            -- find state
            local rwState = (self.currentMessage.payload and #self.currentMessage.payload > 0) and "WRITE" or "READ"

            rfsuite.utils.logMsp(cmd, rwState, self.currentMessage.payload or buf, err)      
        end    
    end

    if self.currentMessage and os.clock() - self.currentMessageStartTime > (self.currentMessage.timeout or self.timeout) then
        if self.currentMessage.errorHandler then self.currentMessage:errorHandler() end
        rfsuite.utils.log("Message timeout exceeded. Flushing queue.","debug")
        self.currentMessage = nil
        self.uuid = nil
        return
    end

    if cmd then
        self.lastTimeCommandSent = nil
    end

    if (cmd == self.currentMessage.command and not err) or (self.currentMessage.command == 68 and self.retryCount == 2) or (self.currentMessage.command == 217 and err and self.retryCount == 2) then

        if self.currentMessage.processReply then 
            self.currentMessage:processReply(buf) 
            if cmd then
                -- we can do logging etc here as payload is now complete (real)
                local rwState = (self.currentMessage.payload and #self.currentMessage.payload > 0) and "WRITE" or "READ"
                rfsuite.utils.logMsp(cmd, rwState, self.currentMessage.payload or buf, err)
            end
        end
        self.currentMessage = nil
        self.uuid = nil -- Clear UUID after successful processing

        if rfsuite.app.Page and rfsuite.app.Page.mspSuccess then rfsuite.app.Page.mspSuccess() end
    elseif self.retryCount > self.maxRetries then
        self.messageQueue = {}
        if self.currentMessage.errorHandler then self.currentMessage:errorHandler() end
        self:clear()

        if rfsuite.app.Page and rfsuite.app.Page.mspTimeout then rfsuite.app.Page.mspTimeout() end
    end
end

--[[
    Clears the message queue and resets the current message and UUID.
    Also clears the MSP transmission buffer.
]]
function MspQueueController:clear()
    rfsuite.app.triggers.mspBusy = false
    self.mspBusyStart = nil    
    self.messageQueue = {}
    self.currentMessage = nil
    self.uuid = nil -- Ensure UUID is cleared when queue is cleared
    rfsuite.tasks.msp.common.mspClearTxBuf()
end

--[[
    Function: deepCopy
    Creates a deep copy of a given table. If the input is not a table, it returns the input as is.
    
    Parameters:
    original - The table to be deep copied.
    
    Returns:
    A new table that is a deep copy of the original table, or the original value if it is not a table.
]]
local function deepCopy(original)
    if type(original) == "table" then
        local copy = {}
        for key, value in next, original, nil do copy[key] = deepCopy(value) end
        return setmetatable(copy, getmetatable(original))
    else
        return original
    end
end

--[[
    Adds a message to the MSP queue if telemetry is active and the message is not a duplicate.
    
    @param message (table) The message to be added to the queue. The message should contain a 'command' field and optionally a 'uuid' field.
    
    @return (MspQueueController) Returns the MspQueueController instance if the message is successfully added to the queue.
    
    Logs:
    - "Skipping duplicate message with UUID <uuid>" if the message is a duplicate.
    - "Queueing command <command> at position <position>" when a message is successfully added to the queue.
    - "Unable to queue - nil message." if the message is nil.
]]
function MspQueueController:add(message)
    if not rfsuite.session.telemetryState then return end
    if message then
        if message.uuid and self.uuid == message.uuid then
            rfsuite.utils.log("Skipping duplicate message with UUID " .. message.uuid,"debug")
            return
        end
        message = deepCopy(message)
        if message.uuid then self.uuid = message.uuid end
        --rfsuite.utils.log("Queueing command " .. message.command .. " at position " .. #self.messageQueue + 1,"info")
        self.messageQueue[#self.messageQueue + 1] = message
        return self
    else
        rfsuite.utils.log("Unable to queue - nil message.","debug")
    end
end

return MspQueueController.new()
