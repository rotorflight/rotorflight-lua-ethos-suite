--[[
  Lightweight protocol logger (disabled by default)

  Notes:
  - Uses the shared logger (tasks/logger/log.lua) when available, so we inherit the
    same disk buffering + file path handling as the rest of RFSuite.
  - Falls back to a direct io.open() logger if the shared logger isn't available.
]]--

local rfsuite = require("rfsuite")

local M = {}

-- Public knobs
M.enabled = false

-- Default file (Ethos-style path). Can be overridden by setting M.logFile before enable(true).
M.logFile = "LOGS:/msp_proto.log"

-- Optional: include payload hex dump lines (can be noisy)
M.dumpPayload = true

-- Internal
local _logs = nil         -- shared logger (preferred)
local _fh = nil           -- fallback file handle
local _lastFlushAt = 0    -- fallback flush throttle
local _flushEvery = 0.25  -- seconds (fallback)

-- Localise globals
local os_clock = os.clock
local string_format = string.format
local tostring = tostring
local type = type
local io_open = io.open
local pcall = pcall
local string_byte = string.byte
local table_concat = table.concat

local hex_lookup = {}
for i = 0, 255 do
    hex_lookup[i] = string_format("%02X", i)
end

local function now()
    return string_format("%.3f", os_clock())
end

local function tryRequire(name)
    local ok, mod = pcall(require, name)
    if ok and mod then return mod end
    return nil
end

local function resolveSharedLogger()
    -- Prefer the canonical module if present in your tree.
    -- (These are deliberately tried in a safe order.)
    return
        tryRequire("rfsuite.tasks.logger.log") or
        tryRequire("rfsuite.tasks.logger") or
        tryRequire("tasks.logger.log") or
        tryRequire("tasks.logger")
end

local function hexFromTable(t)
    local out = {}
    for i = 1, #t do
        local b = t[i] or 0
        out[#out + 1] = hex_lookup[b & 0xFF] or "00"
    end
    return table_concat(out, " ")
end

local function hexFromString(s)
    local out = {}
    for i = 1, #s do
        out[#out + 1] = hex_lookup[string_byte(s, i)]
    end
    return table_concat(out, " ")
end

local function payloadLen(payload)
    if not payload then return 0 end
    local tp = type(payload)
    if tp == "table" then return #payload end
    if tp == "string" then return #payload end
    return 0
end

local function writeLine(line)
    if not M.enabled then return end

    -- Shared logger path: buffered, low I/O
    if _logs and _logs.log then
        _logs.log(line, "debug")
        return
    end

    -- Fallback direct-to-disk path
    if not _fh then return end
    _fh:write(line, "\n")

    local t = os_clock()
    if (t - _lastFlushAt) >= _flushEvery then
        _lastFlushAt = t
        pcall(function() _fh:flush() end)
    end
end

function M.enable(on)
    if on and not M.enabled then
        -- Prefer shared logger (inherits same disk buffering + config semantics)
        _logs = resolveSharedLogger()
        if _logs and _logs.config then
            -- Make sure disk logging is enabled, but don't spam console.
            _logs.config.enabled = true
            _logs.config.log_to_file = true
            _logs.config.log_file = M.logFile
            -- Keep the global logger's own print intervals; we just log at debug.
        else
            _logs = nil
        end

        -- If shared logger isn't available, open our own file.
        if not _logs then
            _fh = io_open(M.logFile, "a")
            if _fh then
                pcall(function() _fh:write("\n") end)
            end
        end

        M.enabled = (_logs ~= nil) or (_fh ~= nil)
        if M.enabled then
            writeLine("--- MSP PROTOCOL LOG START " .. now() .. " ---")
        end

    elseif (not on) and M.enabled then
        writeLine("--- MSP PROTOCOL LOG STOP " .. now() .. " ---")

        if _logs and _logs.flush then
            -- Ensure it hits disk on teardown, but don't touch global close() here.
            pcall(function() _logs.flush() end)
        end

        if _fh then
            pcall(function() _fh:flush() end)
            pcall(function() _fh:close() end)
        end

        _logs = nil
        _fh = nil
        M.enabled = false
    end
end

-- dir: "TX"/"RX" (or any label)
-- proto: e.g. "MSP", "MSP2", "SPORT", "CRSF"
-- cmd: command id
-- payload: table of bytes OR string
-- extra: optional string (e.g. error text, flags, timing)
function M.log(dir, proto, cmd, payload, extra)
    if not M.enabled then return end

    local len = payloadLen(payload)
    local hdr = now()
        .. " " .. tostring(dir or "?")
        .. " " .. tostring(proto or "?")
        .. " CMD=" .. tostring(cmd)
        .. " LEN=" .. tostring(len)

    if extra and extra ~= "" then
        hdr = hdr .. " " .. tostring(extra)
    end

    writeLine(hdr)

    if M.dumpPayload and payload and len > 0 then
        local tp = type(payload)
        if tp == "table" then
            writeLine(hexFromTable(payload))
        elseif tp == "string" then
            writeLine(hexFromString(payload))
        end
    end
end

return M
