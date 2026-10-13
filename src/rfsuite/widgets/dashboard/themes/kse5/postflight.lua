--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local lcd = lcd

local common = requireModule("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/themes/kse5/common.lua")

local boxes_cache = nil
local lastScreenW = nil
local lastPrefs = nil

local function boxes()
    local W = lcd.getWindowSize()
    local prefs = common.prefsVersion()
    if boxes_cache == nil or lastScreenW ~= W or lastPrefs ~= prefs then
        boxes_cache = common.buildBoxes(W, "postflight")
        lastScreenW = W
        lastPrefs = prefs
    end
    return boxes_cache
end

return {
    layout = common.layout,
    boxes = boxes,
    header_boxes = common.headerBoxes,
    header_layout = common.headerLayout,
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.5}
}
