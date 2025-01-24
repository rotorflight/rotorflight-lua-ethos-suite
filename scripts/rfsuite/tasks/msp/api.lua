--
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

-- Define the API directory path based on the ethos version
local apidir = "tasks/msp/api/"
local api_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and apidir or (config.suiteDir .. apidir)

local api = {}

-- Store loaded modules to avoid reloading
api.modules = {}

function api.use(moduleName)
    if not api.modules[moduleName] then
        local path = api_path .. moduleName .. ".lua"

        -- Check if the file exists before attempting to load it
        if rfsuite.utils.file_exists(path) then
            local mod = assert(loadfile(path))()
            api.modules[moduleName] = mod
            mod:init()
        else
            rfsuite.utils.log("Module file not found: " .. path)
        end
    end
    return api.modules[moduleName]
end

-- response parser used in almost all api
function api.parseResponse(buf, structure, readData)
    local index = 1
    for _, entry in ipairs(structure) do
        local key, bits = entry.key, entry.bits
        if bits == 8 then
            readData[key] = buf[index]
            index = index + 1
        elseif bits == 16 then
            readData[key] = buf[index] + (buf[index + 1] * 256)
            index = index + 2
        elseif bits == 24 then
            readData[key] = buf[index] + (buf[index + 1] * 256) + (buf[index + 2] * 65536)
            index = index + 3
        elseif bits == 32 then
            readData[key] = buf[index] + (buf[index + 1] * 256) + (buf[index + 2] * 65536) + (buf[index + 3] * 16777216)
            index = index + 4
        end
    end
end

-- common write parse used in almost all api
function api.buildWriteRequest(writeStructure, writeDataBuffer)
    local requestData = {}
    for _, entry in ipairs(writeStructure) do
        local key, bits = entry.key, entry.bits
        local value = writeDataBuffer[key] or 0
        for i = 0, (bits / 8) - 1 do
            table.insert(requestData, (value >> (i * 8)) & 0xFF)
        end
    end
    return requestData
end

-- common function to get data for key value
function api.getData(readData, key)
    if key then
        return readData[key]
    end
    return readData
end

-- common function to set a value
function api.setParam(writeDataBuffer, writeStructure, key, value)
    for _, entry in ipairs(writeStructure) do
        if entry.key == key then
            writeDataBuffer[key] = value
            return
        end
    end
    rfsuite.utils.log("Invalid parameter for writing: " .. key)
end

-- common function to write data
function api.writeData(WRITE_ID, buildWriteRequest, writeStructure, writeDataBuffer, callback, callbackParam, simulatorResponse)
    if WRITE_ID == nil then
        rfsuite.utils.log("Write operation is disabled. WRITE_ID is nil.")
        return
    end

    local message = {
        command = WRITE_ID,
        payload = buildWriteRequest(writeStructure, writeDataBuffer),
		processReply = function(self, buf)
            callback(callbackParam)			
		end,
        simulatorResponse = simulatorResponse or {}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

-- common function to read data
function api.fetchData(READ_ID, parseResponse, readStructure, readStructureCount, readData, callback, callbackParam, simulatorResponse)
    if READ_ID == nil then
        rfsuite.utils.log("Read operation is disabled. READ_ID is nil.")
        return
    end

    local message = {
        command = READ_ID,
        processReply = function(_, buf)
            if #buf >= readStructureCount then
                parseResponse(buf, readStructure, readData)
                callback(callbackParam)
            end
        end,
        simulatorResponse = simulatorResponse or {}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end


return api