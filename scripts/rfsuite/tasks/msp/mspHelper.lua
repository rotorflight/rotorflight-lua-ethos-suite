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

local function debugPrint(message)
    print("[MSP HELPER DEBUG] " .. message)
    if system:getVersion().simulation == true then print("Check MSP_API_SIMULATOR_RESPONSE matches structure") end
end

mspHelper.readU8 = function(buf)
    local offset = buf.offset or 1
    if not buf[offset] then
        debugPrint("Nil offset found in readU8 at position " .. offset)
        return nil
    end
    local value = buf[offset]
    buf.offset = offset + 1
    return value
end

mspHelper.readS8 = function(buf)
    local offset = buf.offset or 1
    if not buf[offset] then
        debugPrint("Nil offset found in readS8 at position " .. offset)
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
        debugPrint("Nil offset found in readU16 at position " .. offset)
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
        debugPrint("Nil value found in readS16")
        return nil
    end
    if value >= 32768 then value = value - 65536 end
    return value
end

mspHelper.readU24 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 2] then
        debugPrint("Nil offset found in readU24 at position " .. offset)
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
        debugPrint("Nil value found in readS24")
        return nil
    end
    if value >= 8388608 then value = value - 16777216 end
    return value
end

mspHelper.readU32 = function(buf, byteorder)
    local offset = buf.offset or 1
    if not buf[offset] or not buf[offset + 3] then
        debugPrint("Nil offset found in readU32 at position " .. offset)
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
        debugPrint("Nil value found in readS32")
        return nil
    end
    if value >= 2147483648 then value = value - 4294967296 end
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

mspHelper.writeRAW = function(buf, value)
    buf[#buf + 1] = value
end

return mspHelper
