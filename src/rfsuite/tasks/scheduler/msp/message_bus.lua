--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local type = type
local pairs = pairs
local pcall = pcall

local bus = {}
local actions = {}
local contexts = {}
local contextOwners = {}
local nextContextId = 0

local function wipe(tbl)
    for k in pairs(tbl) do
        tbl[k] = nil
    end
end

function bus.registerAction(name, fn)
    if type(name) ~= "string" or name == "" or type(fn) ~= "function" then return false end
    actions[name] = fn
    return true
end

function bus.createContext(data, owner)
    if type(data) ~= "table" then return nil end

    nextContextId = nextContextId + 1
    contexts[nextContextId] = data
    contextOwners[nextContextId] = owner
    return nextContextId
end

function bus.getContext(id)
    if id == nil then return nil end
    return contexts[id]
end

function bus.releaseContext(id)
    if id == nil then return false end
    if contexts[id] == nil then return false end

    contexts[id] = nil
    contextOwners[id] = nil
    return true
end

function bus.releaseOwner(owner)
    if owner == nil then return 0 end

    local removed = 0
    for id, registeredOwner in pairs(contextOwners) do
        if registeredOwner == owner then
            contexts[id] = nil
            contextOwners[id] = nil
            removed = removed + 1
        end
    end

    return removed
end

function bus.dispatchAction(name, contextId, ...)
    local fn = actions[name]
    if fn == nil then return false, "missing_action" end

    local context = contexts[contextId]
    if context == nil then return false, "missing_context" end

    return pcall(fn, context, ...)
end

function bus.reset()
    wipe(contexts)
    wipe(contextOwners)
    nextContextId = 0
end

function bus.contextCount()
    local n = 0
    for _ in pairs(contexts) do
        n = n + 1
    end
    return n
end

function bus.actionCount()
    local n = 0
    for _ in pairs(actions) do
        n = n + 1
    end
    return n
end

function bus.ownerCount(owner)
    local handlerCount = 0
    local contextCount = 0

    if owner == nil then
        return handlerCount, contextCount
    end

    for _, registeredOwner in pairs(contextOwners) do
        if registeredOwner == owner then
            contextCount = contextCount + 1
        end
    end

    return handlerCount, contextCount
end

function bus.stats()
    return {
        handlers = 0,
        contexts = bus.contextCount(),
        actions = bus.actionCount()
    }
end

bus.registerAction("legacy.reply", function(context, msg, buf)
    local fn = context and context.reply
    if type(fn) ~= "function" then return false, "missing_reply" end
    return fn(msg, buf)
end)

bus.registerAction("legacy.error", function(context, msg, reason)
    local fn = context and context.error
    if type(fn) ~= "function" then return false, "missing_error" end
    return fn(msg, reason)
end)

return bus
