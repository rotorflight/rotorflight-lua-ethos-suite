--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local dashboard = {}

local compile = loadfile

local baseDir = rfsuite.config.baseDir
local preferences = rfsuite.config.preferences
local utils = rfsuite.utils
local log = utils.log
local tasks = rfsuite.tasks
local objectProfiler = false
local mod

local supportedResolutions = {{784, 294}, {784, 316}, {800, 458}, {800, 480}, {472, 191}, {472, 210}, {480, 301}, {480, 320}, {630, 236}, {630, 258}, {640, 338}, {640, 360}}

local lastFlightMode = nil

local initTime = os.clock()

local lastWakeup = os.clock()

local isSliding = false
local isSlidingStart = 0

dashboard.DEFAULT_THEME = "system/default"

local themesBasePath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/themes/"
local themesUserPath = "SCRIPTS:/" .. preferences .. "/dashboard/"

local loadedStateModules = {}

local wakeupScheduler = 0

local lastModelPath = model.path()
local lastModelPathCheckAt = 0
local PATH_CHECK_INTERVAL = 2.5

local objectWakeupIndex = 1
local objectWakeupsPerCycle = nil
local objectsThreadedWakeupCount = 0
local lastLoadedBoxCount = 0
local lastBoxRectsCount = 0
local lastLoadedBoxSig = nil

local moduleState

local statePreloadQueue = {"inflight", "postflight"}
local statePreloadIndex = 1

local unsupportedResolution = false

dashboard._objectDirty = {}

local scheduledBoxIndices = {}

local firstWakeup = true
local firstWakeupCustomTheme = true

dashboard.boxRects = {}
dashboard.selectedBoxIndex = 1

dashboard.themeFallbackUsed = {preflight = false, inflight = false, postflight = false}
dashboard.themeFallbackTime = {preflight = 0, inflight = 0, postflight = 0}

dashboard.flightmode = rfsuite.flightmode.current or "preflight"

dashboard.currentWidgetPath = nil

dashboard.overlayMessage = nil

dashboard.objectsByType = {}

dashboard.loaderScale = 0.38
dashboard.overlayScale = 0.38

local darkModeState = lcd.darkMode()

dashboard._moduleCache = dashboard._moduleCache or {}

dashboard._hg_cycles_required = 2
dashboard._hg_cycles = 0

dashboard._loader_min_duration = 1.5
dashboard._loader_start_time = nil

dashboard._minPaintInterval = 0.1
dashboard._lastInvalidateTime = 0
dashboard._pendingInvalidates = {}

