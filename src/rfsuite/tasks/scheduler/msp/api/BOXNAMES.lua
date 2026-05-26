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

local API_NAME = "BOXNAMES"
local SEMICOLON = 59
local NUL = 0

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    local parsed = {}
    local names = {}
    local chars = {}

    local function flushName()
        if #chars == 0 then return end
        names[#names + 1] = table.concat(chars)
        chars = {}
    end

    buf.offset = 1
    while true do
        local b = helper.readU8(buf)
        if b == nil then break end
        if b == SEMICOLON or b == NUL then
            flushName()
        elseif b >= 32 and b <= 126 then
            chars[#chars + 1] = string.char(b)
        end
    end

    flushName()
    parsed.box_names = names
    return {parsed = parsed, buffer = buf, receivedBytesCount = #buf}
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = 116,
    minBytes = 0,
    fields = {},
    simulatorResponseRead = {},
    parseRead = parseRead
})
