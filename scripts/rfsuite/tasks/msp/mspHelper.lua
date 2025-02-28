--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note. Some icons have been sourced from https://www.flaticon.com/
 *
]] --
local mspHelper = {}


--[[
Reads an unsigned 8-bit integer from the buffer at the current offset.
Increments the offset by 1 after reading.

@param buf (table) The buffer table containing the data and the current offset.
@return (number or nil) The unsigned 8-bit integer read from the buffer, or nil if the offset is out of bounds.
]]
mspHelper.readU8 = function(buf)
    local offset = buf.offset or 1
    if not buf[offset] then
        return nil
    end
    local value = buf[offset]
    buf.offset = offset + 1
    return value
end

--[[
    Reads a signed 8-bit integer from the buffer at the current offset.
    
    @param buf (table): The buffer table containing the data and the current offset.
                        The offset is expected to be stored in buf.offset.
    
    @return (number): The signed 8-bit integer read from the buffer, or nil if the offset is out of bounds.
]]
mspHelper.readS8 = function(buf)
    local offset = buf.offset or 1
    if not buf[offset] then
        return nil
    end
    local value = buf[offset]
    if value >= 128 then value = value - 256 end
    buf.offset = offset + 1
    return value
end

--[[
    Reads a 16-bit unsigned integer from a buffer.

    @param buf (table): The buffer table containing the data and an optional offset.
    @param byteorder (string): The byte order, either "big" for big-endian or any other value for little-endian.
    @return (number or nil): The 16-bit unsigned integer read from the buffer, or nil if there is not enough data.
]]
mspHelper.readU16 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 1] then
        return nil
    end
    local value = (buf[offset] or 0) + (buf[offset + 1] or 0) * 256
    if byteorder == "big" then value = (buf[offset] or 0) * 256 + (buf[offset + 1] or 0) end
    buf.offset = offset + 2
    return value
end

--[[
    Reads a signed 16-bit integer from the given buffer.
    
    @param buf The buffer to read from.
    @param byteorder The byte order to use for reading.
    @return The signed 16-bit integer value, or nil if the value could not be read.
]]
mspHelper.readS16 = function(buf, byteorder)
    local value = mspHelper.readU16(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 32768 then value = value - 65536 end
    return value
end


--[[
Reads a 24-bit unsigned integer from the buffer.

@param buf (table) The buffer table containing the data and an optional offset.
@param byteorder (string) The byte order, either "big" for big-endian or any other value for little-endian.
@return (number) The 24-bit unsigned integer read from the buffer, or nil if the buffer does not contain enough data.
]]
mspHelper.readU24 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 2] then
        return nil
    end
    local value = (buf[offset] or 0) + (buf[offset + 1] or 0) * 256 + (buf[offset + 2] or 0) * 65536
    if byteorder == "big" then value = (buf[offset] or 0) * 65536 + (buf[offset + 1] or 0) * 256 + (buf[offset + 2] or 0) end
    buf.offset = offset + 3
    return value
end

--[[
    Reads a signed 24-bit integer from the buffer.
    
    @param buf The buffer to read from.
    @param byteorder The byte order to use (e.g., "big" or "little").
    @return The signed 24-bit integer, or nil if the value could not be read.
]]
mspHelper.readS24 = function(buf, byteorder)
    local value = mspHelper.readU24(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 8388608 then value = value - 16777216 end
    return value
end

--[[
    Reads a 32-bit unsigned integer from a buffer.

    @param buf (table) The buffer table containing the bytes to read. The buffer should have an 'offset' field indicating the current read position.
    @param byteorder (string) The byte order to use for reading the integer. Can be "big" for big-endian or any other value for little-endian.
    
    @return (number) The 32-bit unsigned integer read from the buffer, or nil if there are not enough bytes to read.
]]
mspHelper.readU32 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 3] then
        return nil
    end
    local value = (buf[offset] or 0) + (buf[offset + 1] or 0) * 256 + (buf[offset + 2] or 0) * 65536 + (buf[offset + 3] or 0) * 16777216
    if byteorder == "big" then value = (buf[offset] or 0) * 16777216 + (buf[offset + 1] or 0) * 65536 + (buf[offset + 2] or 0) * 256 + (buf[offset + 3] or 0) end
    buf.offset = offset + 4
    return value
end

