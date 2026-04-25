--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local escmspv2 = {}

local function noop() end

local function detachHandlers(api)
    if not api then return end
    if api.setCompleteHandler then pcall(api.setCompleteHandler, noop) end
    if api.setErrorHandler then pcall(api.setErrorHandler, noop) end
end

function escmspv2.new()
    local state = {
        requested = false,
        pending = false,
        nameApi = nil,
        nameApiName = nil,
        detailsApi = nil,
        detailsApiName = nil
    }

    local function isAvailable()
        return rfsuite.utils and rfsuite.utils.apiVersionCompare and rfsuite.utils.apiVersionCompare(">=", {12, 0, 10})
    end

    local function loadApi(slot, slotName, apiName)
        if state[slot] and state[slotName] == apiName then
            return state[slot]
        end

        state[slot] = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.load and
            rfsuite.tasks.msp.api.load(apiName) or nil
        state[slotName] = state[slot] and apiName or nil
        return state[slot]
    end

    local function reset()
        detachHandlers(state.nameApi)
        detachHandlers(state.detailsApi)
        state.requested = false
        state.pending = false
        state.nameApi = nil
        state.nameApiName = nil
        state.detailsApi = nil
        state.detailsApiName = nil
    end

    local function fetch(onComplete, onError, escId)
        if not isAvailable() then
            return false, "unsupported"
        end

        if state.pending or state.requested then
            return false, state.pending and "busy" or "done"
        end

        local nameApi = loadApi("nameApi", "nameApiName", "ESC_NAME")
        local detailsApi = loadApi("detailsApi", "detailsApiName", "ESC_DETAILS")
        if not nameApi or not detailsApi then
            return false, "api_unavailable"
        end

        local function fail(reason, retryable)
            state.pending = false
            if retryable ~= true then
                state.requested = true
            end
            if type(onError) == "function" then
                onError(reason)
            end
        end

        local function complete()
            state.pending = false
            state.requested = true

            if type(onComplete) == "function" then
                onComplete({
                    esc_id = detailsApi.readValue("esc_id") or nameApi.readValue("esc_id"),
                    name_flags = nameApi.readValue("flags"),
                    detail_flags = detailsApi.readValue("flags"),
                    name = nameApi.readValue("name"),
                    model = nameApi.readValue("model"),
                    version = detailsApi.readValue("version"),
                    firmware = detailsApi.readValue("firmware")
                })
            end
        end

        detailsApi.setCompleteHandler(function()
            complete()
        end)
        detailsApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_details_error")
        end)
        nameApi.setCompleteHandler(function()
            local ok, reason = detailsApi.read(escId)
            if not ok then
                fail(reason or "esc_details_queue_failed", reason == "queued_busy")
            end
        end)
        nameApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_name_error")
        end)

        state.pending = true
        local ok, reason = nameApi.read(escId)
        if not ok then
            state.pending = false
            return false, reason
        end

        return true
    end

    return {
        isAvailable = isAvailable,
        pending = function()
            return state.pending
        end,
        requested = function()
            return state.requested
        end,
        fetch = fetch,
        reset = reset
    }
end

return escmspv2
