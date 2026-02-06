--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local callback = {}

-- Localize globals for performance
local os_clock = os.clock
local table_insert = table.insert
local table_remove = table.remove

callback._queue = {}

local MAX_PER_WAKEUP = (config and config.callbackMaxPerWakeup) or 16
local BUDGET_SECONDS = (config and config.callbackBudgetSeconds) or 0.004

function callback.now(callbackParam) table_insert(callback._queue, {time = nil, func = callbackParam, repeat_interval = nil}) end

function callback.inSeconds(seconds, callbackParam) table_insert(callback._queue, {time = os_clock() + seconds, func = callbackParam, repeat_interval = nil}) end

function callback.every(seconds, callbackParam) table_insert(callback._queue, {time = os_clock() + seconds, func = callbackParam, repeat_interval = seconds}) end

function callback.wakeup()
    local now = os_clock()
    local deadline = (BUDGET_SECONDS and BUDGET_SECONDS > 0) and (now + BUDGET_SECONDS) or nil
    local processed = 0
    local i = 1
    local queue = callback._queue -- Local reference for speed

    while i <= #queue do
        if (processed >= MAX_PER_WAKEUP) or (deadline and os_clock() >= deadline) then
            break
        end
        local entry = queue[i]
        if not entry.time or entry.time <= now then
            entry.func()
            if entry.repeat_interval then
                entry.time = now + entry.repeat_interval
                i = i + 1
                processed = processed + 1
            else
                table_remove(queue, i)
                processed = processed + 1
            end
        else
            i = i + 1
        end
    end
end

function callback.clear(callbackParam)
    local queue = callback._queue
    for i = #queue, 1, -1 do
        if queue[i].func == callbackParam then
            table_remove(queue, i)
        end
    end
end

function callback.clearAll() callback._queue = {} end

function callback.reset() callback.clearAll() end

return callback
