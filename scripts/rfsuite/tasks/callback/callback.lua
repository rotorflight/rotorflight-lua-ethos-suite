--[[

 * Copyright (C) Rotorflight Project
 *
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
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
--
local arg = {...}
local config = arg[1]

local callback = {}
local loadedSensorModule = nil

callback._queue = {}

local function get_time()
    return os.clock()
end

function callback.now(callbackParam)
    table.insert(callback._queue, {time = nil, func = callbackParam, repeat_interval = nil})
end

function callback.inSeconds(seconds, callbackParam)
    table.insert(callback._queue, {time = get_time() + seconds, func = callbackParam, repeat_interval = nil})
end

function callback.every(seconds, callbackParam)
    table.insert(callback._queue, {time = get_time() + seconds, func = callbackParam, repeat_interval = seconds})
end

function callback.wakeup()
    local now = get_time()
    local i = 1
    while i <= #callback._queue do
        local entry = callback._queue[i]
        if not entry.time or entry.time <= now then
            entry.func()
            if entry.repeat_interval then
                entry.time = now + entry.repeat_interval
                i = i + 1
            else
                table.remove(callback._queue, i)
            end
        else
            i = i + 1
        end
    end
end

function callback.clear(callbackParam)
    for i = #callback._queue, 1, -1 do
        if callback._queue[i].func == callbackParam then
            table.remove(callback._queue, i)
        end
    end
end

function callback.clearAll()
    callback._queue = {}
end

function callback.reset()
    callback.clearAll()
end


return callback
