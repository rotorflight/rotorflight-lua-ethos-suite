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
local arg = {...}
local config = arg[1]

protocol = {}

local supportedProtocols = {
    sport = {
        mspTransport = "sp.lua",
        mspProtocol = "sport",
        push = sportTelemetryPush,
        maxTxBufferSize = 6,
        maxRxBufferSize = 6,
        maxRetries = 10,
        saveTimeout = 10.0,
        cms = {},
        pageReqTimeout = 15
    },
    crsf = {
        mspTransport = "crsf.lua",
        mspProtocol = "crsf",
        maxTxBufferSize = 8,
        maxRxBufferSize = 58,
        maxRetries = 5,
        saveTimeout = 10.0,
        cms = {},
        pageReqTimeout = 10
    }
}

function protocol.getProtocol()
    if system.getSource("Rx RSSI1") ~= nil then return supportedProtocols.crsf end
    return supportedProtocols.sport
end

function protocol.getTransports()
    local transport = {}
    for i, v in pairs(supportedProtocols) do transport[i] = "tasks/msp/" .. v.mspTransport end
    return transport
end

return protocol
