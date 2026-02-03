--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


-- Optimized locals to reduce global/table lookups
local os_clock = os.clock
local utils = rfsuite.utils
local math_max = math.max
local MspQueueController = {}
MspQueueController.__index = MspQueueController

local lastQueueCount = 0 -- for queue size logging

-- Queue primitives
local function newQueue() return {first = 1, last = 0, data = {}} end
local function qpush(q, v) q.last = q.last + 1; q.data[q.last] = v end
local function qpop(q)
    if q.first > q.last then return nil end
    local v = q.data[q.first]
    q.data[q.first] = nil
    q.first = q.first + 1
    return v
end
local function qcount(q) return q.last - q.first + 1 end

-- Shallow/array clone helpers
local function cloneArray(src)
    local dst = {}
    for i = 1, #src do dst[i] = src[i] end
    return setmetatable(dst, getmetatable(src))
end
local function shallowClone(src)
    local dst = {}
    for k, v in pairs(src) do dst[k] = v end
    return setmetatable(dst, getmetatable(src))
end
local function cloneMessage(msg) -- Clone message (deep clones payload)
    local out = {}
    for k, v in pairs(msg) do
        if k == "payload" and type(v) == "table" then
            out[k] = cloneArray(v)
        elseif k == "simulatorResponse" then
            out[k] = v
        elseif type(v) == "table" then
            out[k] = shallowClone(v)
        else
            out[k] = v
        end
    end
    return setmetatable(out, getmetatable(msg))
end

-- Logging toggles
local function LOG_ENABLED_MSP() return rfsuite and rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.logmsp end
local function LOG_ENABLED_MSP_QUEUE() return rfsuite and rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.logmspQueue end

-- Create a controller instance
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

    self.uuid = nil -- last processed UUID
    self.apiname = nil -- last processed API name

    -- Inter-message delay (gap between *completed* messages)
    self.interMessageDelay = opts.interMessageDelay or 0
    self._nextMessageAt = 0

    -- Optional loop throttle (kept for backwards-compat, but only gates starting the next message)
    self.loopInterval = opts.loopInterval or 0
    self._nextProcessAt = 0

    self.copyOnAdd = opts.copyOnAdd == true -- optionally copy on enqueue

    self.mspBusyStart = nil -- watchdog start

    return self
end

-- Queue helpers
function MspQueueController:queueCount() return qcount(self.queue) end
function MspQueueController:isProcessed() return (self.currentMessage == nil) and (self:queueCount() == 0) end

