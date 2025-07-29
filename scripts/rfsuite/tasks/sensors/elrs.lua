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
-- Rotorflight Custom Telemetry Decoder for ELRS
--
--
local arg = {...}
local config = arg[1]

local elrs = {}

-- used by sensors.lua to know if module has changed
elrs.name = "elrs"


--[[
This script checks if the `crsf.getSensor` function is available.
If available, it retrieves the sensor object and assigns the `popFrame` and `pushFrame` methods from the sensor object to the `elrs` table.
If `crsf.getSensor` is not available, it directly assigns the `crsf.popFrame` and `crsf.pushFrame` methods to the `elrs` table.
]]
if crsf.getSensor ~= nil then
    local sensor = crsf.getSensor()
    elrs.popFrame = function()
        return sensor:popFrame()
    end
    elrs.pushFrame = function(x, y)
        return sensor:pushFrame(x, y)
    end
else
    elrs.popFrame = function()
        return crsf.popFrame()
    end
    elrs.pushFrame = function(x, y)
        return crsf.pushFrame(x, y)
    end
end

local sensors = {}
sensors['uid'] = {}
sensors['lastvalue'] = {}

local rssiSensor = nil

local CRSF_FRAME_CUSTOM_TELEM = 0x88

--[[
    Creates a telemetry sensor with the specified parameters and adds it to the sensors table.

    @param uid (number) - Unique identifier for the sensor.
    @param name (string) - Name of the sensor.
    @param unit (number) - Unit of measurement for the sensor (optional).
    @param dec (number) - Number of decimal places for the sensor value (optional).
    @param value (number) - Initial value of the sensor (optional).
    @param min (number) - Minimum value for the sensor (optional, default is -1000000000).
    @param max (number) - Maximum value for the sensor (optional, default is 2147483647).
]]
local function createTelemetrySensor(uid, name, unit, dec, value, min, max)

    if rfsuite.session.telemetryState == false then return end

    sensors['uid'][uid] = model.createSensor({type=SENSOR_TYPE_DIY})
    sensors['uid'][uid]:name(name)
    sensors['uid'][uid]:appId(uid)
    sensors['uid'][uid]:module(1)
    sensors['uid'][uid]:minimum(min or -1000000000)
    sensors['uid'][uid]:maximum(max or 2147483647)
    if dec then
        sensors['uid'][uid]:decimals(dec)
        sensors['uid'][uid]:protocolDecimals(dec)
    end
    if unit then
        sensors['uid'][uid]:unit(unit)
        sensors['uid'][uid]:protocolUnit(unit)
    end
    if value then sensors['uid'][uid]:value(value) end
end

--[[
    setTelemetryValue - Sets the telemetry value for a given sensor.

    Parameters:
    uid (number) - Unique identifier for the sensor.
    subid (number) - Sub-identifier for the sensor (not used in the function).
    instance (number) - Instance of the sensor (not used in the function).
    value (number) - The value to set for the sensor.
    unit (number) - The unit of the value.
    dec (number) - Decimal places for the value.
    name (string) - Name of the sensor.
    min (number) - Minimum value for the sensor.
    max (number) - Maximum value for the sensor.

    The function checks if the sensor with the given uid exists. If not, it creates the sensor.
    If the sensor exists, it updates the value if it has changed. It also checks if the sensor
    has been deleted or is missing and handles it accordingly.
]]
local function setTelemetryValue(uid, subid, instance, value, unit, dec, name, min, max)

    if rfsuite.session.telemetryState == false then return end

    if sensors['uid'][uid] == nil then
        sensors['uid'][uid] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
        if sensors['uid'][uid] == nil then
            rfsuite.utils.log("Create sensor: " .. uid, "debug")
            createTelemetrySensor(uid, name, unit, dec, value, min, max)
        end
    else
        if sensors['uid'][uid] then
            if sensors['lastvalue'][uid] == nil or sensors['lastvalue'][uid] ~= value then sensors['uid'][uid]:value(value) end

            -- detect if sensor has been deleted or is missing after initial creation
            if sensors['uid'][uid]:state() == false then
                sensors['uid'][uid] = nil
                sensors['lastvalue'][uid] = nil
            end

        end
    end
end