--[[
    Reads a signed 32-bit integer from the buffer.
    
    @param buf The buffer to read from.
    @param byteorder The byte order to use when reading the buffer.
    @return The signed 32-bit integer read from the buffer, or nil if the value could not be read.
]]
mspHelper.readS32 = function(buf, byteorder)
    local value = mspHelper.readU32(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2147483648 then value = value - 4294967296 end
    return value
end

--[[
    Reads a 48-bit unsigned integer from the buffer.

    @param buf (table): The buffer table containing the data and an optional offset.
    @param byteorder (string): The byte order to use, either "big" for big-endian or "little" for little-endian.
    @return (number or nil): The 48-bit unsigned integer read from the buffer, or nil if the buffer does not contain enough data.
]]
mspHelper.readU48 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 5] then
        return nil
    end
    local value = 0
    if byteorder == "big" then
        for i = 0, 5 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    else
        for i = 5, 0, -1 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    end
    buf.offset = offset + 6
    return value
end

--[[
    Reads a signed 48-bit integer from the buffer.

    @param buf The buffer to read from.
    @param byteorder The byte order to use when reading the buffer.
    @return The signed 48-bit integer, or nil if the value could not be read.
]]
mspHelper.readS48 = function(buf, byteorder)
    local value = mspHelper.readU48(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2^47 then value = value - 2^48 end
    return value
end

--[[
Reads an unsigned 64-bit integer from the buffer.

@param buf (table) The buffer table containing the data and an optional offset.
@param byteorder (string) The byte order to use for reading ("big" for big-endian, otherwise little-endian).
@return (number or nil) The 64-bit unsigned integer read from the buffer, or nil if there are not enough bytes.
]]
mspHelper.readU64 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 7] then
        return nil
    end
    local value = 0
    if byteorder == "big" then
        for i = 0, 7 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    else
        for i = 7, 0, -1 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    end
    buf.offset = offset + 8
    return value
end

--[[
    Reads a signed 64-bit integer from the buffer.
    
    @param buf The buffer to read from.
    @param byteorder The byte order to use when reading the buffer.
    @return The signed 64-bit integer read from the buffer, or nil if the read operation fails.
]]
mspHelper.readS64 = function(buf, byteorder)
    local value = mspHelper.readU64(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2^63 then value = value - 2^64 end
    return value
end

--[[
Reads a 72-bit unsigned integer from the buffer.

@param buf (table) The buffer table containing the data and an optional offset.
@param byteorder (string) The byte order to use, either "big" for big-endian or any other value for little-endian.
@return (number) The 72-bit unsigned integer read from the buffer, or nil if the buffer does not contain enough data.
]]
mspHelper.readU72 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 8] then
        return nil
    end
    local value = 0
    if byteorder == "big" then
        for i = 0, 8 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    else
        for i = 8, 0, -1 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    end
    buf.offset = offset + 9
    return value
end

--[[
    Reads a signed 72-bit integer from the buffer.

    @param buf The buffer to read from.
    @param byteorder The byte order to use when reading the buffer.
    @return The signed 72-bit integer value, or nil if the value could not be read.
]]
mspHelper.readS72 = function(buf, byteorder)
    local value = mspHelper.readU72(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2^71 then value = value - 2^72 end
    return value
end

--[[
Reads a 128-bit unsigned integer from the buffer.

@param buf The buffer table containing the data and an optional offset.
@param byteorder The byte order to use ("big" for big-endian, anything else for little-endian).
@return The 128-bit unsigned integer read from the buffer, or nil if there is not enough data.
]]
mspHelper.readU128 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 15] then
        return nil
    end
    local value = 0
    if byteorder == "big" then
        for i = 0, 15 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    else
        for i = 15, 0, -1 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    end
    buf.offset = offset + 16
    return value
end

