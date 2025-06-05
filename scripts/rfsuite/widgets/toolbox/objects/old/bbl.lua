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
local function drawCenteredMessage(msg, valueOffset)
    local w, h = lcd.getWindowSize()

    local isDarkMode = lcd.darkMode()
    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

    local maxW, maxH = w * 0.9, h * 0.9
    local bestFont, bestW, bestH = FONT_XXS, 0, 0

    for _, font in ipairs(fonts) do
        lcd.font(font)
        if msg == nil then msg = "-" end
        local tW, tH = lcd.getTextSize(msg)
        if tW <= maxW and tH <= maxH then
            bestFont, bestW, bestH = font, tW, tH
        else
            break
        end
    end

    lcd.font(bestFont)
    lcd.color(isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90))
    lcd.drawText((w - bestW) / 2, ((h - bestH ) / 2) + 5 + valueOffset, msg)
end

-- Request summary from dataflash
local function getDataflashSummary()

    summary.totalSize = rfsuite.session.bblSize
    summary.usedSize = rfsuite.session.bblUsed
    local flags = rfsuite.session.bblFlags or 0
    summary.ready = (flags & 1) ~= 0
    summary.supported = (flags & 2) ~= 0

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

    if rfsuite.session.apiVersion == nil then
        summary = {}
        return
    end

    if not rfsuite.tasks.msp.mspQueue:isProcessed() then
        return
    end

    LCD_W, LCD_H = lcd.getWindowSize()
    if rfsuite.tasks.telemetry.getSensorSource("armflags") then
        local armValue = rfsuite.tasks.telemetry.getSensorSource("armflags"):value()
        if armValue ~= nil then
            armValue = math.floor(armValue)
        end
        local now = os.clock()


        getDataflashSummary()
    end    
end

local function getFreeDataflashSpace()

    local freeSpace = summary.totalSize - summary.usedSize

    local msg

    if config.display == 0 or config.display == nil then
        msg = string.format("%.1f/%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"),
        summary.usedSize / (1024 * 1024),
        summary.totalSize / (1024 * 1024))
    elseif config.display == 1 then
        msg = string.format("%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"), freeSpace / (1024 * 1024))
    elseif config.display == 2 then 
        msg = string.format("%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"), summary.usedSize / (1024 * 1024))
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
        rfsuite.widgets.toolbox.utils.screenError(msg)
        return
    end

    local w, h = lcd.getWindowSize()

    local TITLE_COLOR = lcd.darkMode() and lcd.RGB(154,154,154) or lcd.RGB(77, 73, 77)
    local TEXT_COLOR = lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(77, 73, 77)
    local valueOffset = 0
    if widget.title then
        lcd.font(FONT_S)
        local titlemsg = "Blackbox"
        local tsizeW, tsizeH = lcd.getTextSize(titlemsg)
        valueOffset = (tsizeH/2) 
        lcd.color(TITLE_COLOR)  -- Set text color
        lcd.drawText((w - tsizeW) / 2, tsizeH/4, titlemsg)
        lcd.color(TEXT_COLOR)  -- Reset text color for values
    end



    if isErase then
        msg = rfsuite.i18n.get("widgets.bbl.erasing")
    elseif not not rfsuite.tasks and not not rfsuite.tasks.telemetry and not rfsuite.tasks.telemetry.active() then
        msg = rfsuite.i18n.get("no_link"):upper() 
    elseif summary.totalSize and summary.usedSize then
        msg = getFreeDataflashSpace()       
    else
        msg = "-"
    end    

    drawCenteredMessage(msg,valueOffset)
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
        progressCounter = progressCounter + 5
        progress:value(progressCounter)
        if progressCounter >= 100 then
            summary.usedSize = 0
            rfsuite.session.bblUsed = 0
            progress:close()
            progress = nil
        end
    end
end

return rf2bbl