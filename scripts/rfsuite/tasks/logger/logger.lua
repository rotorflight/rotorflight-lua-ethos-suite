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

local logger = {}

-- 
-- This script initializes the logging configuration for the rfsuite module.
-- 
-- The logging configuration is loaded from the "lib/log.lua" file and is 
-- customized based on the provided configuration (`config`).
-- 
-- The log file is named using the current date and time in the format 
-- "logs/rfsuite_YYYY-MM-DD_HH-MM-SS.log".
-- 
-- The minimum print level for logging is set from `rfsuite.preferences.developer.loglevel`.
-- 
-- The option to log to a file is set from `preferences.developer.logtofile`.
-- 
-- If the system is running in simulation mode, the log print interval is 
-- set to 0.1 seconds.
-- logging
os.mkdir("LOGS:")
os.mkdir("LOGS:/rfsuite")
os.mkdir("LOGS:/rfsuite/logs")
logger.queue = assert(rfsuite.compiler.loadfile("tasks/logger/lib/log.lua"))(config)
logger.queue.config.log_file = "LOGS:/rfsuite/logs/rfsuite_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".log"
logger.queue.config.min_print_level  = rfsuite.preferences.developer.loglevel
local logtofile = rfsuite.preferences.developer.logtofile
logger.queue.config.log_to_file = (logtofile == true or logtofile == "true")


function logger.wakeup()
    logger.queue.process()    
end

function logger.reset()

end

function logger.add(message, level)
    logger.queue.config.min_print_level  = rfsuite.preferences.developer.loglevel
    local logtofile = rfsuite.preferences.developer.logtofile
    logger.queue.config.log_to_file = (logtofile == true or logtofile == "true")
    logger.queue.config.prefix = function()
        return string.format("[%.2f] ", os.clock())
    end    
    logger.queue.add(message,level)
end

return logger
