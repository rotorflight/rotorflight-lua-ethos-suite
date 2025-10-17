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
    if rfsuite.session.toolbox.craftimage ~= nil then return end

    local craftName = rfsuite.session.craftName

    local image1, image2, image3, image4
    if craftName then
        image1 = "/bitmaps/models/" .. craftName .. ".png"
        image2 = "/bitmaps/models/" .. craftName .. ".bmp"
    end

    local default_image = "widgets/toolbox/gfx/default_image.png"

    bitmapPtr = rfsuite.utils.loadImage(image1, image2, image3, image4)

    if not bitmapPtr and model and model.bitmap then
        local ethosBitmap = model.bitmap()
        if ethosBitmap and type(ethosBitmap) == "string" and not string.find(ethosBitmap, "default_") then bitmapPtr = ethosBitmap end
    end

    if not bitmapPtr then bitmapPtr = rfsuite.utils.loadImage(default_image) end

    rfsuite.session.toolbox.craftimage = bitmapPtr
end

return craftimage
