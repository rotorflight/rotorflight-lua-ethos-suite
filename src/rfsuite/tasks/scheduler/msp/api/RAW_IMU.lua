--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local osClock = os.clock
local sin = math.sin
local floor = math.floor

local function writeS16(v, bytes)
    if v < 0 then v = v + 0x10000 end
    bytes[#bytes + 1] = v % 256
    bytes[#bytes + 1] = floor(v / 256) % 256
end

local function simulatorResponse()
    local t = osClock() * 3.5
    local bytes = {}

    writeS16(floor(sin(t) * 180), bytes)
    writeS16(floor(sin(t + 1.3) * 160), bytes)
    writeS16(floor(512 + sin(t + 0.4) * 70), bytes)
    writeS16(floor(sin(t * 1.2) * 220), bytes)
    writeS16(floor(sin(t * 1.1 + 1.1) * 200), bytes)
    writeS16(floor(sin(t * 0.9 + 2.0) * 170), bytes)
    writeS16(floor(sin(t * 0.8) * 120), bytes)
    writeS16(floor(sin(t * 0.7 + 0.7) * 140), bytes)
    writeS16(floor(sin(t * 0.6 + 1.8) * 90), bytes)

    return bytes
end

return core.createReadOnlyAPI({
    name = "RAW_IMU",
    readCmd = 102,
    fields = {
        "accel_1", "S16",
        "accel_2", "S16",
        "accel_3", "S16",
        "gyro_1", "S16",
        "gyro_2", "S16",
        "gyro_3", "S16",
        "mag_1", "S16",
        "mag_2", "S16",
        "mag_3", "S16"
    },
    simulatorResponseRead = simulatorResponse
})
