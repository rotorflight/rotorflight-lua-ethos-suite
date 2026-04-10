--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local msp = rfsuite.tasks and rfsuite.tasks.msp
local factory = (msp and msp.apifactory) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/_factory.lua"))()
if msp and not msp.apifactory then msp.apifactory = factory end

local API_NAME = "BOXNAMES"
local SEMICOLON = 59
local NUL = 0

local function parseRead(buf)
    local helper = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspHelper
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
    return {parsed = parsed, buffer = buf}
end

return factory.create({
    name = API_NAME,
    readCmd = 116,
    minBytes = 0,
    simulatorResponseRead = {},
    parseRead = parseRead,
    readCompleteFn = function(state)
        return state.mspData ~= nil
    end
})
