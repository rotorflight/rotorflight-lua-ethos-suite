--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "SET_ADJUSTMENT_RANGE"

return factory.create({
    name = API_NAME,
    writeCmd = 53,
    customWrite = function(suppliedPayload, state, emitComplete, emitError)
        local payload = suppliedPayload or state.payloadData.payload
        if type(payload) ~= "table" then return false, "missing_payload" end

        state.mspWriteComplete = false

        local uuid = state.uuid
        if not uuid then
            local utils = rfsuite and rfsuite.utils
            uuid = (utils and utils.uuid and utils.uuid()) or tostring(os.clock())
        end

        local message = {
            command = 53,
            apiname = API_NAME,
            payload = payload,
            processReply = function(self, buf)
                state.mspWriteComplete = true
                emitComplete(self, buf)
            end,
            errorHandler = function(self, err)
                emitError(self, err)
            end,
            simulatorResponse = {},
            uuid = uuid,
            timeout = state.timeout
        }

        return rfsuite.tasks.msp.mspQueue:add(message)
    end
})
