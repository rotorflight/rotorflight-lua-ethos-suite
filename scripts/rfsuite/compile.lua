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

]]--

compile = {}

local arg = {...}
local config = arg[1]


local readConfig
local switchParam
local pref
local spref
local s

function compile.initialise()

end


local function dir_exists(base,name)
        if base == nil then base = "./" end
        list = system.listFiles(base)       
        for i,v in pairs(list) do
                if v == name then
                        return true
                end
        end
        return false
end

local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

local function baseName()
    local baseName
    baseName = config.suiteDir:gsub("/scripts/", "")
    baseName = baseName:gsub("/", "")
    return baseName
end

-- explode a string
local function explode(inputstr, sep)
    if sep == nil then sep = "%s" end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do table.insert(t, str) end
    return t
end

function compile.loadScript(script)


     if os.mkdir ~= nil and dir_exists("./" , "compiled") == false then
                        os.mkdir("./" .. "compiled")
     end

    -- we need to add code to stop this reading every time function runs
    local cachefile    
    cachefile = "compiled/" .. script:gsub("/", "_") .. "c"

    -- overrides
    if config.useCompiler == true then
        if file_exists("/scripts/" .. baseName() .. ".nocompile") == true then config.useCompiler = false end

        if file_exists("/scripts/nocompile") == true then config.useCompiler = false end
    end

    -- do not compile if for some reason the compiler cache folder is missing
    if dir_exists(suiteDir , "compiled") ~= true then
        config.useCompiler = false
    end

    if config.useCompiler == true then
        if file_exists(cachefile) ~= true then
            system.compile(script)

            os.rename(script .. 'c', cachefile)

            -- if not compiled - we compile; but return non compiled to sort timing issue.
            --print("Loading: " .. cachefile)
            return assert(loadfile(cachefile))
        end
        -- print("Loading: " .. cachefile)
        return assert(loadfile(cachefile))
    else
        if file_exists(cachefile) == true then os.remove(cachefile) end
        -- print("Loading: " .. script)              
        return assert(loadfile(script))
    end

end

return compile
