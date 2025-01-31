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
local mspHelper = {
    -- Read functions with endianness handling
    readU8 = function(buf)
        local offset = buf.offset or 1
        local value = buf[offset]
        buf.offset = offset + 1
        return value
    end,
    readS8 = function(buf)
        local offset = buf.offset or 1
        local value = buf[offset]
        if value >= 128 then value = value - 256 end
        buf.offset = offset + 1
        return value
    end,
    readU16 = function(buf, byteorder)
        local offset = buf.offset or 1
        local value
        if byteorder == "big" then
            value = buf[offset] * 256 + buf[offset + 1]
        else -- Default to little-endian
            value = buf[offset] + buf[offset + 1] * 256
        end
        buf.offset = offset + 2
        return value
    end,
    readS16 = function(buf, byteorder)
        local offset = buf.offset or 1
        local value
        if byteorder == "big" then
            value = buf[offset] * 256 + buf[offset + 1]
        else
            value = buf[offset] + buf[offset + 1] * 256
        end
        if value >= 32768 then value = value - 65536 end
        buf.offset = offset + 2
        return value
    end,
    readU32 = function(buf, byteorder)
        local offset = buf.offset or 1
        local value
        if byteorder == "big" then
            value = buf[offset] * 16777216 + buf[offset + 1] * 65536 +
                        buf[offset + 2] * 256 + buf[offset + 3]
        else
            value = buf[offset] + buf[offset + 1] * 256 + buf[offset + 2] *
                        65536 + buf[offset + 3] * 16777216
        end
        buf.offset = offset + 4
        return value
    end,
    readS32 = function(buf, byteorder)
        local offset = buf.offset or 1
        local value
        if byteorder == "big" then
            value = buf[offset] * 16777216 + buf[offset + 1] * 65536 +
                        buf[offset + 2] * 256 + buf[offset + 3]
        else
            value = buf[offset] + buf[offset + 1] * 256 + buf[offset + 2] *
                        65536 + buf[offset + 3] * 16777216
        end
        if value >= 2147483648 then value = value - 4294967296 end
        buf.offset = offset + 4
        return value
    end,
    -- Write functions with endianness handling
    writeU8 = function(buf, value)
        buf[#buf + 1] = value % 256
    end,
    writeS8 = function(buf, value)
        if value < 0 then value = value + 256 end
        buf[#buf + 1] = value % 256
    end,
    writeU16 = function(buf, value, byteorder)
        if byteorder == "big" then
            buf[#buf + 1] = math.floor(value / 256) % 256
            buf[#buf + 1] = value % 256
        else
            buf[#buf + 1] = value % 256
            buf[#buf + 1] = math.floor(value / 256) % 256
        end
    end,
    writeS16 = function(buf, value, byteorder)
        if value < 0 then value = value + 65536 end
        mspHelper.writeU16(buf, value, byteorder)
    end,
    writeU32 = function(buf, value, byteorder)
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
    end,
    writeS32 = function(buf, value, byteorder)
        if value < 0 then value = value + 4294967296 end
        mspHelper.writeU32(buf, value, byteorder)
    end,
    writeRAW = function(buf, value)
        buf[#buf + 1] = value
    end
}

return mspHelper
