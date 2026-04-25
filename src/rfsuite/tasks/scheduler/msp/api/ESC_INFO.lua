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

local API_NAME = "ESC_INFO"
local MSP_API_CMD_READ = 0x3008

local function buildReadPayload(_, _, _, _, escId)
    if type(escId) ~= "number" then
        return nil
    end

    escId = math.floor(escId)
    if escId < 0 then escId = 0 end
    if escId > 255 then escId = 255 end

    return {escId}
end

local FIELD_SPEC = {
    "esc_id", "U8",
    "protocol", "U8",
    "signature", "U8",
    "flags", "U8",
    "capabilities", "U8",
    "parameter_bytes", "U8",
    "max_chunk_size", "U8"
}

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    minApiVersion = {12, 0, 10},
    fields = FIELD_SPEC,
    buildReadPayload = buildReadPayload
})