local function _queueInvalidateRect(x, y, w, h)
    local r = {x = x, y = y, w = w, h = h}
    dashboard._pendingInvalidates[#dashboard._pendingInvalidates + 1] = r
end

local function _flushInvalidatesRespectingBudget()
    local now = os.clock()
    if (now - dashboard._lastInvalidateTime) < dashboard._minPaintInterval then return false end

    if #dashboard._pendingInvalidates == 0 then return false end

    if #dashboard._pendingInvalidates > 6 then
        lcd.invalidate()
        dashboard._pendingInvalidates = {}
        dashboard._lastInvalidateTime = now
        return true
    end

    local x1, y1, x2, y2 = 1e9, 1e9, -1e9, -1e9
    for _, r in ipairs(dashboard._pendingInvalidates) do
        if r.x < x1 then x1 = r.x end
        if r.y < y1 then y1 = r.y end
        if (r.x + r.w) > x2 then x2 = r.x + r.w end
        if (r.y + r.h) > y2 then y2 = r.y + r.h end
    end
    lcd.invalidate(x1, y1, x2 - x1, y2 - y1)
    dashboard._pendingInvalidates = {}
    dashboard._lastInvalidateTime = now
    return true
end

dashboard.prof = dashboard.prof or {enabled = true, reportEvery = 2.0, lastReport = 0, perId = {}, firstInventoryDone = false}

local function _profStart()
    if not (dashboard.prof and dashboard.prof.enabled) then return 0 end
    return os.clock()
end

local function _profStop(kind, id, typ, t0)
    if t0 == 0 then return end
    local dt = os.clock() - t0
    local rec = dashboard.prof.perId[id]
    if not rec then
        rec = {type = typ, paint = 0, wakeup = 0, pc = 0, wc = 0}
        dashboard.prof.perId[id] = rec
    end
    if kind == "paint" then
        rec.paint = rec.paint + dt
        rec.pc = rec.pc + 1
    else
        rec.wakeup = rec.wakeup + dt
        rec.wc = rec.wc + 1
    end
end

local function _profIdFromRect(rect)
    local b = rect.box

    local H = rect.isHeader and "H" or "B"
    return string.format("%s@%s:%d,%d,%dx%d", b.type or "?", H, rect.x, rect.y, rect.w, rect.h)
end

local function _profReportIfDue()
    local P = dashboard.prof
    if not (P and P.enabled) then return end
    local now = os.clock()
    if P.lastReport == 0 then
        P.lastReport = now
        return
    end
    if (now - P.lastReport) < (P.reportEvery or 2.0) then return end

    local rows, perTypeAgg = {}, {}
    for id, v in pairs(P.perId) do
        local tot = (v.paint + v.wakeup)
        rows[#rows + 1] = {id = id, type = v.type, paint = v.paint, wake = v.wakeup, pc = v.pc, wc = v.wc, tot = tot}
        local T = v.type or "?"
        local agg = perTypeAgg[T] or {paint = 0, wake = 0, pc = 0, wc = 0, tot = 0}
        agg.paint, agg.wake, agg.pc, agg.wc, agg.tot = agg.paint + v.paint, agg.wake + v.wakeup, agg.pc + v.pc, agg.wc + v.wc, agg.tot + tot
        perTypeAgg[T] = agg
    end
    table.sort(rows, function(a, b) return a.tot > b.tot end)

    log("--------------- OBJECT PROFILER (per instance) ---------------", "info")
    for _, r in ipairs(rows) do
        local pms, wms = r.paint * 1000, r.wake * 1000
        local ap = r.pc > 0 and (pms / r.pc) or 0
        local aw = r.wc > 0 and (wms / r.wc) or 0
        log(string.format("[prof] %-40s | paint:%7.3fms (%4d, avg %6.3f) | wakeup:%7.3fms (%4d, avg %6.3f)", r.id, pms, r.pc, ap, wms, r.wc, aw), "info")

        local rec = P.perId[r.id];
        rec.paint, rec.wakeup, rec.pc, rec.wc = 0, 0, 0, 0
    end
    log("-------------------- per-type summary ------------------------", "info")
    for T, a in pairs(perTypeAgg) do log(string.format("[sum ] %-18s | paint:%7.3fms | wakeup:%7.3fms | total:%7.3fms", T, a.paint * 1000, a.wake * 1000, a.tot * 1000), "info") end
    log("--------------------------------------------------------------", "info")

    P.lastReport = now
end

function dashboard.loader(x, y, w, h)

    -- old style - maybe a preference at some point?
    --dashboard.loaders.staticLoader(dashboard, x, y, w, h)

    local logmsg = rfsuite.tasks.logger and rfsuite.tasks.logger.getConnectLines(20, { noTimestamp = true })
    dashboard.loaders.logsLoader(dashboard, x, y, w, h, logmsg, opts)


    _queueInvalidateRect(x, y, w, h)
    _flushInvalidatesRespectingBudget()
end

local function forceInvalidateAllObjects()
    for _, rect in ipairs(dashboard.boxRects) do
        local obj = dashboard.objectsByType[rect.box.type]
        if obj and obj.dirty and obj.dirty(rect.box) then _queueInvalidateRect(rect.x, rect.y, rect.w, rect.h) end
    end
    _flushInvalidatesRespectingBudget()
end

function dashboard.overlaymessage(x, y, w, h, txt) 

    -- old style - maybe a preference at some point?
    --dashboard.loaders.staticOverlayMessage(dashboard, x, y, w, h, txt) 

    local logmsg = rfsuite.tasks.logger and rfsuite.tasks.logger.getConnectLines(5, { noTimestamp = true })   
    dashboard.loaders.logsLoader(dashboard, x, y, w, h, logmsg)
end

local function computeObjectSchedulerPercentage(count)
    if count <= 10 then
        return 0.8
    elseif count <= 15 then
        return 0.7
    elseif count <= 25 then
        return 0.6
    elseif count <= 40 then
        return 0.5
    else
        return 0.4
    end
end

function dashboard.loadObjectType(box)
    local typ = box and box.type
    if not typ then return end

    if not dashboard._moduleCache[typ] then

        local bdir = baseDir or "default"
        local objPath = "SCRIPTS:/" .. bdir .. "/widgets/dashboard/objects/" .. typ .. ".lua"

        local ok, obj = pcall(function() return assert(compile(objPath))() end)
        if ok and type(obj) == "table" then
            dashboard._moduleCache[typ] = obj
        else
            log("Failed to load object: " .. tostring(typ), "info")
            dashboard._moduleCache[typ] = false
        end
    end

    if dashboard._moduleCache[typ] then dashboard.objectsByType[typ] = dashboard._moduleCache[typ] end
end

function dashboard.loadAllObjects(boxConfigs)
    dashboard.objectsByType = {}
    for _, box in ipairs(boxConfigs or {}) do
        local typ = box.type
        if typ then

            if not dashboard._moduleCache[typ] then
                local bdir = baseDir or "default"
                local objPath = "SCRIPTS:/" .. bdir .. "/widgets/dashboard/objects/" .. typ .. ".lua"
                local ok, obj = pcall(function() return assert(compile(objPath))() end)
                if ok and type(obj) == "table" then
                    dashboard._moduleCache[typ] = obj
                else
                    log("Failed to load object: " .. tostring(typ), "info")

                    dashboard._moduleCache[typ] = false
                end
            end

            if dashboard._moduleCache[typ] then dashboard.objectsByType[typ] = dashboard._moduleCache[typ] end
        end
    end
end

local function getOnpressBoxIndices()
    local indices = {}
    for i, rect in ipairs(dashboard.boxRects) do if rect.box.onpress then indices[#indices + 1] = i end end
    return indices
end

function dashboard.computeOverlayMessage()

    local state = dashboard.flightmode or "preflight"
    local telemetry = tasks.telemetry
    local pad = "      "

    if dashboard.themeFallbackUsed and dashboard.themeFallbackUsed[state] and (os.clock() - (dashboard.themeFallbackTime and dashboard.themeFallbackTime[state] or 0)) < 10 then return "@i18n(widgets.dashboard.theme_load_error)@" end

    local elapsed = os.clock() - initTime
    if elapsed > 10 then if not tasks.active() then return "@i18n(widgets.dashboard.check_bg_task)@" end end

    if rfsuite.session.apiVersion and rfsuite.session.rfVersion and not rfsuite.session.isConnectedLow and state ~= "postflight" then
        if system.getVersion().simulation == true then
            return pad .. "SIM " .. rfsuite.session.apiVersion .. pad
        else
            return pad .. "RF" .. rfsuite.session.rfVersion .. pad
        end
    end

    -- old path for later optional use
    --if not rfsuite.session.isConnectedHigh and state ~= "postflight" then return "@i18n(widgets.dashboard.waiting_for_connection)@" end

    if not rfsuite.session.isConnected and state ~= "postflight" then
        return "@i18n(widgets.dashboard.waiting_for_connection)@"
    end

    return nil
end

local function getBoxSize(box, boxWidth, boxHeight, PADDING, WIDGET_W, WIDGET_H)
    if box.w_pct and box.h_pct then
        local wp = box.w_pct
        local hp = box.h_pct
        if wp > 1 then wp = wp / 100 end
        if hp > 1 then hp = hp / 100 end
        local w = math.floor(wp * WIDGET_W)
        local h = math.floor(hp * WIDGET_H)
        return w, h
    elseif box.w and box.h then
        return tonumber(box.w) or boxWidth, tonumber(box.h) or boxHeight
    elseif box.colspan or box.rowspan then
        local w = math.floor((box.colspan or 1) * boxWidth + ((box.colspan or 1) - 1) * PADDING)
        local h = math.floor((box.rowspan or 1) * boxHeight + ((box.rowspan or 1) - 1) * PADDING)
        return w, h
    else
        return boxWidth, boxHeight
    end
end

local function getBoxPosition(box, w, h, boxWidth, boxHeight, PADDING, WIDGET_W, WIDGET_H)

    if box.x_pct and box.y_pct then
        local xp = box.x_pct
        local yp = box.y_pct
        if xp > 1 then xp = xp / 100 end
        if yp > 1 then yp = yp / 100 end

        local x = math.floor(xp * (WIDGET_W - (w or boxWidth)))
        local y = math.floor(yp * (WIDGET_H - (h or boxHeight)))
        return x, y
    elseif box.x and box.y then
        local x = tonumber(box.x) or 0
        local y = tonumber(box.y) or 0
        return x, y
    elseif box.col and box.row then
        local col = box.col or 1
        local row = box.row or 1
        local x = math.floor((col - 1) * (boxWidth + PADDING)) + (box.xOffset or 0)
        local y = math.floor(PADDING + (row - 1) * (boxHeight + PADDING))
        return x, y
    else
        return 0, 0
    end
end

function dashboard.renderLayout(widget, config)
    local utils = dashboard.utils
    local telemetry = tasks.telemetry

    dashboard.boxRects = dashboard.boxRects or {}
    scheduledBoxIndices = scheduledBoxIndices or {}
    dashboard._objectDirty = dashboard._objectDirty or {}

    local function resolve(val, ...) return type(val) == "function" and val(...) or val end

    local layout = resolve(config.layout) or {}
    local headerLayout = resolve(config.header_layout) or {}
    local boxes = resolve(config.boxes or layout.boxes or {})
    local headerBoxes = resolve(config.header_boxes or {})

    if (#boxes + #headerBoxes) ~= lastLoadedBoxCount then
        local allBoxes = {}
        for _, b in ipairs(boxes) do table.insert(allBoxes, b) end
        for _, b in ipairs(headerBoxes) do table.insert(allBoxes, b) end
        dashboard.loadAllObjects(allBoxes)
        lastLoadedBoxCount = #boxes + #headerBoxes
    end

    local function makeBoxesSig(bx, hbx)
        local t = {}
        for _, b in ipairs(bx or {}) do t[#t + 1] = tostring(b.type or "") end
        for _, b in ipairs(hbx or {}) do t[#t + 1] = tostring(b.type or "") end
        table.sort(t)
        return table.concat(t, "|")
    end

    local thisSig = makeBoxesSig(boxes, headerBoxes)

    if ((#boxes + #headerBoxes) ~= lastLoadedBoxCount) or (thisSig ~= lastLoadedBoxSig) then
        local allBoxes = {}
        for _, b in ipairs(boxes) do allBoxes[#allBoxes + 1] = b end
        for _, b in ipairs(headerBoxes) do allBoxes[#allBoxes + 1] = b end
        dashboard.loadAllObjects(allBoxes)
        lastLoadedBoxCount = #boxes + #headerBoxes
        lastLoadedBoxSig = thisSig
    end

    for k in pairs(dashboard._objectDirty) do dashboard._objectDirty[k] = nil end

    local W_raw, H_raw = lcd.getWindowSize()
    local isFullScreen = utils.isFullScreen(W_raw, H_raw)
    local cols = layout.cols or 1
    local rows = layout.rows or 1
    local pad = layout.padding or 0

    local function adjustDimension(dim, cells, padCount) return dim - ((dim - padCount * pad) % cells) end

    if isFullScreen and headerLayout and headerLayout.height and type(headerLayout.height) == "number" then H_raw = H_raw - headerLayout.height end

    local W = adjustDimension(W_raw, cols, cols - 1)
    local H = adjustDimension(H_raw, rows, rows + 1)
    local xOffset = math.floor((W_raw - W) / 2)

    local contentW = W - ((cols - 1) * pad)
    local contentH = H - ((rows + 1) * pad)
    local boxW = contentW / cols
    local boxH = contentH / rows

    utils.setBackgroundColourBasedOnTheme()

    for i = #dashboard.boxRects, 1, -1 do dashboard.boxRects[i] = nil end
    for i = #scheduledBoxIndices, 1, -1 do scheduledBoxIndices[i] = nil end

    for _, box in ipairs(boxes) do
        local w, h = getBoxSize(box, boxW, boxH, pad, W, H)
        box.xOffset = xOffset
        local x, y = getBoxPosition(box, w, h, boxW, boxH, pad, W, H)
        if isFullScreen and headerLayout and headerLayout.height and type(headerLayout.height) == "number" then y = y + headerLayout.height end

        local rect = {x = x, y = y, w = w, h = h, box = box, isHeader = false}
        table.insert(dashboard.boxRects, rect)

        local rectIndex = #dashboard.boxRects
        dashboard._objectDirty[rectIndex] = nil

        local obj = dashboard.objectsByType[box.type]
        if obj and obj.scheduler and obj.wakeup then table.insert(scheduledBoxIndices, rectIndex) end
    end

    if isFullScreen then
        local headerGeoms = {}
        local rightmost_idx, rightmost_x = 1, 0
        for idx, box in ipairs(headerBoxes) do
            local w, h = getBoxSize(box, boxW, boxH, pad, W_raw, headerLayout.height)
            local x, y = getBoxPosition(box, w, h, boxW, boxH, pad, W_raw, headerLayout.height)
            headerGeoms[idx] = {x = x, y = y, w = w, h = h, box = box}
            if x > rightmost_x then
                rightmost_idx = idx
                rightmost_x = x
            end
        end

        for idx, geom in ipairs(headerGeoms) do
            local w = geom.w
            if idx == rightmost_idx then w = W_raw - geom.x end

            local rect = {x = geom.x, y = geom.y, w = w, h = geom.h, box = geom.box, isHeader = true}
            table.insert(dashboard.boxRects, rect)
            local idx_rect = #dashboard.boxRects
            dashboard._objectDirty[idx_rect] = nil

            local obj = dashboard.objectsByType[geom.box.type]
            if obj and obj.scheduler and obj.wakeup then table.insert(scheduledBoxIndices, idx_rect) end
        end
    end

    if not objectWakeupsPerCycle or #dashboard.boxRects ~= lastBoxRectsCount then
        local count = #dashboard.boxRects
        local percentage = dashboard._spreadRatioOverride or computeObjectSchedulerPercentage(count)

        if objectsThreadedWakeupCount < 1 then
            percentage = 1.0
            log("Accelerating first wakeup pass with 100% objects per cycle", "info")
        end

        objectWakeupsPerCycle = math.max(1, math.ceil(count * percentage))
        lastBoxRectsCount = count

        log("Object scheduler set to " .. objectWakeupsPerCycle .. " out of " .. count .. " boxes", "info")
    end

    dashboard._loader_start_time = dashboard._loader_start_time or os.clock()
    local loaderElapsed = os.clock() - dashboard._loader_start_time
    if objectsThreadedWakeupCount < 1 or loaderElapsed < dashboard._loader_min_duration then
        local loaderY = (isFullScreen and headerLayout.height) or 0
        dashboard.loader(0, loaderY, W, H - loaderY)
        _queueInvalidateRect(0, loaderY, W, H - loaderY)
        _flushInvalidatesRespectingBudget()
        return
    end

    local selColor = layout.selectcolor or utils.resolveColor("yellow") or lcd.RGB(255, 255, 0)
    local selBorder = layout.selectborder or 2

    for i, rect in ipairs(dashboard.boxRects) do
        if not rect.isHeader then
            local box = rect.box
            local obj = dashboard.objectsByType[box.type]
            if obj and obj.paint then
                if objectProfiler then
                    local id = _profIdFromRect(rect)
                    local t0 = _profStart()
                    obj.paint(rect.x, rect.y, rect.w, rect.h, box)
                    _profStop("paint", id, box.type, t0)
                else
                    obj.paint(rect.x, rect.y, rect.w, rect.h, box)
                end
            end

            if dashboard.selectedBoxIndex == i and box.onpress then
                lcd.color(selColor)
                lcd.drawRectangle(rect.x, rect.y, rect.w, rect.h, selBorder)
            end
        end
    end

    if isFullScreen and config.header_layout and #headerBoxes > 0 then
        local header = config.header_layout
        local h_cols = header.cols or 1
        local h_rows = header.rows or 1
        local h_pad = header.padding or 0

        local headerW = W_raw
        local headerH = header.height or 0

        local function adjustHeaderDimension(dim, cells, padCount) return dim - ((dim - padCount * h_pad) % cells) end

        local adjustedW = adjustHeaderDimension(headerW, h_cols, h_cols - 1)
        local adjustedH = adjustHeaderDimension(headerH, h_rows, h_rows - 1)

        local contentW = adjustedW - ((h_cols - 1) * h_pad)
        local contentH = adjustedH - ((h_rows - 1) * h_pad)
        local h_boxW = contentW / h_cols
        local h_boxH = contentH / h_rows

        local rightmost_idx, rightmost_x = 1, 0
        local headerGeoms = {}
        for idx, box in ipairs(headerBoxes) do
            local w, h = getBoxSize(box, h_boxW, h_boxH, h_pad, adjustedW, adjustedH)
            local x, y = getBoxPosition(box, w, h, h_boxW, h_boxH, h_pad, adjustedW, adjustedH)
            headerGeoms[idx] = {x = x, y = y, w = w, h = h, box = box}
            if x > rightmost_x then
                rightmost_idx = idx
                rightmost_x = x
            end
        end

        for idx, geom in ipairs(headerGeoms) do
            local w = geom.w
            if idx == rightmost_idx then w = W_raw - geom.x end
            local obj = dashboard.objectsByType[geom.box.type]
            if obj and obj.paint then
                if objectProfiler then
                    local fakeRect = {x = geom.x, y = geom.y, w = w, h = geom.h, box = geom.box, isHeader = true}
                    local id = _profIdFromRect(fakeRect)
                    local t0 = _profStart()
                    obj.paint(geom.x, geom.y, w, geom.h, geom.box)
                    _profStop("paint", id, geom.box.type, t0)
                else
                    obj.paint(geom.x, geom.y, w, geom.h, geom.box)
                end
            end
        end

        if isFullScreen and headerLayout and headerLayout.showgrid then
            lcd.color(headerLayout.showgrid)
            lcd.pen(1)

            for i = 1, h_cols - 1 do
                local x = math.floor(i * (h_boxW + h_pad)) - math.floor(h_pad / 2)
                lcd.drawLine(x, 0, x, headerLayout.height)
            end

            for i = 1, h_rows - 1 do
                local y = math.floor(i * (h_boxH + h_pad)) - math.floor(h_pad / 2)
                lcd.drawLine(0, y, W_raw, y)
            end

            lcd.pen(SOLID)
        end

    end

    if layout.showgrid or rfsuite.preferences.developer.overlaygrid then
        lcd.color(layout.showgrid)
        lcd.pen(1)

        local headerOffset = (isFullScreen and headerLayout and headerLayout.height) or 0

        for i = 1, cols - 1 do
            local x = math.floor(i * (boxW + pad)) + xOffset - math.floor(pad / 2)
            lcd.drawLine(x, headerOffset, x, H_raw + headerOffset)
        end

        for i = 1, rows - 1 do
            local y = math.floor(i * (boxH + pad)) + pad + headerOffset
            lcd.drawLine(0, y, W_raw, y)
        end

        lcd.pen(SOLID)
    end

    if layout.showstats or rfsuite.preferences.developer.overlaystats then
        local headerOffset = (isFullScreen and headerLayout and headerLayout.height) or 0

        local cpuUsage = (rfsuite.performance and rfsuite.performance.cpuload) or 0
        local loopMs = (rfsuite.performance and rfsuite.performance.loop_ms) or 0
        local budgetMs = (rfsuite.performance and rfsuite.performance.budget_ms) or 50
        local tickMs = (rfsuite.performance and rfsuite.performance.tick_ms)
        local headroomPct = math.max(0, 100 - (cpuUsage or 0))

        local ramFreeKB = (rfsuite.performance and rfsuite.performance.luaRamKB) or 0
        local ramUsedGC_KB = (rfsuite.performance and rfsuite.performance.usedram) or 0
        local sysRamFreeKB = (rfsuite.performance and rfsuite.performance.ramKB) or 0
        local bitmapRamFreeKB = (rfsuite.performance and rfsuite.performance.luaBitmapsRamKB) or 0
        local mainStackKB = (rfsuite.performance and rfsuite.performance.mainStackKB) or 0

        lcd.font(FONT_S)
        local _, lineH = lcd.getTextSize("A")

        local cfg = {padX = 8, padY = 6, colGap = 10, rowGap = 2, labelW = 170, valueW = 120, unitW = 30, sectionGap = 8, decimalsMS = 1, decimalsKB = 1, boxX = 4, boxY = 4 + headerOffset, bg = {0, 0, 0, 0.9}, fg = {255, 255, 255}, border = true, showActualPeriod = true}

        local function fmtPct(n) return rfsuite.utils.round(n or 0, 0) end
        local function fmtMS(n) return string.format("%." .. cfg.decimalsMS .. "f", n or 0) end
        local function fmtKB(n) return string.format("%." .. cfg.decimalsKB .. "f", n or 0) end

        local schedRows = {{"LOAD", fmtPct(cpuUsage), "%"}, {"LOAD (100ms window)", fmtPct(rfsuite.performance.cpuload_window100 or 0), "%"}, {"HEADROOM", fmtPct(headroomPct), "%"}, {"LOOP / BUDGET", fmtMS(loopMs) .. " / " .. fmtMS(budgetMs), "ms"}}
        if cfg.showActualPeriod and tickMs then table.insert(schedRows, {"ACTUAL PERIOD", fmtMS(tickMs), "ms"}) end

        local memRows = {{"LUA RAM FREE", fmtKB(ramFreeKB), "KB"}, {"LUA RAM USED (GC)", fmtKB(ramUsedGC_KB), "KB"}, {"SYSTEM RAM FREE", fmtKB(sysRamFreeKB), "KB"}, {"LUA BITMAP RAM", fmtKB(bitmapRamFreeKB), "KB"}}

        local boxW = cfg.padX * 2 + cfg.labelW + cfg.colGap + cfg.valueW + cfg.colGap + cfg.unitW

        local sectionHeaderH = lineH
        local totalRows = #schedRows + #memRows
        local boxH = cfg.padY * 2 + sectionHeaderH + (#schedRows * (lineH + cfg.rowGap)) + cfg.sectionGap + sectionHeaderH + (#memRows * (lineH + cfg.rowGap))

        local screenW, screenH = lcd.getWindowSize()
        local boxX = math.floor((screenW - boxW) / 2)
        local boxY = math.floor((screenH - boxH) / 2)
        local minY = 4 + headerOffset
        if boxY < minY then boxY = minY end

        lcd.color(lcd.RGB(cfg.bg[1], cfg.bg[2], cfg.bg[3], cfg.bg[4]))
        lcd.drawFilledRectangle(boxX, boxY, boxW, boxH)
        if cfg.border then
            lcd.pen(1)
            lcd.color(lcd.RGB(cfg.fg[1], cfg.fg[2], cfg.fg[3]))
            lcd.drawRectangle(boxX, boxY, boxW, boxH)
            lcd.pen(0)
        end

        local labelX = boxX + cfg.padX
        local valueX = labelX + cfg.labelW + cfg.colGap
        local unitX = valueX + cfg.valueW + cfg.colGap
        local y = boxY + cfg.padY

        local function drawSection(title, rows)

            lcd.color(lcd.RGB(cfg.fg[1], cfg.fg[2], cfg.fg[3]))
            lcd.font(FONT_S_BOLD)
            lcd.drawText(labelX, y, title)
            lcd.font(FONT_S)
            y = y + sectionHeaderH + cfg.rowGap

            for i = 1, #rows do
                local label, value, unit = rows[i][1], rows[i][2], rows[i][3]
                lcd.drawText(labelX, y, label)

                local tw = lcd.getTextSize(tostring(value))
                lcd.drawText(valueX + cfg.valueW - tw, y, tostring(value))
                lcd.drawText(unitX, y, tostring(unit))
                y = y + lineH + cfg.rowGap
            end

            y = y + cfg.sectionGap
        end

        drawSection("SCHEDULER", schedRows)
        drawSection("MEMORY", memRows)
    end

    if dashboard.overlayMessage then dashboard._hg_cycles = dashboard._hg_cycles_required end
    if dashboard._hg_cycles > 0 then
        local loaderY = (isFullScreen and headerLayout.height) or 0
        dashboard.overlaymessage(0, loaderY, W, H - loaderY, dashboard.overlayMessage)
        dashboard._hg_cycles = dashboard._hg_cycles - 1
        _queueInvalidateRect(0, loaderY, W, H - loaderY)
        _flushInvalidatesRespectingBudget()
        return
    end

    dashboard._forceFullRepaint = true
end

local function getThemeForState(state)
    local prefs = rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.dashboard
    local fallback = rfsuite.preferences.dashboard
    local val = prefs and prefs["theme_" .. state]
    return (val and val ~= "nil" and val) or fallback["theme_" .. state] or dashboard.DEFAULT_THEME
end

local function load_state_script(theme_folder, state, isFallback)
    isFallback = isFallback or false

    local src, folder = theme_folder:match("([^/]+)/(.+)")
    local base = (src == "user") and themesUserPath or themesBasePath

    if not src or not folder then
        if not isFallback then return load_state_script(dashboard.DEFAULT_THEME, state, true) end

        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
        return nil
    end

    local function setPath() dashboard.currentWidgetPath = src .. "/" .. folder end

    local initPath = base .. folder .. "/init.lua"
    local initChunk, initErr = compile(initPath)
    if not initChunk then
        if not isFallback then return load_state_script(dashboard.DEFAULT_THEME, state, true) end
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
        return nil
    end

    local ok, initTable = pcall(initChunk)
    if not ok or type(initTable) ~= "table" then
        if not isFallback then return load_state_script(dashboard.DEFAULT_THEME, state, true) end
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
        return nil
    end

    local scriptName = (type(initTable[state]) == "string" and initTable[state] ~= "") and initTable[state] or (state .. ".lua")
    local scriptPath = base .. folder .. "/" .. scriptName

    local chunk, chunkErr = compile(scriptPath)
    if not chunk then
        if not isFallback then return load_state_script(dashboard.DEFAULT_THEME, state, true) end

        log("dashboard: Could not load " .. scriptName .. " for " .. folder .. " or default: " .. tostring(chunkErr), "info")
        dashboard.themeFallbackUsed[state] = true
        dashboard.themeFallbackTime[state] = os.clock()
        return nil
    end

    dashboard.themeFallbackUsed[state] = (isFallback == true)
    dashboard.themeFallbackTime[state] = isFallback and os.clock() or 0
    setPath()

    if initTable.standalone then
        return chunk
    else
        local ok2, module = pcall(chunk)
        if not ok2 then
            if not isFallback then return load_state_script(dashboard.DEFAULT_THEME, state, true) end
            dashboard.themeFallbackUsed[state] = true
            dashboard.themeFallbackTime[state] = os.clock()
            return nil
        end
        return module
    end
end

local function getThemeForState(state)
    local modelPrefs = rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.dashboard
    local userPrefs = rfsuite.preferences.dashboard
    local val = nil
    if modelPrefs then
        val = modelPrefs["theme_" .. state]
        if val == "nil" then val = nil end
    end
    return val or userPrefs["theme_" .. state] or dashboard.DEFAULT_THEME
end

local function reload_state_only(state)
    dashboard.utils.resetImageCache()
    loadedStateModules[state] = load_state_script(getThemeForState(state), state)
    lastLoadedBoxCount = 0
    lastBoxRectsCount = 0
    objectWakeupIndex = 1
    objectsThreadedWakeupCount = 0
    objectWakeupsPerCycle = nil
    dashboard.boxRects = {}
    if dashboard.boxRects then for k in pairs(dashboard.boxRects) do dashboard.boxRects[k] = nil end end
    lcd.invalidate()
end

function dashboard.reload_active_theme_only(force)
    dashboard.utils.resetImageCache()

    local state = dashboard.flightmode or "preflight"
    local theme = getThemeForState(state)

    if force or not loadedStateModules[state] then
        log("Reloading active theme: " .. theme, "info")
        loadedStateModules[state] = load_state_script(theme, state)
    else
        log("Skipped reloading active theme: already loaded", "info")
    end

    firstWakeup = true
    lcd.invalidate()

    wakeupScheduler = 0
    dashboard.boxRects = {}
    objectsThreadedWakeupCount = 0
    objectWakeupIndex = 1
    lastLoadedBoxCount = 0
    lastBoxRectsCount = 0
    objectWakeupsPerCycle = nil
    lastLoadedBoxSig = nil

    lcd.invalidate()
end

function dashboard.applySchedulerSettings()

    local active = dashboard.flightmode or "preflight"
    local mod = loadedStateModules[active]
    if mod and mod.scheduler then
        local initTable = (type(mod.scheduler) == "function") and mod.scheduler() or mod.scheduler
        if type(initTable) == "table" then

            dashboard._useSpreadScheduling = (initTable.spread_scheduling ~= false)
            dashboard._useSpreadSchedulingPaint = (initTable.spread_scheduling_paint ~= false)

            dashboard._spreadRatioOverride = (type(initTable.spread_ratio) == "number" and initTable.spread_ratio > 0 and initTable.spread_ratio <= 1) and initTable.spread_ratio or nil
        else
            dashboard._useSpreadScheduling = true
            dashboard._useSpreadSchedulingPaint = true
            dashboard._spreadRatioOverride = nil
        end
    else
        dashboard._useSpreadScheduling = true
        dashboard._useSpreadSchedulingPaint = true
        dashboard._spreadRatioOverride = nil
    end

end

function dashboard.reload_themes(force)

    dashboard.renders = {}

    dashboard.reload_active_theme_only(force)

    statePreloadIndex = 1

    dashboard.applySchedulerSettings()

    local boxes = {}
    if mod and mod.boxes then
        local rawBoxes = type(mod.boxes) == "function" and mod.boxes() or mod.boxes
        for _, box in ipairs(rawBoxes or {}) do table.insert(boxes, box) end
    end
    dashboard.loadAllObjects(boxes)

    firstWakeup = true
    dashboard._loader_start_time = nil
    dashboard._hg_cycles = dashboard._hg_cycles_required

    dashboard._forceFullRepaint = true
    if dashboard.boxRects then for k in pairs(dashboard.boxRects) do dashboard.boxRects[k] = nil end end
    lastBoxRectsCount = 0
    lastLoadedBoxCount = 0
    objectWakeupIndex = 1
    objectWakeupsPerCycle = nil
    objectsThreadedWakeupCount = 0
    lastLoadedBoxSig = nil

    local mod = loadedStateModules[dashboard.flightmode or "preflight"]
    if type(mod) == "table" and mod.layout and mod.boxes then
        log("Manually triggering renderLayout after theme reload", "info")
        dashboard.renderLayout(nil, mod)
    end

end

local function callStateFunc(funcName, widget, paintFallback)
    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if not tasks.active() then return nil end

    if type(module) == "table" and module.layout and funcName == "paint" then return module end

    if module and type(module[funcName]) == "function" then return module[funcName](widget) end

    if paintFallback then
        local msg = "dashboard: " .. funcName .. " not implemented for " .. state .. "."
        dashboard.utils.screenError(msg)
    end
end

function dashboard.create()

    if not dashboard.utils then dashboard.utils = assert(compile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/utils.lua"))() end
    if not dashboard.loaders then dashboard.loaders = assert(compile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/loaders.lua"))() end

    os.mkdir("SCRIPTS:/" .. rfsuite.config.preferences .. "/dashboard/")

    dashboard._pendingInvalidates = {}
    dashboard._lastInvalidateTime = 0
    dashboard._hg_cycles = 0
    dashboard.overlayMessage = nil

    firstWakeup = true
    firstWakeupCustomTheme = true
    wakeupScheduler = 0
    objectWakeupIndex = 1
    objectsThreadedWakeupCount = 0
    objectWakeupsPerCycle = nil
    scheduledBoxIndices = {}
    dashboard.boxRects = {}
    dashboard.selectedBoxIndex = nil

    lcd.invalidate()

    return {value = 0}
end

function dashboard.paint(widget)

    local isCompiledCheck = "@i18n(iscompiledcheck)@"
    if isCompiledCheck ~= "true" then
        dashboard.utils.screenError("i18n not compiled - download a release version", true, 0.6)
        return
    end

    if unsupportedResolution then

        local W, H = lcd.getWindowSize()
        if H < (system.getVersion().lcdHeight / 5) or W < (system.getVersion().lcdWidth / 10) then
            dashboard.utils.screenError("@i18n(widgets.dashboard.unsupported_resolution)@", true, 0.4)
        else
            dashboard.overlaymessage(0, 0, W, H, "@i18n(widgets.dashboard.unsupported_resolution)@")
        end
        return
    end

    if firstWakeup then
        local W, H = lcd.getWindowSize()
        local loaderY = (isFullScreen and headerLayout.height) or 0
        dashboard.loader(0, loaderY, W, H - loaderY)
        lcd.invalidate()
        return
    end

    if os.clock() - lastModelPathCheckAt >= PATH_CHECK_INTERVAL then
        local newModelPath = model.path()
        lastModelPathCheckAt = os.clock()
        if newModelPath ~= lastModelPath then
            lastModelPath = newModelPath

            local W, H = lcd.getWindowSize()
            local loaderY = (isFullScreen and headerLayout.height) or 0
            dashboard.loader(0, loaderY, W, H - loaderY)
            lcd.invalidate()
            return
        end
    end

    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if type(module) == "table" and module.layout and module.boxes then
        dashboard.renderLayout(widget, module)
        if type(module.paint) == "function" then module.paint(widget, module.layout, module.boxes) end
    else
        callStateFunc("paint", widget)
    end

    if objectProfiler then _profReportIfDue() end
end

function dashboard.configure(widget) return callStateFunc("configure", widget) or widget end

function dashboard.read(widget) return callStateFunc("read", widget) end

function dashboard.write(widget) return callStateFunc("write", widget) end

function dashboard.build(widget) return callStateFunc("build", widget) end

function dashboard.event(widget, category, value, x, y)

    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if state == "postflight" and category == EVT_KEY and value == 131 then
        rfsuite.widgets.dashboard.flightmode = "preflight"
        dashboard.resetFlightModeAsk()
    end

    if category == 1 and value == TOUCH_MOVE then
        isSliding = true
        isSlidingStart = os.clock()
    end

    if category == EVT_KEY and lcd.hasFocus() then
        local indices = getOnpressBoxIndices()
        local count = #indices
        if count == 0 then return end

        local current = dashboard.selectedBoxIndex or 1
        local pos = 1
        for i, idx in ipairs(indices) do
            if idx == current then
                pos = i
                break
            end
        end

        if value == 4099 then
            pos = pos - 1
            if pos < 1 then pos = count end
            dashboard.selectedBoxIndex = indices[pos]
            lcd.invalidate(widget)
            return true
        elseif value == 4100 then
            pos = pos + 1
            if pos > count then pos = 1 end
            dashboard.selectedBoxIndex = indices[pos]
            lcd.invalidate(widget)
            return true
        elseif value == 33 and category == EVT_KEY then
            local inIndices = false
            for i = 1, #indices do
                if indices[i] == dashboard.selectedBoxIndex then
                    inIndices = true
                    break
                end
            end
            if not inIndices then
                dashboard.selectedBoxIndex = indices[1]
                lcd.invalidate(widget)
                return true
            else
                local idx = dashboard.selectedBoxIndex
                local rect = dashboard.boxRects[idx]
                if rect and rect.box.onpress then
                    rect.box.onpress(widget, rect.box, rect.x, rect.y, category, value)
                    system.killEvents(97)
                    return true
                end
            end
        end
    end
    if value == 35 and dashboard.selectedBoxIndex then
        dashboard.selectedBoxIndex = nil
        lcd.invalidate(widget)
        return true
    end

    if category == 1 and value == 16641 and lcd.hasFocus() then
        if x and y then
            for i, rect in ipairs(dashboard.boxRects) do
                if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
                    if rect.box.onpress then
                        dashboard.selectedBoxIndex = i
                        lcd.invalidate(widget)
                        rect.box.onpress(widget, rect.box, x, y, category, value)
                        system.killEvents(16640)
                        return true
                    end
                end
            end
        end
    end

    if type(module) == "table" and type(module.event) == "function" then return module.event(widget, category, value, x, y) end

end

function dashboard.wakeup(widget)

    local now = os.clock()
    local visible = lcd.isVisible()
    local admin = rfsuite.app and rfsuite.app.guiIsRunning

    if admin or not visible then

        return
    elseif isSliding then

        if (now - isSlidingStart) > 1 then
            isSliding = false
        else
            return
        end
    end

    objectProfiler = rfsuite.preferences and rfsuite.preferences.developer and rfsuite.preferences.developer.logobjprof

    local telemetry = tasks.telemetry
    local W, H = lcd.getWindowSize()

    dashboard._lastWH = dashboard._lastWH or {w = nil, h = nil, supported = nil}

    if W ~= dashboard._lastWH.w or H ~= dashboard._lastWH.h then
        local supported = dashboard.utils.supportedResolution(W, H, supportedResolutions)
        if supported ~= dashboard._lastWH.supported then
            unsupportedResolution = not supported
            dashboard._lastWH.supported = supported

            lcd.invalidate(widget)
        end
        dashboard._lastWH.w, dashboard._lastWH.h = W, H
    end

    if unsupportedResolution then return end

    if lcd.darkMode() ~= darkModeState then
        darkModeState = lcd.darkMode()
        dashboard.reload_themes(true)
    end

    if firstWakeup then
        firstWakeup = false
        local theme = getThemeForState("preflight")
        log("Initial loading of preflight theme: " .. theme, "info")
        loadedStateModules.preflight = load_state_script(theme, "preflight")
        dashboard.applySchedulerSettings()
    end

    if statePreloadIndex <= #statePreloadQueue then
        local state = statePreloadQueue[statePreloadIndex]
        if not loadedStateModules[state] then
            local theme = getThemeForState(state)
            log("Preloading theme: " .. theme .. " for " .. state, "info")
            loadedStateModules[state] = load_state_script(theme, state)

            local mod = loadedStateModules[state]
            if mod and mod.boxes then
                local boxes = type(mod.boxes) == "function" and mod.boxes() or mod.boxes
                for _, box in ipairs(boxes or {}) do dashboard.loadObjectType(box) end
            end
        end
        statePreloadIndex = statePreloadIndex + 1
    end

    if firstWakeupCustomTheme and rfsuite.session.mcu_id and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.dashboard then

        local modelPrefs = rfsuite.session.modelPreferences.dashboard
        local currentPrefs = rfsuite.preferences.dashboard

        if (modelPrefs.theme_preflight and modelPrefs.theme_preflight ~= "nil" and modelPrefs.theme_preflight ~= currentPrefs.theme_preflight) or (modelPrefs.theme_inflight and modelPrefs.theme_inflight ~= "nil" and modelPrefs.theme_inflight ~= currentPrefs.theme_inflight) or (modelPrefs.theme_postflight and modelPrefs.theme_postflight ~= "nil" and modelPrefs.theme_postflight ~= currentPrefs.theme_postflight) then
            dashboard.reload_themes()
            firstWakeupCustomTheme = false
        end
    end

    local currentFlightMode = rfsuite.flightmode.current or "preflight"
    if lastFlightMode ~= currentFlightMode then
        dashboard.flightmode = currentFlightMode
        reload_state_only(currentFlightMode)
        lastFlightMode = currentFlightMode
        if dashboard._useSpreadSchedulingPaint then lcd.invalidate(widget) end
    end

    local newMessage = dashboard.computeOverlayMessage()
    if dashboard.overlayMessage ~= newMessage then
        dashboard.overlayMessage = newMessage
        dashboard._hg_cycles = newMessage and dashboard._hg_cycles_required or 0
        lcd.invalidate(widget)
    end

    local state = dashboard.flightmode or "preflight"
    local module = loadedStateModules[state]

    if module and type(module.wakeup) == "function" then
        module.wakeup(widget)
    else
        callStateFunc("wakeup", widget)
    end

    if #dashboard.boxRects > 0 then

        for _, idx in ipairs(scheduledBoxIndices) do
            local rect = dashboard.boxRects[idx]
            local obj = dashboard.objectsByType[rect.box.type]
            if obj and obj.wakeup then
                if objectProfiler then
                    local id = _profIdFromRect(rect)
                    local t0 = _profStart()
                    obj.wakeup(rect.box)
                    _profStop("wakeup", id, rect.box.type, t0)
                else
                    obj.wakeup(rect.box)
                end
            end
        end

        local needsFullInvalidate = dashboard._forceFullRepaint or dashboard.overlayMessage or objectsThreadedWakeupCount < 1
        local dirtyRects = {}

        if dashboard._useSpreadScheduling == false then

            for i, rect in ipairs(dashboard.boxRects) do
                local obj = dashboard.objectsByType[rect.box.type]
                if obj and obj.wakeup and not obj.scheduler then obj.wakeup(rect.box) end
                if not needsFullInvalidate then
                    local dirtyFn = obj and obj.dirty
                    if dirtyFn and dirtyFn(rect.box) then table.insert(dirtyRects, {x = rect.x - 1, y = rect.y - 1, w = rect.w + 2, h = rect.h + 2}) end
                end
            end

        else

            for i = 1, objectWakeupsPerCycle do
                local idx = objectWakeupIndex
                local rect = dashboard.boxRects[idx]
                if rect then
                    local obj = dashboard.objectsByType[rect.box.type]
                    if obj and obj.wakeup and not obj.scheduler then obj.wakeup(rect.box) end
                    if not needsFullInvalidate then
                        local dirtyFn = obj and obj.dirty
                        if dirtyFn and dirtyFn(rect.box) then table.insert(dirtyRects, {x = rect.x - 1, y = rect.y - 1, w = rect.w + 2, h = rect.h + 2}) end
                    end
                end
                objectWakeupIndex = (#dashboard.boxRects > 0) and ((objectWakeupIndex % #dashboard.boxRects) + 1) or 1
            end

        end

        objectsThreadedWakeupCount = objectsThreadedWakeupCount + 1

        if dashboard._useSpreadSchedulingPaint then
            if needsFullInvalidate then

                _queueInvalidateRect(0, 0, W, H)
                dashboard._forceFullRepaint = false
            else
                for _, r in ipairs(dirtyRects) do _queueInvalidateRect(r.x, r.y, r.w, r.h) end
            end
        else
            _queueInvalidateRect(0, 0, W, H)
        end

        _flushInvalidatesRespectingBudget()
    end

    if not lcd.hasFocus(widget) and dashboard.selectedBoxIndex ~= nil then
        log("Removing focus from box " .. tostring(dashboard.selectedBoxIndex), "info")
        dashboard.selectedBoxIndex = nil
        if dashboard._useSpreadSchedulingPaint then lcd.invalidate(widget) end
    end

    if not dashboard._useSpreadSchedulingPaint then lcd.invalidate() end
end

function dashboard.listThemes()
    local themes = {}
    local num = 0

    local function scanThemes(basePath, sourceType)
        local folders = system.listFiles(basePath)
        if not folders then return end
        for _, folder in ipairs(folders) do
            if folder ~= ".." and folder ~= "." and not folder:match("%.%a+$") then
                local themeDir = basePath .. folder .. "/"
                local initPath = themeDir .. "init.lua"
                if utils.dir_exists(basePath, folder) then
                    local chunk, err = compile(initPath)
                    if chunk then
                        local ok, initTable = pcall(chunk)
                        if ok and initTable and type(initTable.name) == "string" then
                            if not initTable.developer or rfsuite.preferences.developer.devtools == true then
                                num = num + 1
                                themes[num] = {name = initTable.name, configure = initTable.configure, folder = folder, idx = num, source = sourceType}
                            end
                        end
                    end
                end
            end
        end
    end

    scanThemes(themesBasePath, "system")
    local basePath = "SCRIPTS:/" .. preferences .. "/"
    if utils.dir_exists(basePath, 'dashboard') then scanThemes(themesUserPath, "user") end

    return themes
end

function dashboard.getPreference(key)
    if not rfsuite.session.modelPreferences or not dashboard.currentWidgetPath then return nil end

    if not rfsuite.app.guiIsRunning then
        return rfsuite.ini.getvalue(rfsuite.session.modelPreferences, dashboard.currentWidgetPath, key)
    else
        return rfsuite.ini.getvalue(rfsuite.session.modelPreferences, rfsuite.app.dashboardEditingTheme, key)
    end
end

function dashboard.savePreference(key, value)
    if not rfsuite.session.modelPreferences or not rfsuite.session.modelPreferencesFile or not dashboard.currentWidgetPath then return false end
    if not rfsuite.app.guiIsRunning then
        rfsuite.ini.setvalue(rfsuite.session.modelPreferences, dashboard.currentWidgetPath, key, value)
        return rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
    else
        rfsuite.ini.setvalue(rfsuite.session.modelPreferences, rfsuite.app.dashboardEditingTheme, key, value)
        return rfsuite.ini.save_ini_file(rfsuite.session.modelPreferencesFile, rfsuite.session.modelPreferences)
    end
end

function dashboard.resetFlightModeAsk()

    local buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()
                tasks.events.flightmode.reset()
                lcd.invalidate()
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }

    form.openDialog({width = nil, title = "@i18n(widgets.dashboard.reset_flight_ask_title)@", message = "@i18n(widgets.dashboard.reset_flight_ask_text)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

end

function dashboard.menu(widget) return {{"@i18n(widgets.dashboard.reset_flight)@", dashboard.resetFlightModeAsk}} end

dashboard.renders = dashboard.renders or {}

dashboard.title = false

dashboard.isSliding = function() return isSliding end

return dashboard