--[[
    decNil function
    Short description: This function returns nil and the given position.
    
    Parameters:
    - data: The data input (not used in the function).
    - pos: The position input to be returned.
    
    Returns:
    - nil: Always returns nil.
    - pos: The position input.
]]
local function decNil(data, pos)
    return nil, pos
end

--[[
    decU8 - Decodes an unsigned 8-bit integer from the given data at the specified position.
    
    Parameters:
    data (table) - The table containing the data to decode.
    pos (number) - The position in the data table to start decoding from.
    
    Returns:
    number - The decoded unsigned 8-bit integer.
    number - The next position in the data table after decoding.
]]
local function decU8(data, pos)
    return data[pos], pos + 1
end

--[[
    decS8 - Decodes a signed 8-bit integer from the given data at the specified position.
    
    Parameters:
    data (string) - The data string containing the 8-bit integer to decode.
    pos (number) - The position in the data string to start decoding from.
    
    Returns:
    number - The decoded signed 8-bit integer.
    number - The next position in the data string after decoding.
]]
local function decS8(data, pos)
    local val, ptr = decU8(data, pos)
    return val < 0x80 and val or val - 0x100, ptr
end

--[[
    decU16 - Decodes a 16-bit unsigned integer from a byte array.
    
    Parameters:
    data (table) - The byte array containing the data.
    pos (number) - The position in the array to start decoding from.
    
    Returns:
    number - The decoded 16-bit unsigned integer.
    number - The new position in the array after decoding.
]]
local function decU16(data, pos)
    return (data[pos] << 8) | data[pos + 1], pos + 2
end

--[[
    decS16 - Decodes a signed 16-bit integer from the given data at the specified position.
    
    Parameters:
    data (string) - The data string containing the encoded integer.
    pos (number) - The position in the data string to start decoding from.
    
    Returns:
    number - The decoded signed 16-bit integer.
    number - The updated position pointer after decoding.
]]
local function decS16(data, pos)
    local val, ptr = decU16(data, pos)
    return val < 0x8000 and val or val - 0x10000, ptr
end

--[[
    decU12U12 - Decodes two 12-bit unsigned integers from a byte array.

    Parameters:
    data (table) - The byte array containing the data to decode.
    pos (number) - The starting position in the byte array.

    Returns:
    a (number) - The first 12-bit unsigned integer.
    b (number) - The second 12-bit unsigned integer.
    pos (number) - The updated position in the byte array after decoding.
]]
local function decU12U12(data, pos)
    local a = ((data[pos] & 0x0F) << 8) | data[pos + 1]
    local b = ((data[pos] & 0xF0) << 4) | data[pos + 2]
    return a, b, pos + 3
end

--[[
    Decodes two signed 12-bit integers from the given data starting at the specified position.
    
    Parameters:
    data (string) - The data string containing the encoded 12-bit integers.
    pos (number) - The position in the data string to start decoding from.
    
    Returns:
    a (number) - The first decoded signed 12-bit integer.
    b (number) - The second decoded signed 12-bit integer.
    ptr (number) - The updated position in the data string after decoding.
]]
local function decS12S12(data, pos)
    local a, b, ptr = decU12U12(data, pos)
    return a < 0x0800 and a or a - 0x1000, b < 0x0800 and b or b - 0x1000, ptr
end

--[[
    decU24 - Decodes a 24-bit unsigned integer from a byte array.
    
    Parameters:
    data (table) - The byte array containing the data.
    pos (number) - The starting position in the byte array.
    
    Returns:
    number - The decoded 24-bit unsigned integer.
    number - The updated position in the byte array.
]]
local function decU24(data, pos)
    return (data[pos] << 16) | (data[pos + 1] << 8) | data[pos + 2], pos + 3
end

--[[
    decS24 - Decodes a signed 24-bit integer from the given data starting at the specified position.
    
    Parameters:
    data (string) - The data string containing the 24-bit integer to decode.
    pos (number) - The position in the data string to start decoding from.
    
    Returns:
    number - The decoded signed 24-bit integer.
    number - The updated position pointer after decoding.
]]
local function decS24(data, pos)
    local val, ptr = decU24(data, pos)
    return val < 0x800000 and val or val - 0x1000000, ptr
end

--[[
    Decodes a 32-bit unsigned integer from a given position in a byte array.
    
    Parameters:
    data (table): The byte array containing the data.
    pos (number): The position in the byte array from which to start decoding.
    
    Returns:
    number: The decoded 32-bit unsigned integer.
    number: The new position in the byte array after decoding.
]]
local function decU32(data, pos)
    return (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3], pos + 4
