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

local API_NAME = "ESC_WRITE_STATUS"
local MSP_API_CMD_READ = 0x300A

local FIELD_SPEC = {
    "op_id", "U16",
    "esc_id", "U8",
    "protocol", "U8",
    "signature", "U8",
    "state", "U8",
    "error", "U8"
}

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    minApiVersion = {12, 0, 10},
    fields = FIELD_SPEC
})
