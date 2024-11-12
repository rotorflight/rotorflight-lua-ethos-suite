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

local utils = {}

local arg = {...}
local config = arg[1]
local compile = arg[2]



function utils.dir_exists(base,name)
        list = system.listFiles(base)       
        for i,v in pairs(list) do
                if v == name then
                        return true
                end
        end
        return false
end

function utils.file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

function utils.playFile(pkg, file)
    -- Get and clean audio voice path
    local av = system.getAudioVoice()
    av = av:gsub("SD:", ""):gsub("RADIO:", ""):gsub("AUDIO:", ""):gsub("VOICE[1-4]:", "")

    -- Pre-define the base directory paths
    local baseDir = rfsuite.config.suiteDir
    local soundPack = rfsuite.config.soundPack
    local audioPath = soundPack and ("/audio/" .. soundPack) or (av)

    -- Construct file paths
    local wavLocale = baseDir .. audioPath .. "/" .. pkg .. "/" .. file
    local wavDefault = baseDir .. "/audio/en/default/" .. pkg .. "/" .. file

    -- Check if locale file exists, else use the default
    if rfsuite.utils.file_exists(wavLocale) then
        system.playFile(wavLocale)
    else
        system.playFile(wavDefault)
    end
end

function utils.playFileCommon(file)

        local wav = rfsuite.config.suiteDir .. "/audio/" .. file

        system.playFile(wav)
      
end

function utils.isHeliArmed()

    local govmode

    local governorMap = {}
    governorMap[0] = "OFF"
    governorMap[1] = "IDLE"
    governorMap[2] = "SPOOLUP"
    governorMap[3] = "RECOVERY"
    governorMap[4] = "ACTIVE"
    governorMap[5] = "THR-OFF"
    governorMap[6] = "LOST-HS"
    governorMap[7] = "AUTOROT"
    governorMap[8] = "BAILOUT"
    governorMap[100] = "DISABLED"
    governorMap[101] = "DISARMED"

    govSOURCE = rfsuite.bg.telemetry.getSensorSource("governor")

    if rfsuite.bg.telemetry.getSensorProtocol() == 'lcrsf' then
        if govSOURCE ~= nil then govmode = govSOURCE:stringValue() end
    else
        if govSOURCE ~= nil then
            govId = govSOURCE:value()
            if governorMap[govId] == nil then
                govmode = "UNKNOWN"
            else
                govmode = governorMap[govId]
            end
        else
            govmode = ""
        end
    end

    if govmode ~= "DISARMED" then
        return true
    else
        return false
    end

end

-- this is used in multiple places - just gives easy way
-- to grab activeProfile or activeRateProfile in tmp var
-- you MUST set it to nil after you get it!
function utils.getCurrentProfile()

    if (rfsuite.bg.telemetry.getSensorSource("pidProfile") ~= nil and rfsuite.bg.telemetry.getSensorSource("rateProfile") ~= nil) then

        config.activeProfileLast = config.activeProfile
        local p = rfsuite.bg.telemetry.getSensorSource("pidProfile"):value()
        if p ~= nil then
                config.activeProfile = math.floor(p)
        else    
                config.activeProfile = nil
        end        

        config.activeRateProfileLast = config.activeRateProfile
        local r = rfsuite.bg.telemetry.getSensorSource("rateProfile"):value()
        if r ~= nil then
                config.activeRateProfile = math.floor(r)
        else
                config.activeRateProfile = nil
        end

    else
        -- msp call to get data

        if rfsuite.config.ethosRunningVersion ~= nil then

            local message = {
                command = 101, -- MSP_SERVO_CONFIGURATIONS
                processReply = function(self, buf)

                    if #buf >= 30 then

                        buf.offset = 24
                        local activeProfile = rfsuite.bg.msp.mspHelper.readU8(buf)
                        buf.offset = 26
                        local activeRate = rfsuite.bg.msp.mspHelper.readU8(buf)

                        config.activeProfileLast = config.activeProfile
                        config.activeRateProfileLast = config.activeRateProfile

                        config.activeProfile = activeProfile + 1
                        config.activeRateProfile = activeRate + 1

                    end
                end,
                simulatorResponse = {240, 1, 124, 0, 35, 0, 0, 0, 0, 0, 0, 224, 1, 10, 1, 0, 26, 0, 0, 0, 0, 0, 2, 0, 6, 0, 6, 1, 4, 1}

            }
            rfsuite.bg.msp.mspQueue:add(message)

        end

    end
