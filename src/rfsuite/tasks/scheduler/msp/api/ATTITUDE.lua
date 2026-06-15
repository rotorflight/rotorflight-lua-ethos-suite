--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

local API_NAME = "ATTITUDE"

local sin = math.sin
local floor = math.floor
local max = math.max

local FIELD_SPEC = {
    "roll", "S16",
    "pitch", "S16",
    "yaw", "S16"
}

local function buildSimulatorResponse(state, op, now, simStartAt)
    local helper = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspHelper
    if not helper then return {} end

    local t0 = simStartAt or 0
    local t = max(0, (now or os.clock()) - t0)
    local rollDeg = 25.0 * sin(t * 1.25)
    local pitchDeg = 18.0 * sin((t * 0.90) + 0.9)
    local yawDeg = 90.0 * sin((t * 0.42) + 0.2)

    local buf = {}
    helper.writeS16(buf, floor((rollDeg * 10.0) + 0.5))
    helper.writeS16(buf, floor((pitchDeg * 10.0) + 0.5))
    helper.writeS16(buf, floor(yawDeg + 0.5))
    return buf
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 108,
    fields = FIELD_SPEC,
    simulatorResponseRead = core.simResponse(buildSimulatorResponse),
    exports = {}
})
