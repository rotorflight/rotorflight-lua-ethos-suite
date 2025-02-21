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

]] --

local logs = {}

-- Configuration
logs.config = {
    enabled = true,
    log_to_file = true, -- New option to enable/disable logging to a file
    print_interval = 0.25,  -- seconds
    disk_write_interval = 5.0, -- seconds (configurable disk write interval)
    max_line_length = 100,
    min_print_level = "info", -- Default log level
    log_file = "log.txt",
    prefix = ""
}

-- quick logs in sim
if system:getVersion().simulation == true then
    logs.config.print_interval = 0.025
end

logs.queue = {} -- For console output
logs.disk_queue = {} -- For batched disk writes
logs.last_print_time = os.clock()
logs.last_disk_write_time = os.clock()

-- Define log levels
logs.levels = {
    debug = 0,
    info = 1,
    off = 2
}

-- Function to split message into multiple lines
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

-- Function to add a log message
function logs.log(message, level)
    if not logs.config.enabled or logs.config.min_print_level == "off" then return end

    level = level or "info"

    if logs.levels[level] == nil then return end
    if logs.levels[level] < logs.levels[logs.config.min_print_level] then return end

    local prefix = logs.config.prefix .. " [" .. level .. "] "
    local log_entry = prefix .. message
    local lines = {}

    if system:getVersion().simulation then
        table.insert(lines, log_entry)
    else
        lines = split_message(log_entry, logs.config.max_line_length, string.rep(" ", #prefix))
    end

    -- Add to console queue
    for _, line in ipairs(lines) do
        table.insert(logs.queue, line)
    end

    -- Add to disk queue only if logging to a file is enabled
    if logs.config.log_to_file then
        table.insert(logs.disk_queue, log_entry)
    end
end

-- Function to process console output queue
function logs.process_console_queue()
    if not logs.config.enabled or logs.config.min_print_level == "off" then return end

    local now = os.clock()

    if now - logs.last_print_time >= logs.config.print_interval and #logs.queue > 0 then
        logs.last_print_time = now
        local message = table.remove(logs.queue, 1)
        print(message)
    end
end

-- Function to process disk queue
function logs.process_disk_queue()
    if not logs.config.enabled or logs.config.min_print_level == "off" or not logs.config.log_to_file then return end

    local now = os.clock()

    if now - logs.last_disk_write_time >= logs.config.disk_write_interval and #logs.disk_queue > 0 then
        logs.last_disk_write_time = now
        local file = io.open(logs.config.log_file, "a")
        if file then
            for _, message in ipairs(logs.disk_queue) do
                file:write(message .. "\n")
            end
            file:close()
            logs.disk_queue = {} -- Clear queue after writing
        end
    end
end

-- Function to process both queues
function logs.process()
    logs.process_console_queue()
    logs.process_disk_queue()
end

return logs
