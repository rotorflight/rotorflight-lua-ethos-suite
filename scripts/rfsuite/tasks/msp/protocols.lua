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

--[[
    supportedProtocols table contains configurations for different communication protocols.
    
    Each protocol configuration includes:
    - mspTransport: The Lua script responsible for handling the MSP transport layer.
    - mspProtocol: The name of the MSP protocol.
    - push: Function to push telemetry data (only for sport protocol).
    - maxTxBufferSize: Maximum size of the transmission buffer.
    - maxRxBufferSize: Maximum size of the reception buffer.
    - maxRetries: Maximum number of retries for communication.
    - saveTimeout: Timeout duration for saving data.
    - cms: Configuration management system settings (currently empty).
    - pageReqTimeout: Timeout duration for page requests.
]]
local supportedProtocols = {
    sport = {
        mspTransport = "sp.lua",
        mspProtocol = "sport",
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

--[[
    Retrieves the communication protocol based on the availability of the source.
]]
function protocol.getProtocol()
    if rfsuite.session and rfsuite.session.telemetryType then
        if rfsuite.session.telemetryType == "crsf" then
            return supportedProtocols.crsf
        end
    end
    return supportedProtocols.sport
end

--[[
    Retrieves the available transport protocols.
    
    This function iterates over the supportedProtocols table and constructs a new table
    containing the transport paths for each protocol.

    @return table A table where each key corresponds to a protocol and the value is the transport path.
]]
function protocol.getTransports()
    local transport = {}
    for i, v in pairs(supportedProtocols) do transport[i] = "tasks/msp/" .. v.mspTransport end
    return transport
end

return protocol
