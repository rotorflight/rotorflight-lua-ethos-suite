--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- Thin, replaceable message bus. The interface is intentionally minimal so
-- it maps cleanly to whatever Ethos ships natively; swapping means rewriting
-- only this file.
--
-- bus.on(topic, handler, context)   -> id   persistent subscription
-- bus.once(topic, handler, context) -> id   auto-unsubscribes after first delivery
-- bus.off(id)                               unsubscribe by id
-- bus.offContext(context)                   cancel every subscription tagged with context
-- bus.emit(topic, data)                     deliver data to all topic subscribers (sync)

local bus = {}

local _subs    = {}   -- [id] -> {topic, handler, once, context}
local _byTopic = {}   -- [topic] -> {[id]=true}
local _byCtx   = {}   -- [context] -> {[id]=true}
local _seq     = 0

local function _nextId()
    _seq = _seq + 1
    return _seq
end

local function _erase(id)
    local s = _subs[id]
    if not s then return end
    local ts = _byTopic[s.topic]
    if ts then
        ts[id] = nil
        if next(ts) == nil then _byTopic[s.topic] = nil end
    end
    if s.context then
        local cs = _byCtx[s.context]
        if cs then
            cs[id] = nil
            if next(cs) == nil then _byCtx[s.context] = nil end
        end
    end
    _subs[id] = nil
end

local function _add(topic, handler, once, context)
    local id = _nextId()
    _subs[id] = {topic = topic, handler = handler, once = once, context = context}
    local ts = _byTopic[topic]
    if not ts then ts = {}; _byTopic[topic] = ts end
    ts[id] = true
    if context then
        local cs = _byCtx[context]
        if not cs then cs = {}; _byCtx[context] = cs end
        cs[id] = true
    end
    return id
end

function bus.on(topic, handler, context)
    return _add(topic, handler, false, context)
end

function bus.once(topic, handler, context)
    return _add(topic, handler, true, context)
end

function bus.off(id)
    _erase(id)
end

function bus.offContext(context)
    local cs = _byCtx[context]
    if not cs then return end
    local ids = {}
    for id in pairs(cs) do ids[#ids + 1] = id end
    _byCtx[context] = nil
    for _, id in ipairs(ids) do
        local s = _subs[id]
        if s then
            local ts = _byTopic[s.topic]
            if ts then
                ts[id] = nil
                if next(ts) == nil then _byTopic[s.topic] = nil end
            end
            _subs[id] = nil
        end
    end
end

function bus.emit(topic, data)
    local ts = _byTopic[topic]
    if not ts then return end
    local ids = {}
    for id in pairs(ts) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        local s = _subs[id]
        if s then
            if s.once then _erase(id) end
            pcall(s.handler, data)
        end
    end
end

return bus