--[[
    Reads a signed 128-bit integer from the buffer.

    @param buf The buffer to read from.
    @param byteorder The byte order to use when reading the integer.
    @return The signed 128-bit integer, or nil if the value could not be read.
]]
mspHelper.readS128 = function(buf, byteorder)
    local value = mspHelper.readU128(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2^127 then value = value - 2^128 end
    return value
end

--[[
    Writes an 8-bit unsigned integer to the buffer.
    
    @param buf (table) The buffer to write to.
    @param value (number) The 8-bit unsigned integer value to write.
]]
mspHelper.writeU8 = function(buf, value)
    buf[#buf + 1] = value % 256
end

--[[
Writes an 8-bit signed integer to the buffer.

@param buf (table) The buffer to write the value to.
@param value (number) The 8-bit signed integer to write. If the value is negative, it is converted to its unsigned equivalent.
]]
mspHelper.writeS8 = function(buf, value)
    if value < 0 then value = value + 256 end
    buf[#buf + 1] = value % 256
end

--[[
Writes a 16-bit unsigned integer to the buffer in the specified byte order.

Parameters:
- buf (table): The buffer to write the value to.
- value (number): The 16-bit unsigned integer value to write.
- byteorder (string): The byte order to use ("big" for big-endian, otherwise little-endian).

Returns:
- None
]]
mspHelper.writeU16 = function(buf, value, byteorder)
    if byteorder == "big" then
        buf[#buf + 1] = math.floor(value / 256) % 256
        buf[#buf + 1] = value % 256
    else
        buf[#buf + 1] = value % 256
        buf[#buf + 1] = math.floor(value / 256) % 256
    end
end

--[[
Writes a signed 16-bit integer to the buffer in the specified byte order.
If the value is negative, it is converted to its unsigned equivalent before writing.

Parameters:
- buf: The buffer to write the value to.
- value: The signed 16-bit integer to write.
- byteorder: The byte order to use when writing the value (e.g., "big" or "little").
]]
mspHelper.writeS16 = function(buf, value, byteorder)
    if value < 0 then value = value + 65536 end
    mspHelper.writeU16(buf, value, byteorder)
end

--[[
Writes a 24-bit unsigned integer to the buffer in the specified byte order.

@param buf (table) The buffer to write the value to.
@param value (number) The 24-bit unsigned integer value to write.
@param byteorder (string) The byte order to use ("big" for big-endian, otherwise little-endian).
]]
mspHelper.writeU24 = function(buf, value, byteorder)
    if byteorder == "big" then
        buf[#buf + 1] = math.floor(value / 65536) % 256
        buf[#buf + 1] = math.floor(value / 256) % 256
        buf[#buf + 1] = value % 256
    else
        buf[#buf + 1] = value % 256
        buf[#buf + 1] = math.floor(value / 256) % 256
        buf[#buf + 1] = math.floor(value / 65536) % 256
    end
end

--[[
Writes a signed 24-bit integer to the buffer in the specified byte order.

@param buf The buffer to write to.
@param value The signed 24-bit integer value to write.
@param byteorder The byte order to use (e.g., "big" or "little").
]]
mspHelper.writeS24 = function(buf, value, byteorder)
    if value < 0 then value = value + 16777216 end
    mspHelper.writeU24(buf, value, byteorder)
end

--[[
Writes a 32-bit unsigned integer to a buffer in either big-endian or little-endian byte order.

Parameters:
- buf (table): The buffer to write the value to.
- value (number): The 32-bit unsigned integer value to write.
- byteorder (string): The byte order to use ("big" for big-endian, any other value for little-endian).

Returns:
- None
]]
mspHelper.writeU32 = function(buf, value, byteorder)
    if byteorder == "big" then
        buf[#buf + 1] = math.floor(value / 16777216) % 256
        buf[#buf + 1] = math.floor(value / 65536) % 256
        buf[#buf + 1] = math.floor(value / 256) % 256
        buf[#buf + 1] = value % 256
    else
        buf[#buf + 1] = value % 256
        buf[#buf + 1] = math.floor(value / 256) % 256
        buf[#buf + 1] = math.floor(value / 65536) % 256
        buf[#buf + 1] = math.floor(value / 16777216) % 256
    end
end

--[[
Writes a signed 32-bit integer to the buffer in the specified byte order.
If the value is negative, it is converted to its unsigned equivalent before writing.

Parameters:
- buf: The buffer to write the value to.
- value: The signed 32-bit integer to write.
- byteorder: The byte order to use when writing the value (e.g., "big" or "little").
]]
mspHelper.writeS32 = function(buf, value, byteorder)
    if value < 0 then value = value + 4294967296 end
    mspHelper.writeU32(buf, value, byteorder)
end

--[[
    Writes a 48-bit unsigned integer to a buffer in either big-endian or little-endian byte order.

    @param buf (table) The buffer to write the value to.
    @param value (number) The 48-bit unsigned integer value to write.
    @param byteorder (string) The byte order to use ("big" for big-endian, anything else for little-endian).
]]
mspHelper.writeU48 = function(buf, value, byteorder)
    if byteorder == "big" then
        for i = 5, 0, -1 do
            buf[#buf + 1] = math.floor(value / 256^i) % 256
        end
    else
        for i = 0, 5 do
            buf[#buf + 1] = math.floor(value / 256^i) % 256
        end
    end
end

--[[
    Writes a signed 48-bit integer to the buffer in the specified byte order.
    
    @param buf The buffer to write to.
    @param value The signed 48-bit integer value to write.
    @param byteorder The byte order to use when writing the value.
]]
mspHelper.writeS48 = function(buf, value, byteorder)
    if value < 0 then value = value + 2^48 end
    mspHelper.writeU48(buf, value, byteorder)
end

--[[
    Writes a 64-bit unsigned integer to a buffer in either big-endian or little-endian byte order.

    @param buf (table) The buffer to write the value to.
    @param value (number) The 64-bit unsigned integer value to write.
    @param byteorder (string) The byte order to use ("big" for big-endian, anything else for little-endian).
]]
mspHelper.writeU64 = function(buf, value, byteorder)
    if byteorder == "big" then
        for i = 7, 0, -1 do
            buf[#buf + 1] = math.floor(value / 256^i) % 256
        end
    else
        for i = 0, 7 do
            buf[#buf + 1] = math.floor(value / 256^i) % 256
        end
    end
end

--[[
Writes a signed 64-bit integer to the buffer in the specified byte order.

@param buf The buffer to write to.
@param value The signed 64-bit integer value to write.
@param byteorder The byte order to use (e.g., "big" or "little").
]]
mspHelper.writeS64 = function(buf, value, byteorder)
    if value < 0 then value = value + 2^64 end
    mspHelper.writeU64(buf, value, byteorder)
end

--[[
    Writes a 128-bit unsigned integer to a buffer in either big-endian or little-endian byte order.

    @param buf (table) The buffer to write the value to.
    @param value (number) The 128-bit unsigned integer value to write.
    @param byteorder (string) The byte order to use ("big" for big-endian, anything else for little-endian).
]]
mspHelper.writeU128 = function(buf, value, byteorder)
    if byteorder == "big" then
        for i = 15, 0, -1 do
            buf[#buf + 1] = math.floor(value / 256^i) % 256
        end
    else
        for i = 0, 15 do
            buf[#buf + 1] = math.floor(value / 256^i) % 256
        end
    end
end

--[[
    Function: writeU72
    Writes a 72-bit unsigned integer to a buffer in either big-endian or little-endian byte order.

    Parameters:
    buf (table) - The buffer to write the value to.
    value (number) - The 72-bit unsigned integer value to write.
    byteorder (string) - The byte order to use ("big" for big-endian, anything else for little-endian).

    Usage:
    mspHelper.writeU72(buffer, 12345678901234567890, "big")
]]
mspHelper.writeU72 = function(buf, value, byteorder)
    if byteorder == "big" then
        for i = 8, 0, -1 do
            buf[#buf + 1] = math.floor(value / 256^i) % 256
        end
    else
        for i = 0, 8 do
            buf[#buf + 1] = math.floor(value / 256^i) % 256
        end
    end
end

--[[
Writes a signed 72-bit integer to the buffer in the specified byte order.

@param buf The buffer to write to.
@param value The signed 72-bit integer value to write.
@param byteorder The byte order to use (e.g., "big" or "little").
]]
mspHelper.writeS72 = function(buf, value, byteorder)
    if value < 0 then value = value + 2^72 end
    mspHelper.writeU72(buf, value, byteorder)
end

--[[
Writes a signed 128-bit integer to the buffer in the specified byte order.
If the value is negative, it is converted to its unsigned equivalent.
Parameters:
    buf (table): The buffer to write to.
    value (number): The signed 128-bit integer value to write.
    byteorder (string): The byte order to use ("big" or "little").
]]
mspHelper.writeS128 = function(buf, value, byteorder)
    if value < 0 then value = value + 2^128 end
    mspHelper.writeU128(buf, value, byteorder)
end


--[[
    Function: mspHelper.writeRAW
    Description: Appends a given value to the end of the provided buffer.
    Parameters:
        buf (table) - The buffer to which the value will be appended.
        value (any) - The value to append to the buffer.
]]
mspHelper.writeRAW = function(buf, value)
    buf[#buf + 1] = value
end

return mspHelper
