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


mspHelper.readU8 = function(buf)
    local offset = buf.offset or 1
    if not buf[offset] then
        return nil
    end
    local value = buf[offset]
    buf.offset = offset + 1
    return value
end

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

mspHelper.readS16 = function(buf, byteorder)
    local value = mspHelper.readU16(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 32768 then value = value - 65536 end
    return value
end


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

mspHelper.readS24 = function(buf, byteorder)
    local value = mspHelper.readU24(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 8388608 then value = value - 16777216 end
    return value
end

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

mspHelper.readS32 = function(buf, byteorder)
    local value = mspHelper.readU32(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2147483648 then value = value - 4294967296 end
    return value
end

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

mspHelper.readS48 = function(buf, byteorder)
    local value = mspHelper.readU48(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2^47 then value = value - 2^48 end
    return value
end

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

mspHelper.readS64 = function(buf, byteorder)
    local value = mspHelper.readU64(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2^63 then value = value - 2^64 end
    return value
end

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

mspHelper.readS72 = function(buf, byteorder)
    local value = mspHelper.readU72(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2^71 then value = value - 2^72 end
    return value
end

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

mspHelper.readS128 = function(buf, byteorder)
    local value = mspHelper.readU128(buf, byteorder)
    if value == nil then
        return nil
    end
    if value >= 2^127 then value = value - 2^128 end
    return value
end

mspHelper.writeU8 = function(buf, value)
    buf[#buf + 1] = value % 256
end

mspHelper.writeS8 = function(buf, value)
    if value < 0 then value = value + 256 end
    buf[#buf + 1] = value % 256
end

mspHelper.writeU16 = function(buf, value, byteorder)
    if byteorder == "big" then
        buf[#buf + 1] = math.floor(value / 256) % 256
        buf[#buf + 1] = value % 256
    else
        buf[#buf + 1] = value % 256
        buf[#buf + 1] = math.floor(value / 256) % 256
    end
end

mspHelper.writeS16 = function(buf, value, byteorder)
    if value < 0 then value = value + 65536 end
    mspHelper.writeU16(buf, value, byteorder)
end

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

mspHelper.writeS24 = function(buf, value, byteorder)
    if value < 0 then value = value + 16777216 end
    mspHelper.writeU24(buf, value, byteorder)
end

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

mspHelper.writeS32 = function(buf, value, byteorder)
    if value < 0 then value = value + 4294967296 end
    mspHelper.writeU32(buf, value, byteorder)
end

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

mspHelper.writeS48 = function(buf, value, byteorder)
    if value < 0 then value = value + 2^48 end
    mspHelper.writeU48(buf, value, byteorder)
end

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

mspHelper.writeS64 = function(buf, value, byteorder)
    if value < 0 then value = value + 2^64 end
    mspHelper.writeU64(buf, value, byteorder)
end

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

mspHelper.writeS72 = function(buf, value, byteorder)
    if value < 0 then value = value + 2^72 end
    mspHelper.writeU72(buf, value, byteorder)
end

mspHelper.writeS128 = function(buf, value, byteorder)
    if value < 0 then value = value + 2^128 end
    mspHelper.writeU128(buf, value, byteorder)
end


mspHelper.writeRAW = function(buf, value)
    buf[#buf + 1] = value
end

return mspHelper
