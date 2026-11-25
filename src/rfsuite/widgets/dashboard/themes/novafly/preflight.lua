-- PREFLIGHT: the page left of the cockpit on its background (page.lua S.background); the cockpit lines run in from the right
-- and fade out. Head band: on the left the flight mode, in the middle the model name, on the right RSSI and VFR as five bars each without numbers;
-- on the left the pilot's model picture with a soft frame, on the right a box with the battery (charge, voltage, cells, capacity), cell
-- and consumption, open to the right edge; in the foot band four chips with the last flight: altitude, climb, sink, flight time.
-- The page opens and closes with a sideways swipe (cockpit.lua).
local H = ...
local floor = math.floor

local PHOTO = {x = 10, y = 66, h = 168}           -- the photo field, 4:3 from the height; the photo frame has the same size (gfx/photo_frame*.png)
local BARS = {rssi = 398, vfr = 438, bottom = 36, width = 4, step = 6}   -- five reception bars each as on the radio, rising 6 to 18; both groups side by side at the top right, the numbers are on the cockpit
local RSSI_STEPS = {42, 50, 60, 70, 85}         -- dB per bar; 42 is the radio's warning level
local VFR_STEPS = {20, 40, 60, 80, 95}          -- percent per bar
local HEAD_Y = 28                                 -- the middle of the head band (y 8-47)
local MODE = {x = 12, word = 16, value = 34}      -- on the left of the head band: FLIGHT MODE small, below it the mode in green (each the middle of its row)
local BATTERY = {x = 246, y = 66, w = 234, h = 174}  -- the box on the right, open to the edge; at the bottom at 240 like the chip of the banks page opposite, all parallel
local FOOT = {y = 262, h = 48, w = 112, gap = 6, x = 10}
local NO_ZONE = {x = 0, y = 0, w = 0, h = 0}   -- there is no BACK on a page: back is the swipe
local BATTERY_PAUSE = 3                              -- s until the next request for BATTERY_CONFIG when one failed or did not go out

local style, S = nil, nil
local nova = {dirty = false, armState = "unknown", flightLog = {}, highDetail = true, italic = nil}   -- the radio's font, no masks
local IMAGES = H.memo.images or {}   -- photo and photo frame stay loaded beyond closing the page: every opening loaded them
H.memo.images = IMAGES               -- again otherwise, and the X18 stopped
local battery, batteryFor = nil, nil   -- the suite without session.batteryConfig: BATTERY_CONFIG over the bus, and the heli (mcu_id) it belongs to
local request = {fc = nil, from = 0}   -- the request without an answer (for which heli) and from when the next may go

local function loadPhoto()   -- the model picture the pilot gave the model in Ethos, or nil; the cockpit knows its place on the card (H.photoPath)
    local name = nil
    if type(model) == "table" and type(model.bitmap) == "function" then
        local ok, b = pcall(model.bitmap)
        if ok and type(b) == "string" then name = b end
    end
    if IMAGES.photo ~= nil and IMAGES.photoName == name then return IMAGES.photo or nil end   -- kept by the name of the picture: another model, another picture
    IMAGES.photo, IMAGES.photoName = nil, name   -- let go of the previous picture: no reference holds it any more
    local photo = nil
    local path = (name ~= nil and name ~= "" and not name:find("default_", 1, true)) and H.photoPath(name) or nil
    if path ~= nil and type(lcd.loadBitmap) == "function" then
        local ok, bmp = pcall(lcd.loadBitmap, path)
        if ok and bmp then photo = bmp end
    end
    IMAGES.photo = photo or false
    return photo
end

local function photoBox()   -- place and size of the photo in the window: the height from the layout, the width 4 : 3 to it (Ethos keeps the aspect ratio of a picture)
    local h = style.sy(PHOTO.h)
    return style.sx(PHOTO.x), style.sy(PHOTO.y), floor(h * 4 / 3 + 0.5), h
end

local function photoFrame()   -- the soft frame over the photo: outside the page background at the place of the photo (gloss photo_frame.png, for the carbon colours
    local light = S.light()   -- photo_frame_carbon.png, light photo_frame_light_<colour>.png with the bands of the light background), one picture per screen size (S.suffix)
    local carbon = not light and type(H.colorName) == "function" and tostring(H.colorName()):find("carbon", 1, true)
    local name = "photo_frame" .. (light and ("_light_" .. H.lightName()) or (carbon and "_carbon" or "")) .. S.suffix() .. ".png"
    if IMAGES.frameName ~= name then IMAGES.frame, IMAGES.frameName = nil, name end
    if IMAGES.frame == nil then IMAGES.frame = H.loadAsset(lcd.loadBitmap, "gfx/" .. name) or false end
    if IMAGES.frame then
        local x, y, w, h = photoBox()
        pcall(lcd.drawBitmap, x, y, IMAGES.frame, w, h)
    end
