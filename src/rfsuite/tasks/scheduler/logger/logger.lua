--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local logger = {}
logger.pauseDepth = 0

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

local function syncDeveloperLoggingConfig()
    local dev = rfsuite.preferences and rfsuite.preferences.developer
    local mode = dev and dev.loglevel or "off"
    logger.queue.config.enabled = (mode ~= "off")
    logger.queue.config.log_to_file = (mode == "debug")
end

syncDeveloperLoggingConfig()

function logger.wakeup()
    local session = rfsuite.session
    if session and session.mspBusy then return end
    logger.queue.process()
end

function logger.reset() 
    logger.queue.flush()
    logger.queue.reset()
end

function logger.add(message, route)
    if (logger.pauseDepth or 0) > 0 then return false end
    syncDeveloperLoggingConfig()
    logger.queue.add(message, route)
    return true
end

function logger.pause()
    logger.pauseDepth = (logger.pauseDepth or 0) + 1
    return logger.pauseDepth
end

function logger.resume()
    local depth = logger.pauseDepth or 0
    if depth > 0 then depth = depth - 1 end
    logger.pauseDepth = depth
    return depth == 0
end

function logger.isPaused()
    return (logger.pauseDepth or 0) > 0
end

function logger.getConnectLines(n)
    return logger.queue.getConnectLines(n)
end

function logger.flush()
    logger.queue.flush()
end

return logger
