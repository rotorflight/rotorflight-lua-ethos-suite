--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local function Ring(cap)
    return {
        d = {},
        h = 1,
        t = 1,
        n = 0,
        c = cap or 64,
        push = function(self, x)
            self.d[self.t] = x;
            self.t = (self.t % self.c) + 1
            if self.n < self.c then
                self.n = self.n + 1
            else
                self.h = (self.h % self.c) + 1
            end
        end,
        pop = function(self)
            if self.n == 0 then return nil end
            local x = self.d[self.h];
            self.d[self.h] = nil;
            self.h = (self.h % self.c) + 1;
            self.n = self.n - 1;
            return x
        end,
        empty = function(self) return self.n == 0 end,
        items = function(self)
            local out = {}
            if self.n == 0 then return out end
            local idx = self.h
            for i = 1, self.n do
                out[#out + 1] = self.d[idx]
                idx = (idx % self.c) + 1
            end
            return out
        end,        
    }
end

local logs = {config = {enabled = true, log_to_file = true, print_interval = system:getVersion().simulation and 0.025 or 0.5, disk_write_interval = 5.0, max_line_length = 200, min_print_level = "info", log_file = "log.txt", prefix = ""}}

local LEVEL = {debug = 0, info = 1, off = 2}
local MINLVL = LEVEL[logs.config.min_print_level] or 1

local qConsole = Ring(50)
local qDisk = Ring(100)
local qConnect = Ring(20)
-- Separate rolling buffer for on-screen "connect" display.
-- qConnect is drained by process_connect(), so it may be empty when the UI renders.
local qConnectView = Ring(80)
local lastPrint, lastDisk, lastConnect = os.clock(), os.clock(), os.clock()

local function split(msg, maxlen, cont)
    if #msg <= maxlen then return {msg} end
    local t, i = {}, 1
    while i <= #msg do
        local j = i + maxlen - 1
        t[#t + 1] = msg:sub(i, j)
        i = j + 1
        if i <= #msg then
            msg = cont .. msg:sub(i);
            i = 1
        end
        if #msg <= maxlen then
            t[#t + 1] = msg;
            break
        end
    end
    return t
end

function logs.log(message, level)
    if not logs.config.enabled or MINLVL == LEVEL.off then return end

    if rfsuite.preferences.developer.loglevel == "off" then 
        return 
    end

    local lvl = LEVEL[level or "info"]
    if not lvl or lvl < MINLVL then return end

    local maxlen = logs.config.max_line_length * 10
    if #message > maxlen then
        message = message:sub(1, maxlen) .. " [truncated]"
    end

    local e = { msg = message, lvl = lvl }

    -- RULE 1: info 
    if rfsuite.preferences.developer.loglevel == "info" then
        if lvl == LEVEL.info then
            qConsole:push(e)
        end
    end

    -- RULE 2: debug 
    if rfsuite.preferences.developer.loglevel == "debug" then
        if lvl == LEVEL.debug or lvl == LEVEL.info then
            qDisk:push(e)
        end
    end    

end

function logs.add(message, level)
    if level == "connect" then
        local rawp = logs.config.prefix
        local pfx = type(rawp) == "function" and rawp() or (rawp or "")

        local e = { msg = message, lvl = LEVEL.info, pfx = pfx }
        qConnect:push(e)
        if qConnectView then qConnectView:push(e) end
    else
        logs.log(message, level)
    end
end  


local function drain_console(now)
    if now - lastPrint < logs.config.print_interval or qConsole:empty() then return end
    lastPrint = now
    local rawp = logs.config.prefix
    local pfx = type(rawp) == "function" and rawp() or (rawp or "")
    local pad = #pfx > 0 and string.rep(" ", #pfx) or ""
    for _ = 1, 5 do
        local e = qConsole:pop();
        if not e then break end
        for _, line in ipairs(split(pfx .. e.msg, logs.config.max_line_length, pad)) do print(line) end
    end
end

local function drain_disk(now)
    if now - lastDisk < logs.config.disk_write_interval or qDisk:empty() then return end
    lastDisk = now
    local f = io.open(logs.config.log_file, "a");
    if not f then return end
    local rawp = logs.config.prefix
    local pfx = type(rawp) == "function" and rawp() or (rawp or "")
    for _ = 1, 20 do
        local e = qDisk:pop();
        if not e then break end
        f:write(pfx .. e.msg .. "\n")
    end
    f:close()
end

local function drain_connect(now)
    if now - lastConnect < logs.config.print_interval or qConnect:empty() then return end
    lastConnect = now
    local rawp = logs.config.prefix
    local pfx = type(rawp) == "function" and rawp() or (rawp or "")
    local pad = #pfx > 0 and string.rep(" ", #pfx) or ""
    for _ = 1, 5 do
        local e = qConnect:pop()
        if not e then break end
        for _, line in ipairs(split(pfx .. e.msg, logs.config.max_line_length, pad)) do print(line) end
    end
end

function logs.process()
    if not logs.config.enabled or MINLVL == LEVEL.off then return end
    local now = os.clock()
    drain_console(now)
    drain_disk(now)
end

local function stripLeadingTimestamp(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("^%b[]%s*", ""))
end

function logs.getConnectLines(maxLines, opts)
    opts = opts or {}
    maxLines = tonumber(maxLines) or 8
    if maxLines < 1 then return {} end

    local entries = qConnectView:items()
    local lines = {}

    for i = #entries, 1, -1 do
        local e = entries[i]
        if e and e.msg then
            -- use stored prefix if present, otherwise fall back
            local pfx = e.pfx
            if pfx == nil then
                local rawp = logs.config.prefix
                pfx = type(rawp) == "function" and rawp() or (rawp or "")
            end

            if opts.noTimestamp then
                pfx = stripLeadingTimestamp(pfx)
            end

            local pad = #pfx > 0 and string.rep(" ", #pfx) or ""

            local msg = pfx .. e.msg
            local parts = split(msg, logs.config.max_line_length, pad)

            for j = #parts, 1, -1 do
                lines[#lines + 1] = parts[j]
                if #lines >= maxLines then break end
            end
            if #lines >= maxLines then break end
        end
    end

    local out = {}
    for i = #lines, 1, -1 do out[#out + 1] = lines[i] end
    return out
end


function logs.process_connect()
    if not logs.config.enabled or MINLVL == LEVEL.off then return end
    local now = os.clock()
    drain_connect(now)
end

return logs