end

function utils.ethosVersion()
    local environment = system.getVersion()
    v = tonumber(environment.major .. environment.minor .. environment.revision)
    if environment.revision == 0 then
        v = v * 10
    end
    return v
end

function utils.ethosVersionToMinor()
    local environment = system.getVersion()
    local v = tonumber(environment.major .. environment.minor)
    return v
end

function utils.getRssiSensor()
    local rssiSensor
    local rssiNames = {"RSSI", "RSSI 2.4G", "RSSI 900M", "Rx RSSI1", "Rx RSSI2", "RSSI Int", "RSSI Ext", "RSSI Lora"}
    for i, name in pairs(rssiNames) do
        rssiSensor = system.getSource(name)
        if rssiSensor then return {sensor = rssiSensor, name = name} end
    end
    return {sensor = nil, name = nil}
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

function utils.countCarriageReturns(text)
    local _, count = text:gsub("\r", "")
    return count
end

function utils.getSection(id, sections)
    for i, v in ipairs(sections) do if id ~= nil then if v.section == id then return v end end end
end

-- explode a string
function utils.explode(inputstr, sep)
    if sep == nil then sep = "%s" end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do table.insert(t, str) end
    return t
end

function utils.trim(s)
    s = tostring(s)
    return s:match("^%s*(.-)%s*$"):gsub("[\r\n]+$", "")
end

function utils.round(number, precision)
    if precision == nil then precision = 0 end
    local fmtStr = string.format("%%0.%sf", precision)
    number = string.format(fmtStr, number)
    number = tonumber(number)
    return number
end

-- clear the screen when using lcd functions
function utils.clearScreen()
    local w = LCD_W
    local h = LCD_H
    if isDARKMODE then
        lcd.color(lcd.RGB(40, 40, 40))
    else
        lcd.color(lcd.RGB(240, 240, 240))
    end
    lcd.drawFilledRectangle(0, 0, w, h)
end

-- prevent value going to high or too low
function utils.clipValue(val, min, max)
    if val < min then
        val = min
    elseif val > max then
        val = max
    end
    return val
end

-- return current window size
function utils.getWindowSize()
    return lcd.getWindowSize()
    -- return 784, 406
    -- return 472, 288
    -- return 472, 240
end

-- simple wrapper - long term will enable 
-- dynamic compilation
function utils.loadScript(script)
    -- system.compile(script)
    return loadfile(script)
end

-- return the time
function utils.getTime()
    return os.clock() * 100
end

function utils.joinTableItems(table, delimiter)
    if table == nil or #table == 0 then return "" end
    delimiter = delimiter or ""
    local result = table[1]
    for i = 2, #table do result = result .. delimiter .. table[i] end
    return result
end

-- GET FIELD VALUE FOR ETHOS FORMS.  FUNCTION TAKES THE VALUE AND APPLIES RULES BASED
-- ON THE PARAMETERS ON THE rfsuite.pages TABLE
function utils.getFieldValue(f)

    local v

    if f.value == nil then f.value = 0 end
    if f.t == nil then f.t = "N/A" end

    if f.value ~= nil then
        if f.decimals ~= nil then
            v = rfsuite.utils.round(f.value * rfsuite.utils.decimalInc(f.decimals))
        else
            v = f.value
        end
    else
        v = 0
    end

    if f.offset ~= nil then v = v + f.offset end
    if f.mult ~= nil then v = math.floor(v * f.mult + 0.5) end

    return v
end

-- SAVE FIELD VALUE FOR ETHOS FORMS.  FUNCTION TAKES THE VALUE AND APPLIES RULES BASED
-- ON THE PARAMETERS ON THE rfsuite.pages TABLE
function utils.saveFieldValue(f, value)
    if value ~= nil then
        if f.offset ~= nil then value = value - f.offset end
        if f.decimals ~= nil then
            f.value = value / rfsuite.utils.decimalInc(f.decimals)
        else
            f.value = value
        end
        if f.postEdit then f.postEdit(rfsuite.app.Page) end
    end

    if f.mult ~= nil then f.value = f.value / f.mult end

    return f.value
end

