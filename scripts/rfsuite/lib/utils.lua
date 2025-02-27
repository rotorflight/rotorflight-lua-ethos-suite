--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local utils = {}

local arg = {...}
local config = arg[1]

function utils.sanitize_filename(str)
    if not str then return nil end
    return str:match("^%s*(.-)%s*$"):gsub('[\\/:"*?<>|]', '')
end

function utils.dir_exists(base, name)
    local list = system.listFiles(base)
    for i = 1, #list do
        if list[i] == name then
            return true
        end
    end
    return false
end

function utils.file_exists(name)
    local f = io.open(name, "r")
    if f then
        io.close(f)
        return true
    end
    return false
end

function utils.playFile(pkg, file)
    -- Get and clean audio voice path
    local av = system.getAudioVoice():gsub("SD:", ""):gsub("RADIO:", ""):gsub("AUDIO:", ""):gsub("VOICE[1-4]:", "")

    -- Pre-define the base directory paths
    local soundPack = rfsuite.preferences.soundPack
    local audioPath = soundPack and ("/audio/" .. soundPack) or av

    -- Construct file paths
    local wavLocale = audioPath .. "/" .. pkg .. "/" .. file
    local wavDefault = "audio/en/default/" .. pkg .. "/" .. file

    -- Check if locale file exists, else use the default
    system.playFile(rfsuite.utils.file_exists(wavLocale) and wavLocale or wavDefault)
end

function utils.playFileCommon(file)
    system.playFile("audio/" .. file)
end


-- this is used in multiple places - just gives easy way
-- to grab activeProfile or activeRateProfile in tmp var
-- you MUST set it to nil after you get it!
function utils.getCurrentProfile()

    if (rfsuite.tasks.telemetry.getSensorSource("pidProfile") ~= nil and rfsuite.tasks.telemetry.getSensorSource("rateProfile") ~= nil) then

        rfsuite.session.activeProfileLast = rfsuite.session.activeProfile
        local p = rfsuite.tasks.telemetry.getSensorSource("pidProfile"):value()
        if p ~= nil then
            rfsuite.session.activeProfile = math.floor(p)
        else
            rfsuite.session.activeProfile = nil
        end

        rfsuite.session.activeRateProfileLast = rfsuite.session.activeRateProfile
        local r = rfsuite.tasks.telemetry.getSensorSource("rateProfile"):value()
        if r ~= nil then
            rfsuite.session.activeRateProfile = math.floor(r)
        else
            rfsuite.session.activeRateProfile = nil
        end

    else
        -- msp call to get data
        
        if system.getVersion().simulation ~= true then
            
            if rfsuite.config.ethosRunningVersion ~= nil then

                local message = {
                    command = 101, -- MSP_SERVO_CONFIGURATIONS
                    uuid = "getProfile",
                    processReply = function(self, buf)

                        if #buf >= 30 then

                            buf.offset = 24
                            local activeProfile = rfsuite.tasks.msp.mspHelper.readU8(buf)
                            buf.offset = 26
                            local activeRate = rfsuite.tasks.msp.mspHelper.readU8(buf)

                            rfsuite.session.activeProfileLast = rfsuite.session.activeProfile
                            rfsuite.session.activeRateProfileLast = rfsuite.session.activeRateProfile

                            rfsuite.session.activeProfile = activeProfile + 1
                            rfsuite.session.activeRateProfile = activeRate + 1

                        end
                    end,
                    simulatorResponse = {240, 1, 124, 0, 35, 0, 0, 0, 0, 0, 0, 224, 1, 10, 1, 0, 26, 0, 0, 0, 0, 0, 2, 0, 6, 0, 6, 1, 4, 1}

                }
                rfsuite.tasks.msp.mspQueue:add(message)


            end
        else
            if rfsuite.preferences.simProfileSwiching == true then
                local seconds = tonumber(os.date("%S"))  -- Get the current second (0-59)
        
                local ap
                if seconds % 20 < 10 then
                    ap = 1
                else
                    ap = 2
                end       
                

                rfsuite.session.activeProfileLast = rfsuite.session.activeProfile
                local p = ap
                if p ~= nil then
                    rfsuite.session.activeProfile = math.floor(p)
                else
                    rfsuite.session.activeProfile = nil
                end

                rfsuite.session.activeRateProfileLast = rfsuite.session.activeRateProfile
                local r = ap
                if r ~= nil then
                    rfsuite.session.activeRateProfile = math.floor(r)
                else
                    rfsuite.session.activeRateProfile = nil
                end           

            end
        end    
    end
