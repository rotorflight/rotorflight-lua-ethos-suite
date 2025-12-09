--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local protocol = {}

-- LuaFormatter off
local supportedProtocols = {
  sport = {
    mspTransport     = "sp.lua",
    mspProtocol      = "sport",
    maxTxBufferSize  = 6,
    maxRxBufferSize  = 6,
    maxRetries       = 10,
    saveTimeout      = 10.0,
    cms              = {},
    pageReqTimeout   = 15,
    mspIntervalOveride = 0.25,  
    mspQueueTimeout    = 4.0, 
    mspPollBudget      = 0.15
  },

  crsf = {
    mspTransport     = "crsf.lua",
    mspProtocol      = "crsf",
    maxTxBufferSize  = 8,
    maxRxBufferSize  = 58,
    maxRetries       = 5,
    saveTimeout      = 10.0,
    cms              = {},
    pageReqTimeout   = 10,
    mspIntervalOveride = 0.25,  
    mspQueueTimeout    = 2.0,  
    mspPollBudget      = 0.1   
  },
}
-- LuaFormatter on

function protocol.getProtocol()
    if rfsuite.session and rfsuite.session.telemetryType then if rfsuite.session.telemetryType == "crsf" then return supportedProtocols.crsf end end
    return supportedProtocols.sport
end

function protocol.getTransports()
    local transport = {}
    for i, v in pairs(supportedProtocols) do transport[i] = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/" .. v.mspTransport end
    return transport
end

return protocol
