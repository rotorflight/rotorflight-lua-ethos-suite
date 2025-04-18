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

local msp = {}


--[[
msp_sensors: A table containing sensor configurations for MSP (Multiwii Serial Protocol).

A table containing status-related sensor configurations.
    battery_profile: A table containing configuration for the battery profile sensor.
        sensorname: The name of the sensor.
        sessionname: The session name associated with the sensor .
        appId: The application ID for the sensor.
        interval: The interval at which the sensor data is updated (2 seconds minimum).
        unit: The unit of measurement for the sensor data (UNIT_RAW).
        minimum: The minimum value for the sensor data (0).
        maximum: The maximum value for the sensor data (100).

 The code below will create an ethos sensor, or session, or both at the set interval       
]]
local msp_sensors = {
 --   GOVERNOR_CONFIG = {
 --       gov_mode = {
 --           sensorname = "Governor Config",
 --           sessionname = "governorMode",
 --           appId = 0x11000,
 --           interval = 5,
 --           unit = UNIT_RAW,
 --           minimum = 0,
 --           maximum = 3,
 --       },
 --   },
}

msp.sensors = msp_sensors
local sensorCache = {}

--[[
    getCurrentTime

    Returns the current time in seconds since the epoch.

    @return number: The current time in seconds since the epoch.
]]
local function getCurrentTime()
    return os.time()
end


--[[
    Creates or updates a sensor with the given appId, field metadata, and value.

    @param appId (number) - The application ID for the sensor.
    @param fieldMeta (table) - A table containing metadata for the sensor, including:
        - sensorname (string) - The name of the sensor.
        - unit (string, optional) - The unit of measurement for the sensor.
        - minimum (number, optional) - The minimum value for the sensor (default: -1000000000).
        - maximum (number, optional) - The maximum value for the sensor (default: 2147483647).
    @param value (number) - The value to set for the sensor.

    If a sensor with the given appId does not exist in the sensorCache, a new sensor is created
    and added to the cache. The sensor is configured with the provided field metadata and value.
    If the sensor already exists in the cache, its value is updated with the provided value.
--]]
local function createOrUpdateSensor(appId, fieldMeta, value)
    if sensorCache[appId] == nil then
        local sensor = model.createSensor()
        sensor:name(fieldMeta.sensorname)
        sensor:appId(appId)
        sensor:physId(0) -- Replace with actual physId if needed
        sensor:module(rfsuite.session.telemetrySensor:module())
        
        -- Optional settings
        if fieldMeta.unit then
            sensor:unit(fieldMeta.unit)
            sensor:protocolUnit(fieldMeta.unit)
        end
        sensor:minimum(fieldMeta.minimum or -1000000000)
        sensor:maximum(fieldMeta.maximum or 2147483647)

        sensorCache[appId] = sensor
    end

    if sensorCache[appId] then
        sensorCache[appId]:value(value)
    end
end


--- Updates a session field in the `rfsuite.session` table.
-- @param meta A table containing metadata, including the session field name.
-- @param value The value to set for the session field.
-- If `meta.sessionname` exists and `rfsuite.session` is not nil, the function sets the session field specified by `meta.sessionname` to the given value.
local function updateSessionField(meta, value)
    if meta.sessionname and rfsuite.session then
        rfsuite.session[meta.sessionname] = value
    end
end

--[[
    Function: msp.wakeup

    Description:
    This function is responsible for waking up the MSP (Multiwii Serial Protocol) task and processing sensor data. 
    It checks if the MSP queue has been processed and iterates through the defined MSP sensors to determine if they need to be queried based on their defined intervals. 
    If a sensor needs to be queried, it loads the corresponding API, sets a completion handler to process the sensor data, and updates session variables and telemetry sensors accordingly.

    Parameters:
    None

    Returns:
    None

    Notes:
    - The function relies on several external functions and modules such as `getCurrentTime`, `rfsuite.tasks.msp.api.load`, `updateSessionField`, `generateAppId`, `createOrUpdateSensor`, and `rfsuite.utils.log`.
    - The `msp_sensors` table is expected to contain sensor definitions with fields including `interval`, `last_time`, `sensorname`, and `sessionname`.
    - The completion handler updates the `last_time` for each field and logs the updated values.
--]]
local lastWakeupTime = 0
function msp.wakeup()
    -- we never run msp session stuff faster than every 2s due to load
    local now = getCurrentTime()
    if (now - lastWakeupTime) < 2 then
        return
    end
    lastWakeupTime = now

    if not rfsuite.tasks.msp.mspQueue:isProcessed() then
        rfsuite.utils.log("MSP queue busy.. skipping dynamic msp sensors", "info")
        return
    end

    for api_name, fields in pairs(msp_sensors) do
        local should_query = false
        for field_key, meta in pairs(fields) do
            if (now - (meta.last_time or 0)) >= meta.interval then
                should_query = true
                break
            end
        end

        if should_query then
            local API = rfsuite.tasks.msp.api.load(api_name)

            API.setCompleteHandler(function(self, buf)
                for field_key, meta in pairs(fields) do
                    if (now - (meta.last_time or 0)) >= meta.interval then
                        local value = API.readValue(field_key)
                        if value ~= nil then
                            meta.last_time = now

                            -- Update session variable if defined
                            updateSessionField(meta, value)

                            -- Create or update telemetry sensor if defined
                            if meta.sensorname then
                                local appId = meta.appId
                                if appId then
                                    createOrUpdateSensor(appId, meta, value)
                                end
                            end

                            -- Log what we updated
                            --rfsuite.utils.log((meta.sensorname or meta.sessionname or field_key) .. ": " .. tostring(value), "info")
                        end
                    end
                end
            end)

            API.setUUID("uuid-" .. api_name)
            API.read()
        end
    end
end

return msp