end

--[[
    decS32 - Decodes a signed 32-bit integer from the given data starting at the specified position.
    
    Parameters:
    data (string) - The data string containing the encoded integer.
    pos (number) - The position in the data string to start decoding from.
    
    Returns:
    number - The decoded signed 32-bit integer.
    number - The new position in the data string after decoding.
]]
local function decS32(data, pos)
    local val, ptr = decU32(data, pos)
    return val < 0x80000000 and val or val - 0x100000000, ptr
end

--[[
    decCellV

    This function decodes a single cell voltage from the given data at the specified position.
    It uses the decU8 function to decode an unsigned 8-bit integer from the data.

    Parameters:
    - data: The data from which to decode the cell voltage.
    - pos: The position in the data to start decoding from.

    Returns:
    - val: The decoded cell voltage value. If the decoded value is greater than 0, 
           it adds 200 to the value. Otherwise, it returns 0.
    - ptr: The updated position pointer after decoding.
]]
local function decCellV(data, pos)
    local val, ptr = decU8(data, pos)
    return val > 0 and val + 200 or 0, ptr
end

--[[
    decCells function

    This function decodes cell count and cell voltages from the given data and sets telemetry values accordingly.

    Parameters:
    - data: The data to decode.
    - pos: The current position in the data.

    Returns:
    - nil: The function always returns nil.
    - pos: The updated position in the data.
]]
local function decCells(data, pos)
    local cnt, val, vol
    cnt, pos = decU8(data, pos)
    setTelemetryValue(0x1020, 0, 0, cnt, UNIT_RAW, 0, "Cell Count", 0, 15) -- Cel#
    for i = 1, cnt do
        val, pos = decU8(data, pos)
        val = val > 0 and val + 200 or 0
        vol = (cnt << 24) | ((i - 1) << 16) | val
        setTelemetryValue(0x102F, 0, 0, vol, UNIT_CELLS, 2, "Cell Voltages", 0, 455) -- Cels
    end
    return nil, pos
end

--[[
    decControl - Decodes control data and sets telemetry values for pitch, roll, yaw, and collective control.

    Parameters:
    data (string) - The data to decode.
    pos (number) - The current position in the data string.

    Returns:
    nil, pos (number) - Always returns nil and the updated position in the data string.
]]
local function decControl(data, pos)
    local r, p, y, c
    p, r, pos = decS12S12(data, pos)
    y, c, pos = decS12S12(data, pos)
    setTelemetryValue(0x1031, 0, 0, p, UNIT_DEGREE, 2, "Pitch Control", -4500, 4500) -- CPtc
    setTelemetryValue(0x1032, 0, 0, r, UNIT_DEGREE, 2, "Roll Control", -4500, 4500) -- CRol
    setTelemetryValue(0x1033, 0, 0, 3 * y, UNIT_DEGREE, 2, "Yaw Control", -9000, 9000) -- CYaw
    setTelemetryValue(0x1034, 0, 0, c, UNIT_DEGREE, 2, "Coll Control", -4500, 4500) -- CCol
    return nil, pos
end

--[[
    decAttitude - Decodes attitude data from a given position in the data stream.
    
    Parameters:
    data (string) - The data stream containing the attitude information.
    pos (number) - The current position in the data stream to start decoding from.
    
    Returns:
    nil - Always returns nil.
    pos (number) - The updated position in the data stream after decoding.
    
    Description:
    This function decodes pitch, roll, and yaw attitude values from the data stream
    starting at the specified position. It then sets telemetry values for pitch, roll,
    and yaw attitudes using the setTelemetryValue function.
--]]
local function decAttitude(data, pos)
    local p, r, y
    p, pos = decS16(data, pos)
    r, pos = decS16(data, pos)
    y, pos = decS16(data, pos)
    setTelemetryValue(0x1101, 0, 0, p, UNIT_DEGREE, 1, "Pitch Attitude", -1800, 3600) -- Ptch
    setTelemetryValue(0x1102, 0, 0, r, UNIT_DEGREE, 1, "Roll Attitude", -1800, 3600) -- Roll
    setTelemetryValue(0x1103, 0, 0, y, UNIT_DEGREE, 1, "Yaw Attitude", -1800, 3600) -- Yaw
    return nil, pos
