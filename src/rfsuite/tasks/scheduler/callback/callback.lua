--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local callback = {}
local loadedSensorModule = nil

callback._queue = {}

local function get_time() return os.clock() end
local MAX_PER_WAKEUP = (config and config.callbackMaxPerWakeup) or 16
local BUDGET_SECONDS = (config and config.callbackBudgetSeconds) or 0.004

function callback.now(callbackParam) table.insert(callback._queue, {time = nil, func = callbackParam, repeat_interval = nil}) end

function callback.inSeconds(seconds, callbackParam) table.insert(callback._queue, {time = get_time() + seconds, func = callbackParam, repeat_interval = nil}) end

function callback.every(seconds, callbackParam) table.insert(callback._queue, {time = get_time() + seconds, func = callbackParam, repeat_interval = seconds}) end

function callback.wakeup()
    local now = get_time()
    local deadline = (BUDGET_SECONDS and BUDGET_SECONDS > 0) and (now + BUDGET_SECONDS) or nil
    local processed = 0
    local i = 1
    while i <= #callback._queue do
        if (processed >= MAX_PER_WAKEUP) or (deadline and get_time() >= deadline) then
            break
        end
        local entry = callback._queue[i]
        if not entry.time or entry.time <= now then
            entry.func()
            if entry.repeat_interval then
                entry.time = now + entry.repeat_interval
                i = i + 1
                processed = processed + 1
            else
                table.remove(callback._queue, i)
                processed = processed + 1
            end
        else
            i = i + 1
        end
    end
end

function callback.clear(callbackParam) for i = #callback._queue, 1, -1 do if callback._queue[i].func == callbackParam then table.remove(callback._queue, i) end end end

function callback.clearAll() callback._queue = {} end

function callback.reset() callback.clearAll() end

return callback
