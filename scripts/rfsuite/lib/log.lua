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
local logs = {}

-- Configuration
logs.config = {
    enabled = true,
    print_interval = 0.25,  -- seconds
    max_line_length = 100,
    min_print_level = "info", -- Default log level
    log_file = "log.txt",
    prefix = ""
}

logs.queue = {}
logs.last_print_time = os.clock()

-- Define log levels
logs.levels = {
    debug = 0,  -- Debug is the lowest level (least important)
    info = 1,   -- Info is above debug
    off = 2     -- "off" should be the highest to disable logging
}

-- Function to write to a file
local function write_to_file(message)
    local file = io.open(logs.config.log_file, "a")
    if file then
        file:write(message .. "\n")
        file:close()
    end
end

-- Function to split message into multiple lines if it exceeds max_line_length
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

-- Function to add a log message to the queue
function logs.log(message, level)
    if not logs.config.enabled or logs.config.min_print_level == "off" then return end

    level = level or "info"
    
    -- Ensure the level exists
    if logs.levels[level] == nil then return end 

    -- Compare log levels; only log if the level is >= min_print_level
    if logs.levels[level] < logs.levels[logs.config.min_print_level] then
        return
    end

    local prefix = logs.config.prefix .. " [" .. level .. "] "
    local log_entry = prefix .. message
    local lines = {}

    if system:getVersion().simulation then
        table.insert(lines, log_entry) -- No truncation in simulation mode
    else
        lines = split_message(log_entry, logs.config.max_line_length, string.rep(" ", #prefix))
    end

    for _, line in ipairs(lines) do
        table.insert(logs.queue, line)
    end

    write_to_file(log_entry) -- Write full log to the file
end


-- Function to process the log queue
function logs.process()
    if not logs.config.enabled or logs.config.min_print_level == "off" then return end
    
    local now = os.clock()
    
    if now - logs.last_print_time >= logs.config.print_interval and #logs.queue > 0 then
        logs.last_print_time = now
        local file = io.open(logs.config.log_file, "a")
        if file then
            local message = table.remove(logs.queue, 1)  -- Remove only one message
            print(message)
            file:write(message .. "\n")  -- Write the single processed line to the file
            file:close()
        end
    end
end


return logs
