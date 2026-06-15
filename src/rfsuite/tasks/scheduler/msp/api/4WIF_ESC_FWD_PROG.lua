--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = rfsuite.tasks.msp.getApiCore()

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
