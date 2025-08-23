--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * Optimized MspQueueController
 * - Lower CPU: no O(n) table.remove(1), optional loop throttling, tighter logging guards
 * - Lower RAM/GC: optional deep copy on add (off by default), queue nodes released ASAP
 *
 * Drop-in replacement for the original module API: new(), isProcessed(), processQueue(), clear(), add()
]] --

-- MspQueueController class
local MspQueueController = {}
MspQueueController.__index = MspQueueController

-- local module state
local lastQueueCount = 0

--============================--
-- Utilities
--============================--

-- Fast FIFO queue with head/tail indices (no shifting)
local function newQueue()
    return { first = 1, last = 0, data = {} }
end

local function qpush(q, v)
    q.last = q.last + 1
    q.data[q.last] = v
end

local function qpop(q)
    if q.first > q.last then return nil end
    local v = q.data[q.first]
    q.data[q.first] = nil -- release reference to help GC
    q.first = q.first + 1
    return v
end

local function qcount(q)
    return q.last - q.first + 1
end

-- Optional deep copy (used only if copyOnAdd=true)
local function deepCopy(original)
    if type(original) == "table" then
        local copy = {}
        for k, v in next, original do copy[k] = deepCopy(v) end
        return setmetatable(copy, getmetatable(original))
    else
        return original
    end
end

-- Safe logging guard
local function LOG_ENABLED_MSP()
    return rfsuite and rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.logmsp
end

local function LOG_ENABLED_MSP_QUEUE()
    return rfsuite and rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.logmspQueue
end

--============================--
-- Constructor
--============================--

--[[
    MspQueueController.new(opts)
    opts = {
      timeout = 2.0,            -- per-message timeout
      maxRetries = 3,           -- retries per message
      copyOnAdd = false,        -- deep-copy messages when enqueued (set true for strict isolation)
      loopInterval = 0,         -- throttle processQueue() to every N seconds (0 = no throttle)
    }
]]
function MspQueueController.new(opts)
    opts = opts or {}
    local self = setmetatable({}, MspQueueController)

    self.queue = newQueue()
    self.currentMessage = nil
    self.currentMessageStartTime = nil

    self.lastTimeCommandSent = nil
    self.retryCount = 0
    self.maxRetries = opts.maxRetries or 3
    self.timeout = opts.timeout or 2.0

    self.uuid = nil

    -- CPU controls
    self.loopInterval = opts.loopInterval or 0
    self._nextProcessAt = 0

    -- Memory controls
    self.copyOnAdd = opts.copyOnAdd == true

    -- MSP busy watchdog
    self.mspBusyStart = nil

    return self
end

--============================--
-- Public helpers
--============================--

function MspQueueController:queueCount()
    return qcount(self.queue)
end

function MspQueueController:isProcessed()
    return (self.currentMessage == nil) and (self:queueCount() == 0)
end

--============================--
-- Core processing
--============================--

