--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicorev2) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/core.lua"))()
if msp and not msp.apicorev2 then
    msp.apicorev2 = core
end

local API_NAME = "4WIF_ESC_FWD_PROG"

-- Tuple layout:
--   field, type
local WRITE_FIELD_SPEC = {
    {"target", "U8"}
}

local function buildWritePayload(payloadData)
    local target = payloadData[WRITE_FIELD_SPEC[1][1]]
    if target == nil then
        target = 0
    end

    return {target}
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = 244,
    buildWritePayload = buildWritePayload,
    simulatorResponseWrite = {},
    writeUuidFallback = true,
    initialRebuildOnWrite = true
})
