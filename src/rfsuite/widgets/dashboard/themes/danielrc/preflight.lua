--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd

local common = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/danielrc/common.lua"))()

local boxes_cache = nil
local lastScreenW = nil
local lastScreenH = nil
local headerCache = {}

local function header_boxes()
    return common.headerBoxes(headerCache)
end

local function boxes()
    local W, H = lcd.getWindowSize()
    if boxes_cache == nil or lastScreenW ~= W or lastScreenH ~= H then
        boxes_cache = common.buildCockpitBoxes()
        lastScreenW = W
        lastScreenH = H
    end
    return boxes_cache
end

return {
    layout = common.layout,
    boxes = boxes,
    header_boxes = header_boxes,
    header_layout = common.headerLayout,
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.6}
}
