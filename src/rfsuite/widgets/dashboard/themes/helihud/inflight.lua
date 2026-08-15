--[[ HeliHUD inflight.lua ]] --
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local common = requireModule("widgets/dashboard/themes/helihud/common.lua")

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
        boxes_cache = common.buildInflightBoxes()
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
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.80}
}
