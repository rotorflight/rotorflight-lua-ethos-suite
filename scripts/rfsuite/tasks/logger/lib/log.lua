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
]]

local function CircularBuffer(capacity)
    local buffer = {
        data = {},
        head = 1,
        tail = 1,
        size = 0,
        capacity = capacity or 100,
    }

    function buffer:push(item)
        self.data[self.tail] = item
        self.tail = (self.tail % self.capacity) + 1
        if self.size < self.capacity then
            self.size = self.size + 1
        else
            self.head = (self.head % self.capacity) + 1  -- overwrite oldest
        end
    end

    function buffer:pop()
        if self.size == 0 then return nil end
        local item = self.data[self.head]
        self.data[self.head] = nil
        self.head = (self.head % self.capacity) + 1
        self.size = self.size - 1
        return item
    end

    function buffer:is_empty()
        return self.size == 0
    end

    function buffer:reset()
        self.data = {}
        self.head = 1
        self.tail = 1
        self.size = 0
    end

    return buffer
end

local logs = {}

logs.config = {
    enabled = true,
    log_to_file = true,
    print_interval = 0.5,
    disk_write_interval = 5.0,
    max_line_length = 200,
    min_print_level = "info",
    log_file = "log.txt",
    prefix = ""
}

if system:getVersion().simulation == true then
    logs.config.print_interval = 0.025
end

logs.queue = CircularBuffer(50)      -- Console log queue
logs.disk_queue = CircularBuffer(100) -- Disk write queue
logs.last_print_time = os.clock()
logs.last_disk_write_time = os.clock()

logs.levels = {
    debug = 0,
    info = 1,
    off = 2
}

-- Splits a message into multiple lines based on max_length, preserving prefixes
local function split_message(message, max_length, prefix)
    local lines = {}
    while #message > max_length do
        table.insert(lines, message:sub(1, max_length))
        message = prefix .. message:sub(max_length + 1)
    end
    if #message > 0 then
        table.insert(lines, message)
    end
    return lines
end

-- Adds a log entry to the queues (deferred splitting at output time)
function logs.add(message, level)
    if not logs.config.enabled or logs.config.min_print_level == "off" then
        return
    end
    level = level or "info"
    if logs.levels[level] == nil then return end
    if logs.levels[level] < logs.levels[logs.config.min_print_level] then return end

    -- Truncate overly long messages
    local max_message_length = logs.config.max_line_length * 10
    if #message > max_message_length then
        message = message:sub(1, max_message_length) .. " [truncated]"
    end

    -- Enqueue raw entry (lightweight)
    logs.queue:push({ msg = message, lvl = level })
    if logs.config.log_to_file then
        logs.disk_queue:push({ msg = message, lvl = level })
    end
end

-- Processes and prints pending console log entries
local function process_console_queue()
    if not logs.config.enabled or logs.config.min_print_level == "off" then return end
    local now = os.clock()
    if now - logs.last_print_time >= logs.config.print_interval and not logs.queue:is_empty() then
        logs.last_print_time = now

        local MAX_CONSOLE_MESSAGES = 5
        for _ = 1, MAX_CONSOLE_MESSAGES do
            local entry = logs.queue:pop()
            if not entry then break end

            -- Deferred heavy work: split and print lines
            local raw_prefix = logs.config.prefix
            local prefix = type(raw_prefix) == "function" and raw_prefix() or raw_prefix
            local log_entry = prefix .. entry.msg
            local pad = string.rep(" ", #prefix)
            for _, line in ipairs(split_message(log_entry, logs.config.max_line_length, pad)) do
                print(line)
            end
        end
    end
end

-- Processes and writes pending disk log entries
local function process_disk_queue()
    if not logs.config.enabled or logs.config.min_print_level == "off" or not logs.config.log_to_file then return end

    local now = os.clock()
    if now - logs.last_disk_write_time >= logs.config.disk_write_interval and not logs.disk_queue:is_empty() then
        logs.last_disk_write_time = now

        local MAX_DISK_MESSAGES = 20
        local file = io.open(logs.config.log_file, "a")
        if file then
            for _ = 1, MAX_DISK_MESSAGES do
                local entry = logs.disk_queue:pop()
                if not entry then break end

                -- Deferred heavy work: concatenate and write
                local raw_prefix = logs.config.prefix
                local prefix = type(raw_prefix) == "function" and raw_prefix() or raw_prefix
                local line = prefix .. entry.msg
                file:write(line .. "\n")
            end
            file:close()
        end
    end
end

-- Main processing function to be called each tick
function logs.process()
    process_console_queue()
    process_disk_queue()
end

return logs