-- Main queue processor (send, retry, handle replies)
function MspQueueController:processQueue()

    local now = os_clock()

    -- MSP busy watchdog
    local mspBusyTimeout = 2.5

    if LOG_ENABLED_MSP_QUEUE() then
        local count = self:queueCount()
        if count ~= lastQueueCount then
            utils.log("MSP Queue: " .. count .. " messages in queue", "info")
            lastQueueCount = count
        end
    end

    -- Nothing to do
    if self:isProcessed() then
        rfsuite.session.mspBusy = false
        self.mspBusyStart = nil
        return
    end

    -- Watchdog: MSP stuck too long
    if self.mspBusyStart and (os_clock() - self.mspBusyStart) > mspBusyTimeout then
        --utils.log("MSP busy for more than " .. mspBusyTimeout .. " seconds", "info")
        --utils.log(" - Unblocking by setting rfsuite.session.mspBusy = false", "info")
        rfsuite.session.mspBusy = false
        self.mspBusyStart = nil
        return
    end

    -- Get next message if idle (optionally wait before advancing)
    if not self.currentMessage then
        -- Inter-message gap (after a message completes/fails)
        if self.interMessageDelay and self.interMessageDelay > 0 then
            if now < (self._nextMessageAt or 0) then
                rfsuite.session.mspBusy = false
                self.mspBusyStart = nil
                return
            end
        end

        -- Legacy loop throttle, but only gates starting the next message
        if self.loopInterval and self.loopInterval > 0 then
            if now < (self._nextProcessAt or 0) then
                rfsuite.session.mspBusy = false
                self.mspBusyStart = nil
                return
            end
            self._nextProcessAt = now + self.loopInterval
        end

        self.currentMessageStartTime = now
        self.currentMessage = qpop(self.queue)
        self.retryCount = 0
    end

    -- We are now genuinely active (either working a current message or about to send one)
    rfsuite.session.mspBusy = true
    self.mspBusyStart = self.mspBusyStart or now

    utils.muteSensorLostWarnings() -- Avoid sensor warnings during MSP    

    local cmd, buf, err
    local lastTimeInterval = rfsuite.tasks.msp.protocol.mspIntervalOveride or 0.25
    if lastTimeInterval == nil then lastTimeInterval = 1 end

    if not system:getVersion().simulation then
        -- Real MSP: send if interval allows
        if (not self.lastTimeCommandSent) or (self.lastTimeCommandSent + lastTimeInterval < os_clock()) then
            if self.currentMessage then        
                local sent = rfsuite.tasks.msp.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload or {})
                if sent then
                    self.lastTimeCommandSent = os_clock()
                    self.currentMessageStartTime = self.lastTimeCommandSent
                    self.retryCount = self.retryCount + 1
                end
                if rfsuite.app.Page and rfsuite.app.Page.mspRetry then rfsuite.app.Page.mspRetry(self) end
            end
        end

        -- Pump TX 
        rfsuite.tasks.msp.common.mspProcessTxQ()

        -- Poll for reply
        local ok, a, b, c = pcall(rfsuite.tasks.msp.common.mspPollReply)
        if ok then
            cmd, buf, err = a, b, c
        else
            if LOG_ENABLED_MSP() then
                utils.log("mspPollReply error: " .. tostring(a), "info")
            end
            -- back off a little so we don't hammer the same fault every frame
            self._nextMessageAt = os_clock() + 0.05
            return
        end
    else
        -- Simulator mode: use provided simulatorResponse
        if not self.currentMessage.simulatorResponse then
            if LOG_ENABLED_MSP() then utils.log("No simulator response for command " .. tostring(self.currentMessage.command), "debug") end
            self.currentMessage = nil
            self.uuid = nil
            self.apiname = nil 
            return
        end
        cmd, buf, err = self.currentMessage.command, self.currentMessage.simulatorResponse, nil
    end

    -- Per-message timeout
    if self.currentMessage and (os_clock() - self.currentMessageStartTime) > (self.currentMessage.timeout or self.timeout) then
        if self.currentMessage.setErrorHandler then self.currentMessage:setErrorHandler() end
        if LOG_ENABLED_MSP() then utils.log("Message timeout exceeded. Flushing queue.", "debug") end
        self.currentMessage = nil
        self.uuid = nil
        self.apiname = nil
        if self.interMessageDelay and self.interMessageDelay > 0 then
            self._nextMessageAt = os_clock() + self.interMessageDelay
        end
        return
    end

    if cmd then self.lastTimeCommandSent = nil end -- allow next send

    -- Success paths (or special-case shortcuts)
    if (cmd == self.currentMessage.command and not err)
        or (self.currentMessage.command == 68 and self.retryCount == 2)
        or (self.currentMessage.command == 217 and err and self.retryCount == 2) then

        if self.currentMessage.processReply then
            self.currentMessage:processReply(buf)
            if cmd and LOG_ENABLED_MSP() then
                local rwState
                if self.currentMessage.isWrite ~= nil then
                    rwState = self.currentMessage.isWrite and "WRITE" or "READ"
                else
                    -- legacy heuristic
                    rwState = (self.currentMessage.payload and #self.currentMessage.payload > 0) and "WRITE" or "READ"
                end
                local logPayload
                if rwState == "READ" then
                    logPayload = buf
                else
                    logPayload = self.currentMessage.payload
                end

                local logPayload
                if rwState == "WRITE" then
                    logPayload = self.currentMessage.payload
                else
                    local tx = self.currentMessage.payload
                    if tx and #tx > 0 then
                        logPayload = {}
                        -- TX bytes first
                        for i = 1, #tx do logPayload[#logPayload + 1] = tx[i] end
                        -- separator (non-byte) for readability; logMsp should print it as-is
                        logPayload[#logPayload + 1] = "|"
                        -- RX bytes second
                        for i = 1, #(buf or {}) do logPayload[#logPayload + 1] = buf[i] end
                    else
                        logPayload = buf
                    end
                end

                utils.logMsp(cmd, rwState, logPayload, err)
            end
        end
        self.currentMessage = nil
        self.uuid = nil
        self.apiname = nil
        if self.interMessageDelay and self.interMessageDelay > 0 then
            self._nextMessageAt = os_clock() + self.interMessageDelay
        end        
        if rfsuite.app.Page and rfsuite.app.Page.mspSuccess then rfsuite.app.Page.mspSuccess() end

    -- Too many retries → reset
    elseif self.retryCount > self.maxRetries then
        self:clear()
        if self.currentMessage and self.currentMessage.setErrorHandler then self.currentMessage:setErrorHandler() end
        if rfsuite.app.Page and rfsuite.app.Page.mspTimeout then rfsuite.app.Page.mspTimeout() end
    end
end

-- Reset queue + MSP state
function MspQueueController:clear()
    rfsuite.session.mspBusy = false
    self.mspBusyStart = nil
    self.queue = newQueue()
    self.currentMessage = nil
    self._nextMessageAt = 0
    self.uuid = nil
    self.apiname = nil
    rfsuite.tasks.msp.common.mspClearTxBuf()
end

-- Add message to queue (skip duplicate UUIDs; optional clone)
function MspQueueController:add(message)
    if not rfsuite.session.telemetryState then return end
    if not message then
        if LOG_ENABLED_MSP() then utils.log("Unable to queue - nil message.", "debug") end
        return
    end
    -- allow apiname to distinguish otherwise identical MSP calls
    local key = message.uuid
    if message.apiname then
        key = (key or "") .. ":" .. message.apiname
    end

    if key and self.uuid == key then
        if LOG_ENABLED_MSP() then utils.log("Skipping duplicate message with key " .. key, "info") end
        return
    end
    if key then self.uuid = key end
    local toQueue = self.copyOnAdd and cloneMessage(message) or message
    qpush(self.queue, toQueue)
    return self
end

-- Estimate byte cost of pending messages
function MspQueueController:pendingByteCost()
    local total = 0
    local function add(msg)
        if not msg then return end
        local rx = msg.minBytes or 0
        local tx = (msg.payload and #msg.payload) or 0
        total = total + math_max(rx, tx)
    end
    add(self.currentMessage)
    for i = self.queue.first, self.queue.last do add(self.queue.data[i]) end
    return total
end

return MspQueueController.new()
