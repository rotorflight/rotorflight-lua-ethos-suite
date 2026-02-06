--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local craftimage = {}

local default_image = "widgets/toolbox/gfx/default_image.png"
local bitmapPtr

function craftimage.wakeup()
    local session = rfsuite.session
    if session.toolbox.craftimage ~= nil then return end

    local craftName = session.craftName

    local image1, image2, image3, image4
    if craftName then
        image1 = "/bitmaps/models/" .. craftName .. ".png"
        image2 = "/bitmaps/models/" .. craftName .. ".bmp"
    end

    local default_image = "widgets/toolbox/gfx/default_image.png"

    local utils = rfsuite.utils
    bitmapPtr = utils.loadImage(image1, image2, image3, image4)

    if not bitmapPtr and model and model.bitmap then
        local ethosBitmap = model.bitmap()
        if ethosBitmap and type(ethosBitmap) == "string" and not string.find(ethosBitmap, "default_") then bitmapPtr = ethosBitmap end
    end

    if not bitmapPtr then bitmapPtr = utils.loadImage(default_image) end

    session.toolbox.craftimage = bitmapPtr
end

return craftimage