end

--[[
    decAccel - Decodes accelerometer data from a given data stream and sets telemetry values.

    Parameters:
    data (string) - The data stream containing accelerometer values.
    pos (number) - The current position in the data stream.

    Returns:
    nil, pos (number) - Returns nil and the updated position in the data stream.

    The function decodes three 16-bit signed integers from the data stream representing
    the X, Y, and Z accelerometer values. It then sets these values as telemetry data
    with appropriate units and ranges.
]]
local function decAccel(data, pos)
    local x, y, z
    x, pos = decS16(data, pos)
    y, pos = decS16(data, pos)
    z, pos = decS16(data, pos)
    setTelemetryValue(0x1111, 0, 0, x, UNIT_G, 2, "Accel X", -4000, 4000) -- AccX
    setTelemetryValue(0x1112, 0, 0, y, UNIT_G, 2, "Accel Y", -4000, 4000) -- AccY
    setTelemetryValue(0x1113, 0, 0, z, UNIT_G, 2, "Accel Z", -4000, 4000) -- AccZ
    return nil, pos
end

--[[
    decLatLong - Decodes latitude and longitude from the given data and sets telemetry values.

    Parameters:
    data (string) - The data containing encoded latitude and longitude.
    pos (number) - The position in the data to start decoding from.

    Returns:
    nil, pos (number) - Returns nil and the updated position after decoding.
]]
local function decLatLong(data, pos)
    local lat, lon
    lat, pos = decS32(data, pos)
    lon, pos = decS32(data, pos)

    lat = math.floor(lat * 0.001)
    lon = math.floor(lon * 0.001)

    setTelemetryValue(0x1125, 0, 0, lat, UNIT_DEGREE, 4, "GPS Latitude", -10000000000, 10000000000)
    setTelemetryValue(0x112B, 0, 0, lon, UNIT_DEGREE, 4, "GPS Longitude", -10000000000, 10000000000)
    return nil, pos
end

--[[
    decAdjFunc - Decodes adjustment function and value from telemetry data.

    Parameters:
        data (string): The telemetry data to decode.
        pos (number): The current position in the data string.

    Returns:
        nil: Always returns nil.
        pos (number): The updated position in the data string after decoding.

    Description:
        This function decodes a 16-bit unsigned integer (function) and a 32-bit signed integer (value) from the given telemetry data.
        It then sets two telemetry values:
        - Adj. Source (0x1221) with the decoded function.
        - Adj. Value (0x1222) with the decoded value.
]]
local function decAdjFunc(data, pos)
    local fun, val
    fun, pos = decU16(data, pos)
    val, pos = decS32(data, pos)
    setTelemetryValue(0x1221, 0, 0, fun, UNIT_RAW, 0, "Adj. Source", 0, 255) -- AdjF
    setTelemetryValue(0x1222, 0, 0, val, UNIT_RAW, 0, "Adj. Value") -- AdjV
    return nil, pos
end

