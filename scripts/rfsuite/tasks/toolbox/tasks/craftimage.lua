--[[ 
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local arg = { ... }
local config = arg[1]

local craftimage = {}

local default_image = "widgets/toolbox/gfx/default_image.png"
local bitmapPtr

function craftimage.wakeup()
    if rfsuite.session.toolbox.craftimage ~= nil then
        -- prevent multiple image loads
        return
    end

    local craftName = rfsuite.session.craftName
    --local modelID = rfsuite.session.modelID

    local image1, image2, image3, image4
    if craftName then
        image1 = "/bitmaps/models/" .. craftName .. ".png"
        image2 = "/bitmaps/models/" .. craftName .. ".bmp"
    end
    --if modelID then
    --    image3 = "/bitmaps/models/" .. modelID .. ".png"
    --    image4 = "/bitmaps/models/" .. modelID .. ".bmp"
    --end

    local default_image = "widgets/toolbox/gfx/default_image.png"

    -- Try png then bmp for craftName, then png then bmp for modelID, no fallback in loadImage
    bitmapPtr = rfsuite.utils.loadImage(image1, image2, image3, image4)

    -- ETHOS model image fallback if everything above failed and it's not the ETHOS default
    if not bitmapPtr and model and model.bitmap then
        local ethosBitmap = model.bitmap()
        if ethosBitmap and type(ethosBitmap) == "string" and not string.find(ethosBitmap, "default_") then
            bitmapPtr = ethosBitmap
        end
    end

    -- Last fallback: default image
    if not bitmapPtr then
        bitmapPtr = rfsuite.utils.loadImage(default_image)
    end

    rfsuite.session.toolbox.craftimage = bitmapPtr
end

return craftimage
