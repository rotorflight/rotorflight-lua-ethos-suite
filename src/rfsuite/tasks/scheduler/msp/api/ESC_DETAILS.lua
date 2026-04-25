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

local API_NAME = "ESC_DETAILS"
local MSP_API_CMD_READ = 0x300F
local MIN_READ_BYTES = 4

local function buildReadPayload(_, _, _, _, escId)
    if type(escId) ~= "number" then
        return nil
    end

    escId = math.floor(escId)
    if escId < 0 then escId = 0 end
    if escId > 255 then escId = 255 end

    return {escId}
end

local function readText(buf, helper, length)
    local text = {}
    for _ = 1, length do
        local value = helper.readU8(buf)
        if value == nil then break end
        text[#text + 1] = string.char(value)
    end
    return table.concat(text)
end

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    buf.offset = 1

    local escId = helper.readU8(buf)
    local flags = helper.readU8(buf)
    local versionLength = helper.readU8(buf) or 0
    local version = readText(buf, helper, versionLength)
    local firmwareLength = helper.readU8(buf) or 0
    local firmware = readText(buf, helper, firmwareLength)

    return {
        parsed = {
            esc_id = escId,
            flags = flags,
            version = version,
            firmware = firmware
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    minApiVersion = {12, 0, 10},
    minBytes = MIN_READ_BYTES,
    parseRead = parseRead,
    buildReadPayload = buildReadPayload
})
