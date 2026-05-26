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

local API_NAME = "SERVO_CONFIGURATIONS"

local SERVO_FIELDS = {
    {"mid", "U16"},
    {"min", "S16"},
    {"max", "S16"},
    {"rneg", "U16"},
    {"rpos", "U16"},
    {"rate", "U16"},
    {"speed", "U16"},
    {"flags", "U16"}
}

local function buildServoStructure(servoCount)
    local spec = {{"servo_count", "U8"}}
    for i = 1, servoCount do
        for _, tuple in ipairs(SERVO_FIELDS) do
            spec[#spec + 1] = {"servo_" .. i .. "_" .. tuple[1], tuple[2]}
        end
    end
    return select(1, core.buildStructure(spec))
end

local SIM_RESPONSE = core.simResponse({
    4,        -- servo_count

    180, 5,   -- servo_1_mid
    12, 254,  -- servo_1_min
    244, 1,   -- servo_1_max
    244, 1,   -- servo_1_rneg
    244, 1,   -- servo_1_rpos
    144, 0,   -- servo_1_rate
    0, 0,     -- servo_1_speed
    1, 0,     -- servo_1_flags

    160, 5,   -- servo_2_mid
    12, 254,  -- servo_2_min
    244, 1,   -- servo_2_max
    244, 1,   -- servo_2_rneg
    244, 1,   -- servo_2_rpos
    144, 0,   -- servo_2_rate
    0, 0,     -- servo_2_speed
    1, 0,     -- servo_2_flags

    14, 6,    -- servo_3_mid
    12, 254,  -- servo_3_min
    244, 1,   -- servo_3_max
    244, 1,   -- servo_3_rneg
    244, 1,   -- servo_3_rpos
    144, 0,   -- servo_3_rate
    0, 0,     -- servo_3_speed
    0, 0,     -- servo_3_flags

    120, 5,   -- servo_4_mid
    212, 254, -- servo_4_min
    44, 1,    -- servo_4_max
    244, 1,   -- servo_4_rneg
    244, 1,   -- servo_4_rpos
    77, 1,    -- servo_4_rate
    0, 0,     -- servo_4_speed
    0, 0      -- servo_4_flags
})

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    buf.offset = 1
    local servoCount = helper.readU8(buf)
    if servoCount == nil then
        return nil, "parse_failed"
    end

    local parsed = {
        servo_count = servoCount,
        servos = {}
    }

    for i = 1, servoCount do
        local servo = {}
        parsed.servos[i - 1] = servo

        for _, tuple in ipairs(SERVO_FIELDS) do
            local fieldName = tuple[1]
            local reader = helper["read" .. tuple[2]]
            local value = reader and reader(buf) or nil
            if value == nil then
                return nil, "parse_failed"
            end
            parsed["servo_" .. i .. "_" .. fieldName] = value
            servo[fieldName] = value
        end
    end

    return {
        parsed = parsed,
        structure = buildServoStructure(servoCount),
        buffer = buf,
        receivedBytesCount = #buf
    }
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 120,
    minBytes = 1,
    fields = {},
    simulatorResponseRead = SIM_RESPONSE,
    parseRead = parseRead,
    exports = {
        simulatorResponse = SIM_RESPONSE
    }
})
