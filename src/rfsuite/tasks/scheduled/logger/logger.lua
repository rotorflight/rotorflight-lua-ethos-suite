--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local logger = {}

os.mkdir("LOGS:")
os.mkdir("LOGS:/rfsuite")
os.mkdir("LOGS:/rfsuite/logs")
logger.queue = assert(loadfile("tasks/scheduled/logger/lib/log.lua"))(config)
logger.queue.config.log_file = "LOGS:/rfsuite/logs/rfsuite_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".log"
logger.queue.config.min_print_level = rfsuite.preferences.developer.loglevel
local logtofile = rfsuite.preferences.developer.logtofile
logger.queue.config.log_to_file = (logtofile == true or logtofile == "true")

function logger.wakeup()
    if rfsuite.session.mspBusy then return end
    logger.queue.process()
end

function logger.reset() end

function logger.add(message, level)
    logger.queue.config.min_print_level = rfsuite.preferences.developer.loglevel
    local logtofile = rfsuite.preferences.developer.logtofile
    logger.queue.config.log_to_file = (logtofile == true or logtofile == "true")
    logger.queue.config.prefix = function() return string.format("[%.2f] ", os.clock()) end
    logger.queue.add(message, level)
end

function logger.getConnectLines(n)
    return logger.queue.getConnectLines(n)
end

return logger