function utils.scaleValue(value, f)
    local v
    if value ~= nil then
        v = value * utils.decimalInc(f.decimals)
        if f.scale ~= nil then v = v / f.scale end
        v = utils.round(v)
        return v
    else
        return nil
    end
end

function utils.decimalInc(dec)
    local decTable = {10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000, 10000000000, 100000000000}

    if dec == nil then
        return 1
    else
        return decTable[dec]
    end
end

-- set positions of form elements
function utils.getInlinePositions(f, lPage)
    local tmp_inline_size = utils.getInlineSize(f.label, lPage)
    local inline_multiplier = rfsuite.app.radio.inlinesize_mult

    local inline_size = tmp_inline_size * inline_multiplier

    LCD_W, LCD_H = utils.getWindowSize()

    local w = LCD_W
    local h = LCD_H
    local colStart

    local padding = 5
    local fieldW = (w * inline_size) / 100

    local eX
    local eW = fieldW - padding
    local eH = rfsuite.app.radio.navbuttonHeight
    local eY = rfsuite.app.radio.linePaddingTop
    local posX
    lcd.font(FONT_STD)
    tsizeW, tsizeH = lcd.getTextSize(f.t)

    if f.inline == 5 then
        posX = w - fieldW * 9 - tsizeW - padding
        posText = {x = posX, y = eY, w = tsizeW, h = eH}

        posX = w - fieldW * 9
        posField = {x = posX, y = eY, w = eW, h = eH}
    elseif f.inline == 4 then
        posX = w - fieldW * 7 - tsizeW - padding
        posText = {x = posX, y = eY, w = tsizeW, h = eH}

        posX = w - fieldW * 7
        posField = {x = posX, y = eY, w = eW, h = eH}
    elseif f.inline == 3 then
        posX = w - fieldW * 5 - tsizeW - padding
        posText = {x = posX, y = eY, w = tsizeW, h = eH}

        posX = w - fieldW * 5
        posField = {x = posX, y = eY, w = eW, h = eH}
    elseif f.inline == 2 then
        posX = w - fieldW * 3 - tsizeW - padding
        posText = {x = posX, y = eY, w = tsizeW, h = eH}

        posX = w - fieldW * 3
        posField = {x = posX, y = eY, w = eW, h = eH}
    elseif f.inline == 1 then
        posX = w - fieldW - tsizeW - padding - padding
        posText = {x = posX, y = eY, w = tsizeW, h = eH}

        posX = w - fieldW - padding
        posField = {x = posX, y = eY, w = eW, h = eH}
    end

    ret = {posText = posText, posField = posField}

    return ret
end

-- find size of elements
function utils.getInlineSize(id, lPage)
    for i, v in ipairs(lPage.labels) do
        if id ~= nil then
            if v.label == id then
                local size
                if v.inline_size == nil then
                    size = 13.6
                else
                    size = v.inline_size
                end
                return size

            end
        end
    end
end

-- write text at given ordinates on screen
function utils.writeText(x, y, str)
    if lcd.darkMode() then
        lcd.color(lcd.RGB(255, 255, 255))
    else
        lcd.color(lcd.RGB(90, 90, 90))
    end
    lcd.drawText(x, y, str)
end

function utils.log(msg)

    if config.logEnable == true then

        if config.logEnableScreen == true then print(msg) end

        local f = io.open("logs/rfsuite.log", 'a')
        io.write(f, tostring(msg) .. "\n")
        io.close(f)

    end
end

-- print a table out to debug console
function utils.print_r(node)
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

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
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
                -- close the table
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

    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output, output_str)
    output_str = table.concat(output)

    print(output_str)
end

-- convert a string to a nunber
function utils.makeNumber(x)
    if x == nil or x == "" then x = 0 end

    x = string.gsub(x, "%D+", "")
    x = tonumber(x)
    if x == nil or x == "" then x = 0 end

    return x
end

-- used to take tables from format used in pages
-- and convert them to an ethos forms format
function utils.convertPageValueTable(tbl, inc)
    local thetable = {}

    if inc == nil then inc = 0 end

    if tbl[0] ~= nil then
        thetable[0] = {}
        thetable[0][1] = tbl[0]
        thetable[0][2] = 0
    end
    for idx, value in ipairs(tbl) do
        thetable[idx] = {}
        thetable[idx][1] = value
        thetable[idx][2] = idx + inc
    end

    return thetable
end

return utils
