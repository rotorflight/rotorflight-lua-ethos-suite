--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


-- Optimized locals to reduce global/table lookups
local os_clock = os.clock
local utils = rfsuite.utils
local math_max = math.max
local DEFAULT_RETRY_BACKOFF_SECONDS = 1
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

-- Lightweight status updates for UI progress loaders.
local function setMspStatus(message)
    if not rfsuite or not rfsuite.session then return end
    if rfsuite.session.mspStatusMessage ~= message then
        rfsuite.session.mspStatusMessage = message
        rfsuite.session.mspStatusUpdatedAt = os_clock()
        if message then
            rfsuite.session.mspStatusLast = message
            rfsuite.session.mspStatusClearAt = nil
        end
        if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.updateProgressDialogMessage then
            rfsuite.app.ui.updateProgressDialogMessage(message)
        end
        if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.applyMspStatusToActiveDialogs then
            rfsuite.app.ui.applyMspStatusToActiveDialogs(message)
        end
    end
end

local function formatMspStatus(msg, suffix)
    if not msg then return nil end
    local rw
    if msg.isWrite ~= nil then
        rw = msg.isWrite and "WRITE" or "READ"
    else
        rw = (msg.payload and #msg.payload > 0) and "WRITE" or "READ"
    end
    local cmd = msg.command
    local head = "MSP " .. (rw == "WRITE" and "W" or "R")
    if cmd ~= nil then head = head .. " " .. tostring(cmd) end
    if suffix and suffix ~= "" then return head .. " " .. suffix end
    return head
end


-- Drain duplicate/late replies for the same command for a brief window after success.
-- This reduces "spillover" where a late duplicate reply (from an earlier resend) is consumed by the next message.
local function drainAfterSuccess(self, cmd)
    if not cmd then return end
    local drainMs = self.drainAfterReplyMs or 0
    if drainMs <= 0 then return end

    local start = os_clock()
    local pollsLeft = self.drainMaxPolls or 0
    if pollsLeft <= 0 then return end

    local mspCommon = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.common
    local poll = mspCommon and mspCommon.mspPollReply
    if not poll then return end

    while pollsLeft > 0 and (os_clock() - start) < drainMs do
        local c, _, e = poll()
        if not c then break end
        -- Only expect duplicates of the just-completed command. If something else appears, stop draining.
        if c ~= cmd or e then
            if LOG_ENABLED_MSP() then utils.log("Drain saw unexpected cmd " .. tostring(c) .. " (expected " .. tostring(cmd) .. ")", "debug") end
            break
        end
        pollsLeft = pollsLeft - 1
    end
end

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

    -- Minimum seconds between re-sends of the same message (prevents pipelined retries)
    self.retryBackoff = opts.retryBackoff or RETRY_BACKOFF_SECONDS or DEFAULT_RETRY_BACKOFF_SECONDS

    -- After a successful reply, briefly poll to drain any duplicate/late replies for the same cmd
    -- (common with slow/bursty links when retries were attempted).
    self.drainAfterReplyMs = opts.drainAfterReplyMs or 0.03
    self.drainMaxPolls = opts.drainMaxPolls or 6

    self.uuid = nil -- last processed UUID
    self.apiname = nil -- last processed API name

    -- Inter-message delay (gap between *completed* messages)
    self.interMessageDelay = opts.interMessageDelay or 0
    self._nextMessageAt = 0
    self._qidSeq = 0

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
        if rfsuite.session and rfsuite.session.mspStatusMessage then
            rfsuite.session.mspStatusClearAt = os_clock() + 0.75
        end
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

        self.currentMessageStartTime = nil  -- set on first successful send
        self.lastTimeCommandSent = nil    -- per-message send timestamp
        self.currentMessage = qpop(self.queue)
        self.retryCount = 0
    end

    -- We are now genuinely active (either working a current message or about to send one)
    rfsuite.session.mspBusy = true
    self.mspBusyStart = self.mspBusyStart or now

    utils.muteSensorLostWarnings() -- Avoid sensor warnings during MSP    

    local cmd, buf, err
    -- Minimum spacing between send attempts (protocol can override).
    local lastTimeInterval = rfsuite.tasks.msp.protocol.mspIntervalOveride or 0.25
    if lastTimeInterval == nil then lastTimeInterval = 1 end

    if not system.getVersion().simulation then
        -- Real MSP: send once, then wait; only resend after backoff/timeout
        if self.currentMessage then
            local now2 = os_clock()

            -- Minimum spacing between any sends (existing throttle)
            local canSendByInterval = (not self.lastTimeCommandSent) or ((self.lastTimeCommandSent + lastTimeInterval) < now2)

            -- Retry/backoff gate: we only resend if we've either never sent, or we've waited long enough.
            local backoff = (self.currentMessage.retryBackoff or self.retryBackoff or RETRY_BACKOFF_SECONDS or DEFAULT_RETRY_BACKOFF_SECONDS)
            local canSendByBackoff = (self.retryCount == 0) or ((self.lastTimeCommandSent and (now2 - self.lastTimeCommandSent) >= backoff) or false)

            if canSendByInterval and canSendByBackoff and (self.retryCount <= self.maxRetries) then
                local sent = rfsuite.tasks.msp.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload or {})
                if sent then
                    self.lastTimeCommandSent = now2
                    -- Start overall timeout window on the first successful send only
                    if not self.currentMessageStartTime then
                        self.currentMessageStartTime = now2
                    end
                    self.retryCount = self.retryCount + 1
                    if self.retryCount > 1 then
                        setMspStatus(formatMspStatus(self.currentMessage, "retry " .. tostring(self.retryCount) .. "/" .. tostring(self.maxRetries + 1)))
                    else
                        setMspStatus(formatMspStatus(self.currentMessage, "send"))
                    end
                    if rfsuite.app.Page and rfsuite.app.Page.mspRetry then rfsuite.app.Page.mspRetry(self) end
                end
            end
        end

        -- Pump TX queue.
        rfsuite.tasks.msp.common.mspProcessTxQ()

        -- Poll for reply
        local ok, a, b, c = pcall(rfsuite.tasks.msp.common.mspPollReply)
        if ok then
            cmd, buf, err = a, b, c
        else
            if LOG_ENABLED_MSP() then
                utils.log("mspPollReply error: " .. tostring(a), "info")
            end
            setMspStatus("MSP poll error")
            -- back off a little so we don't hammer the same fault every frame
            self._nextMessageAt = os_clock() + 0.05
            return
        end
    else
        -- Simulator mode: use provided simulatorResponse.
        if not self.currentMessage.simulatorResponse then
            if LOG_ENABLED_MSP() then utils.log("No simulator response for command " .. tostring(self.currentMessage.command), "debug") end
            self.currentMessage = nil
            self.uuid = nil
            self.apiname = nil
            self.lastTimeCommandSent = nil
            self.currentMessageStartTime = nil
            return
        end
        cmd, buf, err = self.currentMessage.command, self.currentMessage.simulatorResponse, nil
    end

    -- Per-message timeout
    if self.currentMessage and self.currentMessageStartTime and (os_clock() - self.currentMessageStartTime) > (self.currentMessage.timeout or self.timeout) then
        local msg = self.currentMessage
        if msg and msg.errorHandler then pcall(msg.errorHandler, msg, "timeout") end
        if msg and msg.setErrorHandler then pcall(msg.setErrorHandler, msg) end
        if LOG_ENABLED_MSP() then utils.log("Message timeout exceeded. Flushing queue.", "debug") end
        setMspStatus(formatMspStatus(self.currentMessage, "timeout"))
        self.currentMessage = nil
        self.uuid = nil
        self.apiname = nil
        self.lastTimeCommandSent = nil
        self.currentMessageStartTime = nil
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
        if err then
            setMspStatus(formatMspStatus(self.currentMessage, "error flag"))
        else
            setMspStatus(formatMspStatus(self.currentMessage, "ok"))
        end

        -- After a successful completion, briefly drain duplicate/late replies for this cmd
        if not system.getVersion().simulation then
            drainAfterSuccess(self, self.currentMessage.command)
        end

        self.currentMessage = nil
        self.uuid = nil
        self.apiname = nil
        self.lastTimeCommandSent = nil
        self.currentMessageStartTime = nil
        if self.interMessageDelay and self.interMessageDelay > 0 then
            self._nextMessageAt = os_clock() + self.interMessageDelay
        end        
        if rfsuite.app.Page and rfsuite.app.Page.mspSuccess then rfsuite.app.Page.mspSuccess() end

    -- Too many retries - reset
    elseif self.retryCount > self.maxRetries then
        local msg = self.currentMessage
        self:clear()
        setMspStatus(formatMspStatus(msg, "max retries"))
        if msg and msg.errorHandler then pcall(msg.errorHandler, msg, "max_retries") end
        if msg and msg.setErrorHandler then pcall(msg.setErrorHandler, msg) end
        if rfsuite.app.Page and rfsuite.app.Page.mspTimeout then rfsuite.app.Page.mspTimeout() end
    end
end

-- Reset queue + MSP state
function MspQueueController:clear()
    rfsuite.session.mspBusy = false
    self.mspBusyStart = nil
    self.queue = newQueue()
    self.currentMessage = nil
    self.currentMessageStartTime = nil
    self.lastTimeCommandSent = nil
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
    self._qidSeq = (self._qidSeq or 0) + 1
    toQueue._qid = self._qidSeq
    qpush(self.queue, toQueue)
    setMspStatus(formatMspStatus(toQueue, "queued"))
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

