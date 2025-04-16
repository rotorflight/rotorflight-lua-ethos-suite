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
]] --
local rf2bbl = {}

local LCD_W, LCD_H = lcd.getWindowSize()
local wakeupSchedulerUI = os.clock()

local isErase = false
local init = true

local progress = nil
local progressCounter = 0
local eraseDataflashGo = false

local summary = {}
local lastSummaryTime = 0

local config = {}

-- Helper to display a centered message using the largest possible font
local function drawCenteredMessage(msg)
    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

    local maxW, maxH = w * 0.9, h * 0.9
    local bestFont, bestW, bestH = FONT_XXS, 0, 0

    for _, font in ipairs(fonts) do
        lcd.font(font)
        local tW, tH = lcd.getTextSize(msg)
        if tW <= maxW and tH <= maxH then
            bestFont, bestW, bestH = font, tW, tH
        else
            break
        end
    end

    lcd.font(bestFont)
    lcd.color(isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90))
    lcd.drawText((w - bestW) / 2, (h - bestH) / 2, msg)
end

-- Show critical version error
local function screenError(msg)
    drawCenteredMessage(msg)
end

-- Request summary from dataflash
local function getDataflashSummary()
    local message = {
        command = 70,
        processReply = function(_, buf)
            local helper = rfsuite.tasks.msp.mspHelper
            local flags = helper.readU8(buf)
            summary.ready = (flags & 1) ~= 0
            summary.supported = (flags & 2) ~= 0
            summary.sectors = helper.readU32(buf)
            summary.totalSize = helper.readU32(buf)
            summary.usedSize = helper.readU32(buf)
        end,
        simulatorResponse = {3, 1, 0, 0, 0, 0, 4, 0, 0, 0, 3, 0, 0}
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end


-- Ask user for confirmation before erasing dataflash
local function eraseDataflashAsk()

    local buttons = {{
        label = rfsuite.i18n.get("app.btn_ok"),
        action = function()

            -- we push this to the background task to do its job
            eraseDataflashGo = true
            return true
        end
    }, {
        label = rfsuite.i18n.get("app.btn_cancel"),
        action = function()
            return true
        end
    }}

    form.openDialog({
        width = nil,
        title =  rfsuite.i18n.get("widgets.bbl.erase_dataflash"),
        message = rfsuite.i18n.get("widgets.bbl.erase_dataflash") .. "?",
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

end    

-- Trigger erase command
local function eraseDataflash()
    isErase = true
    progress = form.openProgressDialog(rfsuite.i18n.get("app.msg_saving"), rfsuite.i18n.get("app.msg_saving_to_fbl"))
    progress:value(0)
    progress:closeAllowed(false)
    progressCounter = 0

    local message = {
        command = 72,
        processReply = function()
            summary = {}
            isErase = false
            getDataflashSummary()
        end
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Periodically refresh telemetry info
local function wakeupUI()
    if not rfsuite or not rfsuite.tasks.active() then
        summary = {}
        return
    end

    LCD_W, LCD_H = lcd.getWindowSize()
    if rfsuite.tasks.telemetry.getSensorSource("armflags") then
        local armValue = rfsuite.tasks.telemetry.getSensorSource("armflags"):value()
        local now = os.clock()

        if armValue == 0 or armValue == 2 or (now - lastSummaryTime >= 30) then
            getDataflashSummary()
            lastSummaryTime = now
        end
    end    
end

local function getFreeDataflashSpace()
    if not summary.supported then
        return rfsuite.i18n.get("app.modules.status.unsupported")
    end
    local freeSpace = summary.totalSize - summary.usedSize

    local msg

    if config.display == 0 then
        msg = string.format("%.1f/%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"),
        summary.usedSize / (1024 * 1024),
        summary.totalSize / (1024 * 1024))
    elseif config.display == 1 then
        msg = string.format("%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"), freeSpace / (1024 * 1024))
    elseif config.display == 2 then 
        msg = string.format("%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"), summary.usedSize / (1024 * 1024))
    else    
        msg = "Unknown"
    end

    return msg
end

function rf2bbl.create(widget)
    -- Stub: Initialize if needed
end

function rf2bbl.paint(widget)
    local msg

    if not rfsuite.utils.ethosVersionAtLeast() then
        msg = string.format(rfsuite.i18n.get('ethos') .. " < V%d.%d.%d",
            rfsuite.config.ethosVersion[1],
            rfsuite.config.ethosVersion[2],
            rfsuite.config.ethosVersion[3]
        )
        screenError(msg)
        return
    end

    if isErase then
        msg = rfsuite.i18n.get("widgets.bbl.erasing")
    elseif summary.totalSize and summary.usedSize then
        msg = getFreeDataflashSpace()
    else
        if rfsuite.tasks.telemetry.active() then
            msg = rfsuite.i18n.get('app.msg_loading')
        else
            msg = rfsuite.i18n.get("no_link"):upper()
        end    
    end

    drawCenteredMessage(msg)
end

function rf2bbl.configure(widget)
    local spaceTable = {{rfsuite.i18n.get("widgets.bbl.display_outof"), 0}, {rfsuite.i18n.get("widgets.bbl.display_free"), 1},{rfsuite.i18n.get("widgets.bbl.display_used"), 2} }

    line = form.addLine(rfsuite.i18n.get("widgets.bbl.display"))
    form.addChoiceField(line, nil, spaceTable, function()
        return config.display
    end, function(newValue)
        config.display = newValue
    end)
end

function rf2bbl.menu(widget)
    return {
        {rfsuite.i18n.get("widgets.bbl.erase_dataflash"), eraseDataflashAsk}
    }
end

function rf2bbl.read(widget)
    config.display = storage.read("mem1")
    if config.display == nil then config.display = 0 end
end

-- Write function
function rf2bbl.write(widget)
    storage.write("mem1", config.display)
end

function rf2bbl.wakeup(widget)

    -- update the display every 2 seconds
    local schedulerUI = 2
    local now = os.clock()
    if lcd.isVisible() and ((now - wakeupSchedulerUI) >= schedulerUI or init) then
        wakeupSchedulerUI = now
        wakeupUI()
        lcd.invalidate()
        init = false
    end

    -- run the erase process if requested
    if eraseDataflashGo then
        eraseDataflashGo = false
        eraseDataflash()
    end

    -- draw progress bar if needed
    if progress then
        progressCounter = progressCounter + 10
        progress:value(progressCounter)
        if progressCounter >= 100 then
            progress:close()
            progress = nil
        end
    end
end

return rf2bbl