function MspQueueController:processQueue()

    -- Optional loop throttling to reduce CPU when called from a hot loop
    if self.loopInterval and self.loopInterval > 0 then
        local now = os.clock()
        if now < self._nextProcessAt then return end
        self._nextProcessAt = now + self.loopInterval
    end

    local mspBusyTimeout = 2.0
    self.mspBusyStart = self.mspBusyStart or os.clock()

    -- lightweight, guarded logging
    if LOG_ENABLED_MSP_QUEUE() then
        local count = self:queueCount()
        if count ~= lastQueueCount then
            rfsuite.utils.log("MSP Queue: " .. count .. " messages in queue", "info")
            lastQueueCount = count
        end
    end

    if self:isProcessed() then
        rfsuite.app.triggers.mspBusy = false
        self.mspBusyStart = nil
        return
    end

    -- Timeout watchdog for global MSP busy state
    if self.mspBusyStart and (os.clock() - self.mspBusyStart) > mspBusyTimeout then
        rfsuite.utils.log("MSP busy timeout exceeded. Forcing clear.", "warn")
        rfsuite.app.triggers.mspBusy = false
        self.mspBusyStart = nil
        return
    end

    rfsuite.app.triggers.mspBusy = true

    if rfsuite.session.telemetryModule then
        local module = rfsuite.session.telemetryModule
        if module and module.muteSensorLost then module:muteSensorLost(2.0) end
    end

    -- Load a new current message if needed
    if not self.currentMessage then
        self.currentMessageStartTime = os.clock()
        self.currentMessage = qpop(self.queue)
        self.retryCount = 0
    end

    local cmd, buf, err

    -- Sending cadence controlled by protocol override or default 1s
    local lastTimeInterval = rfsuite.tasks.msp.protocol.mspIntervalOveride or 1
    if lastTimeInterval == nil then lastTimeInterval = 1 end

    if not system:getVersion().simulation then
        -- On real radio: send command only after interval
        if (not self.lastTimeCommandSent) or (self.lastTimeCommandSent + lastTimeInterval < os.clock()) then
            rfsuite.tasks.msp.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload or {})
            self.lastTimeCommandSent = os.clock()
            self.currentMessageStartTime = self.lastTimeCommandSent
            self.retryCount = self.retryCount + 1
            if rfsuite.app.Page and rfsuite.app.Page.mspRetry then rfsuite.app.Page.mspRetry(self) end
        end

        rfsuite.tasks.msp.common.mspProcessTxQ()
        cmd, buf, err = rfsuite.tasks.msp.common.mspPollReply()
        -- defer logging until payload complete
    else
        -- Simulator path
        if not self.currentMessage.simulatorResponse then
            if LOG_ENABLED_MSP() then
                rfsuite.utils.log("No simulator response for command " .. tostring(self.currentMessage.command), "debug")
            end
            self.currentMessage = nil
            self.uuid = nil
            return
        end
        cmd, buf, err = self.currentMessage.command, self.currentMessage.simulatorResponse, nil
        if cmd then
            local rwState = (self.currentMessage.payload and #self.currentMessage.payload > 0) and "WRITE" or "READ"
            if LOG_ENABLED_MSP() then rfsuite.utils.logMsp(cmd, rwState, self.currentMessage.payload or buf, err) end
        end
    end

    -- Per-message timeout
    if self.currentMessage and (os.clock() - self.currentMessageStartTime) > (self.currentMessage.timeout or self.timeout) then
        if self.currentMessage.errorHandler then self.currentMessage:errorHandler() end
        if LOG_ENABLED_MSP() then rfsuite.utils.log("Message timeout exceeded. Flushing queue.", "debug") end
        self.currentMessage = nil
        self.uuid = nil
        return
    end

    if cmd then
        self.lastTimeCommandSent = nil
    end

    -- Success conditions (retain original special-cases for 68 and 217)
    if (cmd == self.currentMessage.command and not err)
        or (self.currentMessage.command == 68 and self.retryCount == 2)
        or (self.currentMessage.command == 217 and err and self.retryCount == 2) then

        if self.currentMessage.processReply then
            self.currentMessage:processReply(buf)
            if cmd and LOG_ENABLED_MSP() then
                local rwState = (self.currentMessage.payload and #self.currentMessage.payload > 0) and "WRITE" or "READ"
                rfsuite.utils.logMsp(cmd, rwState, self.currentMessage.payload or buf, err)
            end
        end
        self.currentMessage = nil
        self.uuid = nil
        if rfsuite.app.Page and rfsuite.app.Page.mspSuccess then rfsuite.app.Page.mspSuccess() end
    elseif self.retryCount > self.maxRetries then
        -- Hard failure: clear queue and notify
        self:clear()
        if self.currentMessage and self.currentMessage.errorHandler then self.currentMessage:errorHandler() end
        if rfsuite.app.Page and rfsuite.app.Page.mspTimeout then rfsuite.app.Page.mspTimeout() end
    end
end

--============================--
-- Control
--============================--

function MspQueueController:clear()
    rfsuite.app.triggers.mspBusy = false
    self.mspBusyStart = nil
    -- Reset FIFO quickly
    self.queue = newQueue()
    self.currentMessage = nil
    self.uuid = nil
    rfsuite.tasks.msp.common.mspClearTxBuf()
end

--============================--
-- Enqueue
--============================--

--[[
    Adds a message to the MSP queue if telemetry is active and the message is not a duplicate UUID.
    When copyOnAdd=true (constructor option), a deep copy is made to isolate the queued message from external mutations.
]]
function MspQueueController:add(message)
    if not rfsuite.session.telemetryState then return end
    if not message then
        if LOG_ENABLED_MSP() then rfsuite.utils.log("Unable to queue - nil message.", "debug") end
        return
    end

    if message.uuid and self.uuid == message.uuid then
        if LOG_ENABLED_MSP() then rfsuite.utils.log("Skipping duplicate message with UUID " .. message.uuid, "debug") end
        return
    end

    if message.uuid then self.uuid = message.uuid end

    local toQueue = self.copyOnAdd and deepCopy(message) or message
    qpush(self.queue, toQueue)
    return self
end

return MspQueueController.new()