end

-- Function to compare the current system version with a target version
-- Function to compare the current system version with a target version
function utils.ethosVersionAtLeast(targetVersion)
    local env = system.getVersion()
    local currentVersion = {env.major, env.minor, env.revision}

    -- Fallback to default config if targetVersion is not provided
    if targetVersion == nil then 
        if rfsuite and rfsuite.config and rfsuite.config.ethosVersion then
            targetVersion = rfsuite.config.ethosVersion
        else
            -- Fail-safe: if no targetVersion is provided and config is missing
            return false
        end
    elseif type(targetVersion) == "number" then
        rfsuite.utils.log("WARNING: utils.ethosVersionAtLeast() called with a number instead of a table (" .. targetVersion .. ")",2)
        return false    
    end

    -- Ensure the targetVersion has three components (major, minor, revision)
    for i = 1, 3 do
        targetVersion[i] = targetVersion[i] or 0  -- Default to 0 if not provided
    end

    -- Compare major, minor, and revision explicitly
    for i = 1, 3 do
        if currentVersion[i] > targetVersion[i] then
            return true  -- Current version is higher
        elseif currentVersion[i] < targetVersion[i] then
            return false -- Current version is lower
        end
    end

    return true  -- Versions are equal (>= condition met)
end

function utils.titleCase(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

function utils.stringInArray(array, s)
    for i, value in ipairs(array) do if value == s then return true end end
    return false
end

function utils.round(number, precision)
    if precision == nil then precision = 0 end
    local fmtStr = string.format("%%0.%sf", precision)
    number = string.format(fmtStr, number)
    number = tonumber(number)
    return number
end

function utils.roughlyEqual(a, b, tolerance)
    return math.abs(a - b) < (tolerance or 0.0001)  -- Allows a tiny margin of error
end

-- return current window size
function utils.getWindowSize()
    return lcd.getWindowSize()
end

function utils.joinTableItems(tbl, delimiter)
    if not tbl or #tbl == 0 then return "" end

    delimiter = delimiter or ""
    local startIndex = tbl[0] and 0 or 1
    
    -- Ensure each field is padded to at least 3 characters
    local function padField(field)
        field = tostring(field)
        return field .. string.rep(" ", math.max(0, 3 - #field))
    end

    local result = padField(tbl[startIndex])

    for i = startIndex + 1, #tbl do
        result = result .. delimiter .. padField(tbl[i])
    end

    return result
end


function utils.log(msg, level)
    rfsuite.log.log(msg, level or "debug")
end

-- print a table out to debug console
function utils.print_r(node)
    if node == nil then
        print("nil (type: nil)")
        return
    elseif type(node) ~= "table" then
        print(tostring(node) .. " (type: " .. type(node) .. ")")
        return
    end

    local cache, stack, output = {}, {}, {}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k, v in pairs(node) do size = size + 1 end

        local cur_index = 1
        for k, v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then
                if (string.find(output_str, "}", output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str, "\n", output_str:len())) then
                    output_str = output_str .. "\n"
                end

                table.insert(output, output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "[" .. tostring(k) .. "]"
                else
                    key = "['" .. tostring(k) .. "']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep("\t", depth) .. key .. " = " .. tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep("\t", depth) .. key .. " = {\n"
                    table.insert(stack, node)
                    table.insert(stack, v)
                    cache[node] = cur_index + 1
                    break
                else
                    output_str = output_str .. string.rep("\t", depth) .. key .. " = '" .. tostring(v) .. "'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep("\t", depth - 1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                if (cur_index == size) then output_str = output_str .. "\n" .. string.rep("\t", depth - 1) .. "}" end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then output_str = output_str .. "\n" .. string.rep("\t", depth - 1) .. "}" end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end

    table.insert(output, output_str)
    output_str = table.concat(output, "\n")

    -- Print in chunks of 5 lines
    local lines = {}
    for line in output_str:gmatch("[^\n]+") do table.insert(lines, line) end

    for i = 1, #lines, 5 do
        local chunk = table.concat(lines, "\n", i, math.min(i + 4, #lines))
        print(chunk)
    end
end


function utils.findModules()
    local modulesList = {}

    local moduledir = "app/modules/"
    local modules_path = moduledir

    for _, v in pairs(system.listFiles(modules_path)) do

        if v ~= ".." then
            local init_path = modules_path .. v .. '/init.lua'

            local f = io.open(init_path, "r")
            if f then
                io.close(f)
                local func, err = loadfile(init_path)
                if err then
                    rfsuite.utils.log("Error loading " .. init_path, "info")
                    rfsuite.utils.log(err, "info")
                end
                if func then
                    local mconfig = func()
                    if type(mconfig) ~= "table" or not mconfig.script then
                        rfsuite.utils.log("Invalid configuration in " .. init_path,"info")
                    else
                        rfsuite.utils.log("Loading module " .. v, "debug")
                        mconfig['folder'] = v
                        table.insert(modulesList, mconfig)
                    end
                else
                    rfsuite.utils.log("Error loading " .. init_path, "info")    
                end 
            end
        end    
    end

    return modulesList
end

function utils.findWidgets()
    local widgetsList = {}

    local widgetdir = "widgets/"
    local widgets_path = widgetdir

    for _, v in pairs(system.listFiles(widgets_path)) do

        if v ~= ".." then
            local init_path = widgets_path .. v .. '/init.lua'
            local f = io.open(init_path, "r")
            if f then
                io.close(f)

                local func, err = loadfile(init_path)

                if func then
                    local wconfig = func()
                    if type(wconfig) ~= "table" or not wconfig.key then
                        rfsuite.utils.log("Invalid configuration in " .. init_path,"debug")
                    else
                        wconfig['folder'] = v
                        table.insert(widgetsList, wconfig)
                    end
                end
            end
        end    
    end

    return widgetsList
end

-- Helper function to load an image from up to three possible paths
function utils.loadImage(image1, image2, image3)
    -- Helper function to check file in different locations
    local function find_image_in_directories(img)
        if rfsuite.utils.file_exists(img) then
            return img
        elseif rfsuite.utils.file_exists("BITMAPS:" .. img) then
            return "BITMAPS:" .. img
        elseif rfsuite.utils.file_exists("SYSTEM:" .. img) then
            return "SYSTEM:" .. img
        else
            return nil
        end
    end

    -- Function to check and return a valid image path
    local function resolve_image(image)
        if type(image) == "string" then
            local image_path = find_image_in_directories(image)
            if not image_path then
                if image:match("%.png$") then
                    image_path = find_image_in_directories(image:gsub("%.png$", ".bmp"))
                elseif image:match("%.bmp$") then
                    image_path = find_image_in_directories(image:gsub("%.bmp$", ".png"))
                end
            end
            return image_path
        end
        return nil
    end

    -- Resolve images in order of precedence
    local image_path = resolve_image(image1) or resolve_image(image2) or resolve_image(image3)

    -- If an image path is found, load and return the bitmap
    if image_path then return lcd.loadBitmap(image_path) end

    -- If no valid image path was found, return the first existing Bitmap in order
    if type(image1) == "Bitmap" then return image1 end
    if type(image2) == "Bitmap" then return image2 end
    if type(image3) == "Bitmap" then return image3 end

    -- If nothing was found, return nil
    return nil
end


return utils