end

local function steps(value, list)
    if value == nil then return 0 end
    local n = 0
    for i = 1, #list do if value >= list[i] then n = i end end
    return n
end

local function reception(x, full, color)   -- five bars, rising from left to right; the full ones in the link colour, the empty ones dim
    for i = 0, 4 do
        local h = 6 + i * 3
        S.fillRect(x + i * BARS.step, BARS.bottom - h, BARS.width, h, i < full and color or style.FIELD_DIM)
    end
end

local function modeWord(v)   -- the flight mode from the firmware's bits (runtime_config.h): HORIZON before ANGLE, otherwise Acro; RESCUE (32) comes with ANGLE and goes first
    if v == nil then return nil end
    v = floor(v)
    if floor(v / 32) % 2 == 1 then return "@i18n(widgets.dashboard.novafly.rescue)@" end
    if floor(v / 4) % 2 == 1 then return "@i18n(widgets.dashboard.novafly.horizon)@" end
    if floor(v / 2) % 2 == 1 then return "@i18n(widgets.dashboard.novafly.angle)@" end
    return "ACRO"
end

local function number(v, pattern)
    if v == nil then return "--", style.FIELD_DIM end
    if pattern == nil then v = floor(v + 0.5) end   -- a whole number: %d takes no fraction
    local z = string.format(pattern or "%d", v)
    if type(v) == "number" and v <= 0 and z:find("^%-[0.]*$") then z = z:sub(2) end   -- what rounds to zero stands without a minus ("-0.0" at a sink of exactly 0)
    return z, H.colors.green
end