--[[
    elrs.RFSensors is a table that maps sensor IDs to their respective sensor configurations.
    Each sensor configuration includes:
    - name: The human-readable name of the sensor.
    - unit: The unit of measurement for the sensor's value.
    - prec: The precision of the sensor's value.
    - min: The minimum value the sensor can report.
    - max: The maximum value the sensor can report.
    - dec: The function used to decode the sensor's value.
]]
elrs.RFSensors = {
    -- No data
    [0x1000] = {name = "NULL", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decNil},
    -- Heartbeat (millisecond uptime % 60000)
    [0x1001] = {name = "Heartbeat", unit = UNIT_RAW, prec = 0, min = 0, max = 60000, dec = decU16},

    -- Main battery voltage
    [0x1011] = {name = "Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    -- Main battery current
    [0x1012] = {name = "Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    -- Main battery used capacity
    [0x1013] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    -- Main battery charge / fuel level
    [0x1014] = {name = "Charge Level", unit = UNIT_PERCENT, prec = 0, min = 0, max = 100, dec = decU8},

    -- Main battery cell count
    [0x1020] = {name = "Cell Count", unit = UNIT_RAW, prec = 0, min = 0, max = 16, dec = decU8},
    -- Main battery cell voltage (minimum/average)
    [0x1021] = {name = "Cell Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 455, dec = decCellV},
    -- Main battery cell voltages
    [0x102F] = {name = "Cell Voltages", unit = UNIT_VOLT, prec = 2, min = nil, max = nil, dec = decCells},

    -- Control Combined (hires)
    [0x1030] = {name = "Ctrl", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decControl},
    -- Pitch Control angle
    [0x1031] = {name = "Pitch Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    -- Roll Control angle
    [0x1032] = {name = "Roll Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    -- Yaw Control angle
    [0x1033] = {name = "Yaw Control", unit = UNIT_DEGREE, prec = 1, min = -900, max = 900, dec = decS16},
    -- Collective Control angle
    [0x1034] = {name = "Coll Control", unit = UNIT_DEGREE, prec = 1, min = -450, max = 450, dec = decS16},
    -- Throttle output %
    [0x1035] = {name = "Throttle %", unit = UNIT_PERCENT, prec = 0, min = -100, max = 100, dec = decS8},

    -- ESC#1 voltage
    [0x1041] = {name = "ESC1 Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    -- ESC#1 current
    [0x1042] = {name = "ESC1 Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    -- ESC#1 capacity/consumption
    [0x1043] = {name = "ESC1 Consump", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    -- ESC#1 eRPM
    [0x1044] = {name = "ESC1 eRPM", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU24},
    -- ESC#1 PWM/Power
    [0x1045] = {name = "ESC1 PWM", unit = UNIT_PERCENT, prec = 1, min = 0, max = 1000, dec = decU16},
    -- ESC#1 throttle
    [0x1046] = {name = "ESC1 Throttle", unit = UNIT_PERCENT, prec = 1, min = 0, max = 1000, dec = decU16},
    -- ESC#1 temperature
    [0x1047] = {name = "ESC1 Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- ESC#1 / BEC temperature
    [0x1048] = {name = "ESC1 Temp 2", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- ESC#1 / BEC voltage
    [0x1049] = {name = "ESC1 BEC Volt", unit = UNIT_VOLT, prec = 2, min = 0, max = 1500, dec = decU16},
    -- ESC#1 / BEC current
    [0x104A] = {name = "ESC1 BEC Curr", unit = UNIT_AMPERE, prec = 2, min = 0, max = 10000, dec = decU16},
    -- ESC#1 Status Flags
    [0x104E] = {name = "ESC1 Status", unit = UNIT_RAW, prec = 0, min = 0, max = 2147483647, dec = decU32},
    -- ESC#1 Model Id
    [0x104F] = {name = "ESC1 Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    -- ESC#2 voltage
    [0x1051] = {name = "ESC2 Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    -- ESC#2 current
    [0x1052] = {name = "ESC2 Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    -- ESC#2 capacity/consumption
    [0x1053] = {name = "ESC2 Consump", unit = UNIT_MILLIAMPERE_HOUR, prec = 0, min = 0, max = 65000, dec = decU16},
    -- ESC#2 eRPM
    [0x1054] = {name = "ESC2 eRPM", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU24},
    -- ESC#2 temperature
    [0x1057] = {name = "ESC2 Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- ESC#2 Model Id
    [0x105F] = {name = "ESC2 Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    -- Combined ESC voltage
    [0x1080] = {name = "ESC Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 6500, dec = decU16},
    -- BEC voltage
    [0x1081] = {name = "BEC Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 1600, dec = decU16},
    -- BUS voltage
    [0x1082] = {name = "BUS Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 1200, dec = decU16},
    -- MCU voltage
    [0x1083] = {name = "MCU Voltage", unit = UNIT_VOLT, prec = 2, min = 0, max = 500, dec = decU16},

    -- Combined ESC current
    [0x1090] = {name = "ESC Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 65000, dec = decU16},
    -- BEC current
    [0x1091] = {name = "BEC Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 10000, dec = decU16},
    -- BUS current
    [0x1092] = {name = "BUS Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 1000, dec = decU16},
    -- MCU current
    [0x1093] = {name = "MCU Current", unit = UNIT_AMPERE, prec = 2, min = 0, max = 1000, dec = decU16},

    -- Combined ESC temeperature
    [0x10A0] = {name = "ESC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- BEC temperature
    [0x10A1] = {name = "BEC Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},
    -- MCU temperature
    [0x10A3] = {name = "MCU Temp", unit = UNIT_CELSIUS, prec = 0, min = 0, max = 255, dec = decU8},

    -- Heading (combined gyro+mag+GPS)
    [0x10B1] = {name = "Heading", unit = UNIT_DEGREE, prec = 1, min = -1800, max = 3600, dec = decS16},
    -- Altitude (combined baro+GPS)
    [0x10B2] = {name = "Altitude", unit = UNIT_METER, prec = 2, min = -100000, max = 100000, dec = decS24},
    -- Variometer (combined baro+GPS)
    [0x10B3] = {name = "VSpeed", unit = UNIT_METER_PER_SECOND, prec = 2, min = -10000, max = 10000, dec = decS16},

    -- Headspeed
    [0x10C0] = {name = "Headspeed", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU16},
    -- Tailspeed
    [0x10C1] = {name = "Tailspeed", unit = UNIT_RPM, prec = 0, min = 0, max = 65535, dec = decU16},

    -- Attitude (hires combined)
    [0x1100] = {name = "Attd", unit = UNIT_DEGREE, prec = 1, min = nil, max = nil, dec = decAttitude},
    -- Attitude pitch
    [0x1101] = {name = "Pitch Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    -- Attitude roll
    [0x1102] = {name = "Roll Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},
    -- Attitude yaw
    [0x1103] = {name = "Yaw Attitude", unit = UNIT_DEGREE, prec = 0, min = -180, max = 360, dec = decS16},

    -- Acceleration (hires combined)
    [0x1110] = {name = "Accl", unit = UNIT_G, prec = 2, min = nil, max = nil, dec = decAccel},
    -- Acceleration X
    [0x1111] = {name = "Accel X", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    -- Acceleration Y
    [0x1112] = {name = "Accel Y", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},
    -- Acceleration Z
    [0x1113] = {name = "Accel Z", unit = UNIT_G, prec = 1, min = -4000, max = 4000, dec = decS16},

    -- GPS Satellite count
    [0x1121] = {name = "GPS Sats", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- GPS PDOP
    [0x1122] = {name = "GPS PDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- GPS HDOP
    [0x1123] = {name = "GPS HDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- GPS VDOP
    [0x1124] = {name = "GPS VDOP", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- GPS Coordinates
    [0x1125] = {name = "GPS Coord", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decLatLong},
    -- GPS altitude
    [0x1126] = {name = "GPS Altitude", unit = UNIT_METER, prec = 2, min = -100000000, max = 100000000, dec = decS16},
    -- GPS heading
    [0x1127] = {name = "GPS Heading", unit = UNIT_DEGREE, prec = 1, min = -1800, max = 3600, dec = decS16},
    -- GPS ground speed
    [0x1128] = {name = "GPS Speed", unit = UNIT_METER_PER_SECOND, prec = 2, min = 0, max = 10000, dec = decU16},
    -- GPS home distance
    [0x1129] = {name = "GPS Home Dist", unit = UNIT_METER, prec = 1, min = 0, max = 65535, dec = decU16},
    -- GPS home direction
    [0x112A] = {name = "GPS Home Dir", unit = UNIT_METER, prec = 1, min = 0, max = 3600, dec = decU16},

    -- CPU load
    [0x1141] = {name = "CPU Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 100, dec = decU8},
    -- System load
    [0x1142] = {name = "SYS Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 10, dec = decU8},
    -- Realtime CPU load
    [0x1143] = {name = "RT Load", unit = UNIT_PERCENT, prec = 0, min = 0, max = 200, dec = decU8},

    -- Model ID
    [0x1200] = {name = "Model ID", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- Flight mode flags
    [0x1201] = {name = "Flight Mode", unit = UNIT_RAW, prec = 0, min = 0, max = 65535, dec = decU16},
    -- Arming flags
    [0x1202] = {name = "Arming Flags", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- Arming disable flags
    [0x1203] = {name = "Arming Disable", unit = UNIT_RAW, prec = 0, min = 0, max = 2147483647, dec = decU32},
    -- Rescue state
    [0x1204] = {name = "Rescue", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},
    -- Governor state
    [0x1205] = {name = "Governor", unit = UNIT_RAW, prec = 0, min = 0, max = 255, dec = decU8},

    -- Current PID profile
    [0x1211] = {name = "PID Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    -- Current Rate profile
    [0x1212] = {name = "Rate Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},
    -- Current LED profile
    [0x1213] = {name = "LED Profile", unit = UNIT_RAW, prec = 0, min = 1, max = 6, dec = decU8},

    -- Adjustment function
    [0x1220] = {name = "ADJ", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decAdjFunc},

    -- Debug
    [0xDB00] = {name = "Debug 0", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB01] = {name = "Debug 1", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB02] = {name = "Debug 2", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB03] = {name = "Debug 3", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB04] = {name = "Debug 4", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB05] = {name = "Debug 5", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB06] = {name = "Debug 6", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32},
    [0xDB07] = {name = "Debug 7", unit = UNIT_RAW, prec = 0, min = nil, max = nil, dec = decS32}
}

elrs.telemetryFrameId = 0
elrs.telemetryFrameSkip = 0
elrs.telemetryFrameCount = 0

--[[
    Function: elrs.crossfirePop
    Description: Handles the processing of Crossfire telemetry frames for ELRS (ExpressLRS).
    Short: Processes Crossfire telemetry frames for ELRS.
    Use: This function is called to process incoming telemetry frames from the Crossfire protocol. It checks if telemetry is paused or if MSP (Multiwii Serial Protocol) is busy. If so, it mutes sensor lost warnings for a specified duration. Otherwise, it processes the telemetry frame, decodes sensor values, and updates telemetry values accordingly.
    Parameters: None
    Returns: 
        - true: if a telemetry frame was successfully processed.
        - false: if no telemetry frame was processed or if telemetry is paused/MSP is busy.
]]
function elrs.crossfirePop()

    if (CRSF_PAUSE_TELEMETRY == true or rfsuite.app.triggers.mspBusy == true or rfsuite.session.telemetryState == false) then
        local module = model.getModule(rfsuite.session.telemetrySensor:module())
        if module ~= nil and module.muteSensorLost ~= nil then module:muteSensorLost(5.0) end

        if rfsuite.session.telemetryState == false then
            sensors['uid'] = {}
            sensors['lastvalue'] = {}
        end

        return false
    else

        local command, data = elrs.popFrame()
        if command and data then

            if command == CRSF_FRAME_CUSTOM_TELEM then
                local fid, sid, val
                local ptr = 3
                fid, ptr = decU8(data, ptr)
                local delta = (fid - elrs.telemetryFrameId) & 0xFF
                if delta > 1 then elrs.telemetryFrameSkip = elrs.telemetryFrameSkip + 1 end
                elrs.telemetryFrameId = fid
                elrs.telemetryFrameCount = elrs.telemetryFrameCount + 1
                while ptr < #data do

                    sid, ptr = decU16(data, ptr)
                    local sensor = elrs.RFSensors[sid]
                    if sensor then
                        val, ptr = sensor.dec(data, ptr)
                        if val then setTelemetryValue(sid, 0, 0, val, sensor.unit, sensor.prec, sensor.name, sensor.min, sensor.max) end
                    else
                        break
                    end
                end
                setTelemetryValue(0xEE01, 0, 0, elrs.telemetryFrameCount, UNIT_RAW, 0, "Frame Count", 0, 2147483647) -- *Cnt
                setTelemetryValue(0xEE02, 0, 0, elrs.telemetryFrameSkip, UNIT_RAW, 0, "Frame Skip", 0, 2147483647) -- *Skp
                -- setTelemetryValue(0xEE03, 0, 0, elrs.telemetryFrameId, UNIT_RAW, 0, "*Frm", 0, 255)
            end

            return true
        end

        return false
    end
end

--[[
    Function: elrs.wakeup
    Description: This function is called to handle the wakeup event for the ELRS (ExpressLRS) module. It checks if telemetry is active and if the RSSI sensor is available. If both conditions are met, it processes the Crossfire telemetry data unless telemetry is paused or the MSP (Multiwii Serial Protocol) is busy.
    Usage: Call this function to manage the wakeup event for the ELRS module.
]]
function elrs.wakeup()

    if rfsuite.session.telemetryState and rfsuite.session.telemetrySensor then
        while elrs.crossfirePop() do
            if CRSF_PAUSE_TELEMETRY == true or rfsuite.app.triggers.mspBusy == true  then
                break
            end
        end
    else
        sensors['uid'] = {}
        sensors['lastvalue'] = {}          
    end
end

-- reset
function elrs.reset()
    sensors.uid = {}
    sensors.lastvalue = {}
end

return elrs
