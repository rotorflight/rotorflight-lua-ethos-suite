--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local mspHelper = {}
local math_floor = math.floor

-- Read an unsigned integer from buffer (advances buf.offset)
mspHelper.readUInt = function(buf, numBytes, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + numBytes - 1] then return nil end

    local value = 0
    if byteorder == "big" then
        -- Big-endian: highest byte first
        for i = 0, numBytes - 1 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    else
        -- Little-endian: lowest byte first
        for i = numBytes - 1, 0, -1 do
            value = value * 256 + (buf[offset + i] or 0)
        end
    end

    buf.offset = offset + numBytes
    return value
end

-- Read a signed integer (two’s complement) using readUInt
mspHelper.readSInt = function(buf, numBytes, byteorder)
    local value = mspHelper.readUInt(buf, numBytes, byteorder)
    if value == nil then return nil end

    local maxUnsigned = 2 ^ (8 * numBytes)
    local maxSigned   = maxUnsigned / 2

    -- Convert from unsigned to signed
    if value >= maxSigned then value = value - maxUnsigned end

    return value
end

-- Write an unsigned integer into buffer
mspHelper.writeUInt = function(buf, value, numBytes, byteorder)
    for i = 0, numBytes - 1 do
        local shift = (byteorder == "big")
                      and (8 * (numBytes - 1 - i))
                      or  (8 * i)
        buf[#buf + 1] = math_floor(value / 2 ^ shift) % 256
    end
end

-- Write a signed integer (two’s complement encoding)
mspHelper.writeSInt = function(buf, value, numBytes, byteorder)
    if value < 0 then
        value = value + 2 ^ (8 * numBytes)
    end
    mspHelper.writeUInt(buf, value, numBytes, byteorder)
end

-- Auto-generate convenience helpers for U8..U512 and S8..S512
for bits = 8, 512, 8 do
    local bytes = bits / 8
    mspHelper["readU" .. bits]  = function(buf, byteorder)
        return mspHelper.readUInt(buf, bytes, byteorder)
    end
    mspHelper["readS" .. bits]  = function(buf, byteorder)
        return mspHelper.readSInt(buf, bytes, byteorder)
    end
    mspHelper["writeU" .. bits] = function(buf, value, byteorder)
        mspHelper.writeUInt(buf, value, bytes, byteorder)
    end
    mspHelper["writeS" .. bits] = function(buf, value, byteorder)
        mspHelper.writeSInt(buf, value, bytes, byteorder)
    end
end

-- Optimized overrides for common types (avoid loop overhead)
mspHelper.readU8 = function(buf)
    local off = buf.offset or 1
    local v = buf[off]
    if not v then return nil end
    buf.offset = off + 1
    return v
end

mspHelper.readS8 = function(buf)
    local off = buf.offset or 1
    local v = buf[off]
    if not v then return nil end
    buf.offset = off + 1
    return (v > 127) and (v - 256) or v
end

mspHelper.readU16 = function(buf, byteorder)
    local off = buf.offset or 1
    local b1 = buf[off]
    local b2 = buf[off + 1]
    if not b2 then return nil end
    buf.offset = off + 2
    if byteorder == "big" then
        return (b1 << 8) | b2
    else
        return (b2 << 8) | b1
    end
end

mspHelper.readS16 = function(buf, byteorder)
    local v = mspHelper.readU16(buf, byteorder)
    if not v then return nil end
    return (v >= 0x8000) and (v - 0x10000) or v
end

mspHelper.readU32 = function(buf, byteorder)
    local off = buf.offset or 1
    local b1, b2, b3, b4 = buf[off], buf[off + 1], buf[off + 2], buf[off + 3]
    if not b4 then return nil end
    buf.offset = off + 4
    if byteorder == "big" then
        return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
    else
        return b1 | (b2 << 8) | (b3 << 16) | (b4 << 24)
    end
end

mspHelper.readS32 = function(buf, byteorder)
    local v = mspHelper.readU32(buf, byteorder)
    if not v then return nil end
    return (v >= 0x80000000) and (v - 0x100000000) or v
end

mspHelper.writeU8 = function(buf, value)
    buf[#buf + 1] = value & 0xFF
end

mspHelper.writeS8 = function(buf, value)
    if value < 0 then value = value + 0x100 end
    buf[#buf + 1] = value & 0xFF
end

mspHelper.writeU16 = function(buf, value, byteorder)
    if byteorder == "big" then
        buf[#buf + 1] = (value >> 8) & 0xFF
        buf[#buf + 1] = value & 0xFF
    else
        buf[#buf + 1] = value & 0xFF
        buf[#buf + 1] = (value >> 8) & 0xFF
    end
end

mspHelper.writeS16 = function(buf, value, byteorder)
    if value < 0 then value = value + 0x10000 end
    mspHelper.writeU16(buf, value, byteorder)
end

mspHelper.writeU32 = function(buf, value, byteorder)
    if byteorder == "big" then
        buf[#buf + 1] = (value >> 24) & 0xFF
        buf[#buf + 1] = (value >> 16) & 0xFF
        buf[#buf + 1] = (value >> 8) & 0xFF
        buf[#buf + 1] = value & 0xFF
    else
        buf[#buf + 1] = value & 0xFF
        buf[#buf + 1] = (value >> 8) & 0xFF
        buf[#buf + 1] = (value >> 16) & 0xFF
        buf[#buf + 1] = (value >> 24) & 0xFF
    end
end

mspHelper.writeS32 = function(buf, value, byteorder)
    if value < 0 then value = value + 0x100000000 end
    mspHelper.writeU32(buf, value, byteorder)
end

-- Write a raw byte into the buffer
mspHelper.writeRAW = function(buf, value)
    buf[#buf + 1] = value
end

return mspHelper