local function paint()
    if style == nil then return end
    style.windowRefresh()
    style.bandDrawn, style.footDrawn = false, false
    S.background()
    S.lines(true)
    local s = H.state() or {}
    local link = H.linkColor(s)   -- white on a good link, yellow and red by the cockpit's limits; good is green here like the numbers
    if link == H.colors.white then link = H.colors.green end
    reception(BARS.rssi, steps(s.rssi, RSSI_STEPS), link)
    reception(BARS.vfr, steps(s.vfr, VFR_STEPS), link)
    local mode = modeWord(s.flightMode)
    S.rowLeft(MODE.x, MODE.word, {{"@i18n(widgets.dashboard.novafly.flight_mode)@", style.WHITE, FONT_XS}})
    S.rowLeft(MODE.x, MODE.value, {{mode or "--", mode and H.colors.green or style.FIELD_DIM, FONT_S}})
    local z, f
    style.labelCenteredFit(240, HEAD_Y, s.craft or "", style.WHITE, FONT_L, 280)
    local photo = loadPhoto()
    local fx, fy, fw, fh = photoBox()
    if photo ~= nil and pcall(lcd.drawBitmap, fx, fy, photo, fw, fh) then photoFrame() end

    local a = BATTERY
    S.chip(a.x, a.y, a.w, a.h, "right")
    local cx = a.x + a.w / 2
    local cellCol = H.cellColor(s.cellF or s.cell)   -- the battery colour by the cell, like the cockpit
    style.labelCentered(cx, a.y + 17, "@i18n(widgets.dashboard.novafly.battery)@", style.WHITE, FONT_S)
    z, f = number(s.fuel ~= nil and floor(s.fuel + 0.5) or nil)
    S.row(cx, a.y + 45, {{z, s.fuel ~= nil and cellCol or f, FONT_XL}, {"%", style.WHITE, FONT_S}})
    local rf = H.rf()
    local bc = rf and rf.session and rf.session.batteryConfig
    local chosen = type(bc) == "table" and type(bc.profiles) == "table" and tonumber(bc.profiles[rf.session.activeBatteryType]) or nil   -- rfsuite 2.3.x: the capacity of the chosen battery (session.activeBatteryType, 0 to 5), as the suite itself computes it
    if type(bc) ~= "table" then bc = battery end
    local cap = (chosen ~= nil and chosen > 0) and chosen or (type(bc) == "table" and tonumber(bc.batteryCapacity) or nil)   -- without a choice or without a capacity in the profile the one from connecting
    if cap ~= nil and cap <= 0 then cap = nil end
    local cells = s.cells or (type(bc) == "table" and tonumber(bc.batteryCellCount)) or nil
    if cells ~= nil and cells <= 0 then cells = nil end
    local segs = {}
    local function seg(text, color) segs[#segs + 1] = {text, color, FONT_XS} end
    z, f = number(s.pack, "%.1f") seg(z, s.pack ~= nil and cellCol or f) seg("V  ", style.WHITE)
    seg((cells ~= nil and tostring(floor(cells)) or "--") .. "S  ", cells ~= nil and style.WHITE or style.FIELD_DIM)
    z, f = number(cap) seg(z, f) seg("mAh", style.WHITE)
    S.row(cx, a.y + 74, segs)
    local lx, rx = a.x + a.w / 4, a.x + a.w * 3 / 4
    style.labelCentered(lx, a.y + 108, "@i18n(widgets.dashboard.novafly.cell)@", style.WHITE, FONT_XS)
    z, f = number(s.cell, "%.2f")
    S.row(lx, a.y + 133, {{z, s.cell ~= nil and cellCol or f, FONT_L}, {"V", style.WHITE, FONT_S}})
    style.labelCentered(rx, a.y + 108, "@i18n(widgets.dashboard.novafly.consumption)@", style.WHITE, FONT_XS)
    z, f = number(s.used ~= nil and floor(s.used + 0.5) or nil)
    S.row(rx, a.y + 133, {{z, f, FONT_L}, {"mAh", style.WHITE, FONT_S}})

    local fl = H.flight() or {}   -- the last flight here: altitude and climb/sink from the altitude sensor, the flight time armed with a turning rotor;
    local sz = type(H.session) == "function" and H.session() or {}   -- without a flight here the maximum values since connecting and the last flight time as the suite keeps it
    local altUnit, rateUnit = s.altFt and "ft" or "m", s.altFt and "ft/s" or "m/s"
    local sec = fl.time
    if sec == nil and type(H.lastFlightTime) == "function" then sec = H.lastFlightTime() end
    local time = sec ~= nil and string.format("%d:%02d", floor(sec / 60), floor(sec % 60)) or nil
    local altMax, climb, sink = fl.alt or sz.altMax, fl.climb or sz.climbMax, fl.sink or sz.sinkMax
    local chips = {{"@i18n(widgets.dashboard.novafly.alt_max)@", altMax, "%.0f", altUnit}, {"@i18n(widgets.dashboard.novafly.climb_max)@", climb, "%.1f", rateUnit},
                   {"@i18n(widgets.dashboard.novafly.sink_max)@", sink ~= nil and -sink or nil, "%.1f", rateUnit}, {"@i18n(widgets.dashboard.novafly.flight_time)@", time, "%s", "min"}}
    for i = 1, 4 do
        local x = FOOT.x + (i - 1) * (FOOT.w + FOOT.gap)
        local w = (i == 4) and (480 - x) or FOOT.w
        S.chip(x, FOOT.y, w, FOOT.h, i == 4 and "right" or nil)
        local c = chips[i]
        style.labelCentered(x + w / 2, FOOT.y + 13, c[1], style.WHITE, FONT_XS)
        z, f = number(c[2], c[3])
        S.row(x + w / 2, FOOT.y + 33, {{z, f, FONT_STD}, {c[4], style.WHITE, FONT_XS}})
    end
end

local function event()   -- there is nothing to tap on the left page; every touch still belongs to the theme
    return true
end

local function fcNow()   -- the connected heli (the suite's mcu_id); nil without a link
    local rf = H.rf()
    local se = rf and rf.session
    if type(se) ~= "table" or se.isConnected ~= true then return nil end
    return se.mcu_id
end

local function tick()   -- every wakeup (cockpit.lua): without session.batteryConfig BATTERY_CONFIG once per heli, one request at a time, after a failed one BATTERY_PAUSE
    local rf = H.rf()
    if S == nil or rf == nil or type(rf.session) ~= "table" or type(rf.session.batteryConfig) == "table" then return end
    local fc = fcNow()
    if batteryFor ~= fc then battery, batteryFor = nil, nil end   -- another heli or none: the values of the previous one no longer apply
    if fc == nil or battery ~= nil or request.fc ~= nil or os.clock() < request.from then return end
    request.fc = fc
    local sent = S.busRead("lib/msp_battery_config.lua", function(d)
        request.fc = nil
        if d == nil then request.from = os.clock() + BATTERY_PAUSE
        elseif fcNow() == fc then battery, batteryFor = d, fc end   -- a late answer for the previous heli does not count
    end)
    if not sent then request.fc, request.from = nil, os.clock() + BATTERY_PAUSE end
end

local function open()
    if style == nil then
        local chunk, g = H.loadAsset(loadfile, "style.lua")
        if not chunk then return false, "style.lua does not load: " .. tostring(g) end
        local ok, s = pcall(chunk, {nova = nova, loadAsset = H.loadAsset})
        if not ok or type(s) ~= "table" then return false, "style.lua failed: " .. tostring(s) end
        style = s
        chunk, g = H.loadAsset(loadfile, "page.lua")
        if not chunk then style = nil return false, "page.lua does not load: " .. tostring(g) end
        ok, s = pcall(chunk, {H = H, style = style})
        if not ok or type(s) ~= "table" then style = nil return false, "page.lua failed: " .. tostring(s) end
        S = s
    end
    tick()   -- the first request right on opening
    return true
end

local function leave()
    style, S = nil, nil
end

return {paint = paint, event = event, open = open, leave = leave, tick = tick, back = NO_ZONE, page = true}
