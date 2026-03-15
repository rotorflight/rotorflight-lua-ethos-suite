--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local craftimage = {}

local default_image = "widgets/toolbox/gfx/default_image.png"
local bitmapPtr

local function addCandidate(candidates, path)
    if type(path) ~= "string" or path == "" then return end
    for i = 1, #candidates do
        if candidates[i] == path then return end
    end
    candidates[#candidates + 1] = path
end

local function tryLoadImagePath(path)
    local utils = rfsuite.utils
    if type(path) ~= "string" or path == "" then return nil end

    local tryPaths
    if path:match("%.png$") or path:match("%.bmp$") then
        tryPaths = {path}
    else
        tryPaths = {path .. ".png", path .. ".bmp", path}
    end

    for i = 1, #tryPaths do
        local candidate = tryPaths[i]
        if not utils.isImageTooLarge(candidate, rfsuite.config.maxModelImageBytes) then
            local loaded = utils.loadImage(candidate)
            if loaded then return loaded end
        end
    end

    return nil
end

local function getBitmapCandidates(bitmap)
    local candidates = {}
    addCandidate(candidates, bitmap)

    if type(bitmap) ~= "string" or bitmap == "" then return candidates end

    if bitmap:match("^/bitmaps/") then
        addCandidate(candidates, (bitmap:gsub("^/bitmaps", "BITMAPS:", 1)))
    elseif bitmap:match("^/scripts/") then
        addCandidate(candidates, (bitmap:gsub("^/scripts", "SCRIPTS:", 1)))
    elseif bitmap:match("^/system/") then
        addCandidate(candidates, (bitmap:gsub("^/system", "SYSTEM:", 1)))
    elseif not bitmap:match("^[A-Z]+:") and not bitmap:match("^/") then
        addCandidate(candidates, "BITMAPS:/models/" .. bitmap)
    end

    return candidates
end

function craftimage.wakeup()
    local session = rfsuite.session
    if session.toolbox.craftimage ~= nil then return end

    local craftName = session.craftName

    local imageBase
    if craftName then
        imageBase = "BITMAPS:/models/" .. craftName
    end

    local default_image = "widgets/toolbox/gfx/default_image.png"

    bitmapPtr = tryLoadImagePath(imageBase)

    if not bitmapPtr and model and model.bitmap then
        local ethosBitmap = model.bitmap()
        if ethosBitmap and type(ethosBitmap) == "string" and not string.find(ethosBitmap, "default_") then
            local candidates = getBitmapCandidates(ethosBitmap)
            for i = 1, #candidates do
                bitmapPtr = tryLoadImagePath(candidates[i])
                if bitmapPtr then break end
            end
        end
    end

    if not bitmapPtr then bitmapPtr = rfsuite.utils.loadImage(default_image) end

    session.toolbox.craftimage = bitmapPtr
end

return craftimage
