--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

-- Localise globals (cuts down on global env lookups)
local os_clock = os.clock
local io_open = io.open
local type = type
local tonumber = tonumber
local ipairs = ipairs
local print = print
local table_concat = table.concat

local string_rep = string.rep
local string_sub = string.sub
local string_gsub = string.gsub

local function Ring(cap)
    return {
        d = {},
        h = 1,
        t = 1,
        n = 0,
        c = cap or 64,
        push = function(self, x)
            self.d[self.t] = x
            self.t = (self.t % self.c) + 1
            if self.n < self.c then
                self.n = self.n + 1
            else
                self.h = (self.h % self.c) + 1
            end
        end,
        pop = function(self)
            if self.n == 0 then return nil end
            local x = self.d[self.h]
            self.d[self.h] = nil
            self.h = (self.h % self.c) + 1
            self.n = self.n - 1
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

local logs = {
    config = {
        enabled = true,
        log_to_file = true,
        print_interval = system:getVersion().simulation and 0.025 or 0.5,
        disk_write_interval = 5.0,
        max_line_length = 200,
        min_print_level = "info",
        log_file = "log.txt",
        prefix = "",
        -- New knobs (safe defaults):
        disk_keep_open = true,       -- keep handle open between flushes (reduces open/close spikes)
        disk_buffer_max = 4096,      -- flush if buffered bytes exceed this
        disk_flush_batch = 50,       -- max lines per flush
        disk_drain_budget_seconds = 0.003, -- time budget for draining qDisk when log_to_file is false
    }
}

local LEVEL = { debug = 0, info = 1, error = 2, off = 3 }

-- We keep this as a function so changing config.min_print_level at runtime works.
local function getMinLevel(cfg)
    return LEVEL[cfg.min_print_level] or LEVEL.info
end

local qConsole = Ring(50)
local qDisk = Ring(200) -- a little bigger so we can batch more effectively
local qConnect = Ring(20)

-- Separate rolling buffer for on-screen "connect" display.
local qConnectView = Ring(80)

local lastPrint, lastDisk, lastConnect = os_clock(), os_clock(), os_clock()

-- Disk buffering / handle caching
local diskBuf = {}       -- array of lines (strings, WITHOUT \n)
local diskBufBytes = 0
local diskFH = nil
local diskFHPath = nil

local function diskClose()
    if diskFH then
        pcall(function() diskFH:close() end)
        diskFH = nil
        diskFHPath = nil
    end
end

local function diskEnsureOpen(cfg)
    if not cfg.log_to_file then return nil end
    local path = cfg.log_file
    if not path or path == "" then return nil end

    if diskFH and diskFHPath == path then
        return diskFH
    end

    diskClose()
    local f = io_open(path, "a")
    if not f then return nil end
    diskFH = f
    diskFHPath = path
    return f
end

local function diskBufPush(line)
    diskBuf[#diskBuf + 1] = line
    diskBufBytes = diskBufBytes + #line + 1 -- + "\n"
end

local function split(msg, maxlen, cont)
    if #msg <= maxlen then return { msg } end
    local t, i = {}, 1
    while i <= #msg do
        local j = i + maxlen - 1
        t[#t + 1] = string_sub(msg, i, j)
        i = j + 1
        if i <= #msg then
            msg = cont .. string_sub(msg, i)
            i = 1
        end
        if #msg <= maxlen then
            t[#t + 1] = msg
            break
        end
    end
    return t
end

local function getPrefix(cfg)
    local rawp = cfg.prefix
    if type(rawp) == "function" then
        return rawp() or ""
    end
    return rawp or ""
end

function logs.log(message, level)
    local cfg = logs.config
    if not cfg.enabled then return end

    local minlvl = getMinLevel(cfg)
    if minlvl == LEVEL.off then return end

    local devLevelStr = cfg.min_print_level or "info"
    if devLevelStr == "off" then return end

    local lvl = LEVEL[level or "info"]
    if not lvl or lvl < minlvl then return end

    -- Hard cap (prevents pathological memory churn)
    local maxlen = cfg.max_line_length * 10
    if #message > maxlen then
        message = string_sub(message, 1, maxlen) .. " [truncated]"
    end
    
    -- Capture prefix (timestamp) at creation time for accuracy
    local pfx = getPrefix(cfg)
    local e = { msg = message, lvl = lvl, pfx = pfx }

    -- ROUTING RULES
    -- info  : show info/error on console
    -- debug : show info on console, log debug/error to disk
    if devLevelStr == "info" then
        if lvl >= LEVEL.info and lvl < LEVEL.off then
            qConsole:push(e)
        end
        return
    end

    if devLevelStr == "debug" then
        if lvl == LEVEL.info then
            qConsole:push(e)
            qDisk:push(e)
        elseif lvl == LEVEL.debug or lvl == LEVEL.error then
            qDisk:push(e)
        end
    end
end

function logs.add(message, level)
    if level == "connect" then
        local cfg = logs.config
        local pfx = getPrefix(cfg)
        local e = { msg = message, lvl = LEVEL.info, pfx = pfx }
        qConnect:push(e)
        qConnectView:push(e)
    elseif level == "console" then
        local cfg = logs.config
        local pfx = getPrefix(cfg)
        local e = { msg = message, lvl = LEVEL.info, pfx = pfx }
        qConsole:push(e)
    else
        logs.log(message, level)
    end
end

local function drain_console(now, cfg)
    if (now - lastPrint) < cfg.print_interval or qConsole:empty() then return end
    lastPrint = now

    for _ = 1, 5 do
        local e = qConsole:pop()
        if not e then break end
        
        local p = e.pfx or ""
        local pad = (#p > 0) and string_rep(" ", #p) or ""
        local parts = split(p .. e.msg, cfg.max_line_length, pad)
        for i = 1, #parts do
            print(parts[i])
        end
    end
end

local function flush_disk(cfg)
    if #diskBuf == 0 then return end

    local f = diskEnsureOpen(cfg)
    if not f then
        -- If we can't open, drop buffered lines to avoid runaway memory growth.
        diskBuf = {}
        diskBufBytes = 0
        return
    end

    -- Write buffered lines in one go (less overhead than per-line write)
    -- Ethos Lua usually supports table.concat efficiently.
    local ok = pcall(function()
        f:write(table_concat(diskBuf, "\n"))
        f:write("\n")
        if f.flush then f:flush() end
    end)

    diskBuf = {}
    diskBufBytes = 0

    if not ok then
        diskClose()
    end

    if not cfg.disk_keep_open then
        diskClose()
    end
end

local function drain_disk(now, cfg)
    if not cfg.log_to_file then
        -- Still drain queue to prevent growth, but do not touch disk.
        local budget = cfg.disk_drain_budget_seconds or 0
        local deadline = (budget > 0) and (os_clock() + budget) or nil
        while not qDisk:empty() do
            qDisk:pop()
            if deadline and os_clock() >= deadline then break end
        end
        diskBuf = {}
        diskBufBytes = 0
        diskClose()
        return
    end

    if qDisk:empty() and #diskBuf == 0 then return end

    -- Time-based flush gate
    local doTimeFlush = (now - lastDisk) >= cfg.disk_write_interval

    -- Pull a batch from qDisk into buffer (cheap, no disk I/O yet)
    local batchMax = cfg.disk_flush_batch or 50
    for _ = 1, batchMax do
        local e = qDisk:pop()
        if not e then break end
        diskBufPush((e.pfx or "") .. e.msg)
        if diskBufBytes >= (cfg.disk_buffer_max or 4096) then
            doTimeFlush = true
            break
        end
    end

    if doTimeFlush then
        lastDisk = now
        flush_disk(cfg)
    end
end

local function drain_connect(now, cfg)
    if (now - lastConnect) < cfg.print_interval or qConnect:empty() then return end
    lastConnect = now

    local pfx = getPrefix(cfg)
    local pad = (#pfx > 0) and string_rep(" ", #pfx) or ""

    for _ = 1, 5 do
        local e = qConnect:pop()
        if not e then break end
        local parts = split(pfx .. e.msg, cfg.max_line_length, pad)
        for i = 1, #parts do
            print(parts[i])
        end
    end
end

function logs.process()
    local cfg = logs.config
    if not cfg.enabled then return end
    if getMinLevel(cfg) == LEVEL.off then return end

    local now = os_clock()
    drain_console(now, cfg)
    drain_disk(now, cfg)
end

local function stripLeadingTimestamp(s)
    if type(s) ~= "string" then return s end
    return (string_gsub(s, "^%b[]%s*", ""))
end

function logs.getConnectLines(maxLines, opts)
    opts = opts or {}
    maxLines = tonumber(maxLines) or 8
    if maxLines < 1 then return {} end

    local cfg = logs.config
    local entries = qConnectView:items()
    local lines = {}

    for i = #entries, 1, -1 do
        local e = entries[i]
        if e and e.msg then
            local pfx = e.pfx
            if pfx == nil then
                pfx = getPrefix(cfg)
            end

            if opts.noTimestamp then
                pfx = stripLeadingTimestamp(pfx)
            end

            local pad = (#pfx > 0) and string_rep(" ", #pfx) or ""
            local parts = split(pfx .. e.msg, cfg.max_line_length, pad)

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
    local cfg = logs.config
    if not cfg.enabled then return end
    if getMinLevel(cfg) == LEVEL.off then return end

    local now = os_clock()
    drain_connect(now, cfg)
end

-- allow callers to force a flush/close on teardown
function logs.flush()
    flush_disk(logs.config)
end

-- allow callers to force a reset on teardown
function logs.reset()
    flush_disk(logs.config)
end

function logs.close()
    flush_disk(logs.config)
    diskClose()
end

return logs
