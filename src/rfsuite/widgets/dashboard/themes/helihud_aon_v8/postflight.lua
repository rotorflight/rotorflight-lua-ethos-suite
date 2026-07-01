--[[ HeliHUD AON V8 postflight.lua ]] --
local rfsuite = require("rfsuite")
local lcd = lcd

local common = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/helihud_aon_v8/common.lua"))()

local boxes_cache = nil
local lastScreenW = nil
local lastScreenH = nil
local lastThemeSignature = nil
local headerCache = {}

local function header_boxes()
    return common.headerBoxes(headerCache)
end

local function boxes()
    local W, H = lcd.getWindowSize()
    local themeSignature = common.getThemeSignature()
    if boxes_cache == nil or lastScreenW ~= W or lastScreenH ~= H or lastThemeSignature ~= themeSignature then
        boxes_cache = common.buildReportBoxes()
        lastScreenW = W
        lastScreenH = H
        lastThemeSignature = themeSignature
    end
    return boxes_cache
end

return {
    layout = common.layout,
    boxes = boxes,
    header_boxes = header_boxes,
    header_layout = common.headerLayout,
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.65}
}
