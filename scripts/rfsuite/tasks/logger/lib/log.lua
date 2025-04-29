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

--[[
logs.config: Configuration table for logging settings.

Fields:
- enabled (boolean): Enable or disable logging.
- log_to_file (boolean): Enable or disable logging to a file.
- print_interval (number): Interval in seconds for printing logs to the console.
- disk_write_interval (number): Interval in seconds for writing logs to disk.
- max_line_length (number): Maximum length of a log line.
- min_print_level (string): Minimum log level to print (e.g., "info").
- log_file (string): Name of the log file.
- prefix (string): Prefix to add to each log message.
]]
logs.config = {
    enabled = true,
    log_to_file = true,
    print_interval = 0.25,
    disk_write_interval = 5.0, 
    max_line_length = 100,
    min_print_level = "info", 
    log_file = "log.txt",
    prefix = ""
}


--[[
    Checks if the system is running in simulation mode.
    If true, sets the log print interval to 0.025 seconds.
]]
if system:getVersion().simulation == true then
    logs.config.print_interval = 0.025
end

--[[
    logs.queue: Table to store log messages for console output.
    logs.disk_queue: Table to store log messages for batched disk writes.
    logs.last_print_time: Timestamp of the last console output.
    logs.last_disk_write_time: Timestamp of the last disk write.
]]
logs.queue = {} 
logs.disk_queue = {} 
logs.last_print_time = os.clock()
logs.last_disk_write_time = os.clock()


--[[
    Table `logs.levels` defines different logging levels.
    The levels are:
    - `debug`: Level 0, used for debugging messages.
    - `info`: Level 1, used for informational messages.
    - `off`: Level 2, used to turn off logging.
]]
logs.levels = {
    debug = 0,
    info = 1,
    off = 2
}

--[[
Splits a message into multiple lines if it exceeds a specified maximum length.

@param message (string) The message to be split.
@param max_length (number) The maximum length of each line.
@param prefix (string) The prefix to be added to each subsequent line after the first.

@return (table) A table containing the split lines of the message.
]]
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


--[[
Logs a message with a specified log level.

Parameters:
- message (string): The message to log.
- level (string, optional): The log level (e.g., "info", "error"). Defaults to "info".

The function checks if logging is enabled and if the specified log level is above the minimum print level.
If the conditions are met, it formats the message with a prefix and splits it into lines if necessary.
The message is then added to the console queue and, if file logging is enabled, to the disk queue.

Returns:
- None
]]
function logs.add(message, level)
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


--[[
    Function: logs.process_console_queue
    Description: Processes the console log queue by printing messages at a specified interval.
    If logging is disabled or the minimum print level is set to "off", the function returns immediately.
    Otherwise, it prints the next message in the queue if the configured print interval has elapsed.
    
    Parameters: None
    
    Returns: None
]]
local function process_console_queue()
    if not logs.config.enabled or logs.config.min_print_level == "off" then return end

    local now = os.clock()

    if now - logs.last_print_time >= logs.config.print_interval and #logs.queue > 0 then
        logs.last_print_time = now
        local message = table.remove(logs.queue, 1)
        print(message)
    end
end

--[[
    Function: logs.process_disk_queue
    Description: Processes the disk queue by writing log messages to a file if certain conditions are met.
    Conditions:
        - Logging is enabled.
        - Minimum print level is not set to "off".
        - Logging to file is enabled.
    Behavior:
        - Checks the current time and compares it with the last disk write time.
        - If the time interval since the last write is greater than or equal to the configured disk write interval and there are messages in the disk queue, it writes the messages to the log file.
        - Clears the disk queue after writing.
    Dependencies:
        - logs.config.enabled: Boolean indicating if logging is enabled.
        - logs.config.min_print_level: String indicating the minimum print level.
        - logs.config.log_to_file: Boolean indicating if logging to file is enabled.
        - logs.config.disk_write_interval: Number indicating the interval between disk writes.
        - logs.config.log_file: String indicating the path to the log file.
        - logs.last_disk_write_time: Number indicating the last time logs were written to disk.
        - logs.disk_queue: Table containing log messages to be written to disk.
]]
local function process_disk_queue()
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

--[[
    Function: logs.process
    Description: Processes the console and disk queues by calling the respective functions.
    This function is responsible for handling log processing tasks.
]]
function logs.process()
    process_console_queue()
    process_disk_queue()
end

return logs
