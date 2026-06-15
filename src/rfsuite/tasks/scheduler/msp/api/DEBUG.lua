--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local osClock = os.clock
local sin = math.sin
local floor = math.floor

local function writeS32(v, bytes)
    if v < 0 then v = v + 0x100000000 end
    bytes[#bytes + 1] = v % 256
    bytes[#bytes + 1] = floor(v / 256) % 256
    bytes[#bytes + 1] = floor(v / 65536) % 256
    bytes[#bytes + 1] = floor(v / 16777216) % 256
end

local function simulatorResponse()
    local t = osClock() * 2.0
    local bytes = {}

    for i = 1, 8 do
        writeS32(floor(sin(t + i * 0.6) * 1000), bytes)
    end

    return bytes
end

return core.createReadOnlyAPI({
    name = "DEBUG",
    readCmd = 254,
    fields = {
        "debug_1", "S32",
        "debug_2", "S32",
        "debug_3", "S32",
        "debug_4", "S32",
        "debug_5", "S32",
        "debug_6", "S32",
        "debug_7", "S32",
        "debug_8", "S32"
    },
    simulatorResponseRead = simulatorResponse
})
