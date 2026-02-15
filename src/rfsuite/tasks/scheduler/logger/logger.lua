--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local logger = {}

-- Localize globals
local os_clock = os.clock
local string_format = string.format

os.mkdir("LOGS:")
os.mkdir("LOGS:/rfsuite")
os.mkdir("LOGS:/rfsuite/logs")
logger.queue = assert(loadfile("tasks/scheduler/logger/lib/log.lua"))(config)
logger.queue.config.log_file = "LOGS:/rfsuite/logs/rfsuite_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".log"

-- Pre-define prefix function to avoid closure allocation on every log
local function getLogPrefix()
    return string_format("[%.2f] ", os_clock())
end
logger.queue.config.prefix = getLogPrefix

if rfsuite.preferences and rfsuite.preferences.developer then
    logger.queue.config.min_print_level = rfsuite.preferences.developer.loglevel
    logger.queue.config.log_to_file = (rfsuite.preferences.developer.loglevel == "debug")
end

function logger.wakeup()
    local session = rfsuite.session
    if session and session.mspBusy then return end
    logger.queue.process()
end

function logger.reset() 
    logger.queue.flush()
    logger.queue.reset()
end

function logger.add(message, level)
    local dev = rfsuite.preferences.developer
    logger.queue.config.min_print_level = dev.loglevel
    logger.queue.config.log_to_file = (dev.loglevel == "debug")
    logger.queue.add(message, level)
end

function logger.getConnectLines(n)
    return logger.queue.getConnectLines(n)
end

function logger.flush()
    logger.queue.flush()
end

return logger
