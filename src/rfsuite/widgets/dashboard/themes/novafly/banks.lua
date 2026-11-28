-- BANKS: the page right of the cockpit on its background (page.lua S.background), the cockpit lines run in from the left
-- and fade out. At the top the drive of the bank (governor, target headspeed, spool-up, gain), below it four chips with the
-- rate per axis and three chips with the gains per axis, the chips from the cockpit lines with r 4 corners, the first
-- of each row open to the left edge. On the right a standing headspeed bar: the measured headspeed against the target headspeed of the
-- bank, green up to the target, yellow just above, red too high, with the mark of the highest headspeed of this bank (peak marker).
local H = ...
local floor = math.floor

local LEFT, RIGHT = 10, 376            -- the alignment of the chips: both rows start and end alike
local RATE_CHIP = {y = 66, h = 58, n = 4, gap = 6}
local GAIN_CHIP = {y = 136, h = 104, n = 3, gap = 6}
local BAR = {x = 440, w = 24, top = 62, bottom = 300, rim = 4}   -- the frame of the bar; the column stays rim inside
local ZONES_X, ZONES_W = 467, 3          -- the strip of the zones right of the bar
local SCALE, YELLOW_FROM = 1.25, 1.08        -- the bar reaches 125 % of the target headspeed; yellow from the target, red from 108 %
local ACTUAL_X, ACTUAL_W = 386, 94             -- the measured headspeed at the top over the bar
local BANK_RX, BANK_Y, BANK_STEP = 434, 150, 30   -- BANK 1 2 3 right-aligned beside the bar
local FOOT_Y = 277
local NO_ZONE = {x = 0, y = 0, w = 0, h = 0}   -- there is no BACK on a page: back is the swipe
local RATE_TYPES = {[0] = "NONE", "BETAFLIGHT", "RACEFLIGHT", "KISS", "ACTUAL", "QUICK", "ROTORFLIGHT"}
local GOV_MODES = {[0] = "OFF", "LIMIT", "DIRECT", "ELECTRIC", "NITRO"}   -- the firmware's gov_mode; at 3 and 4 the FC governs the headspeed
local GOV_FROM = 3
local govName, govFor = nil, nil   -- the name of the mode, once per GOVERNOR_CONFIG read
local govSpoolup = nil                  -- gov_spoolup_time in tenths of a second, with one decimal like the suite (lib/msp_governor_config.lua: decimals 1)
local DEG_S, DEG = "\194\176/s", "\194\176"
local RATE_RULES = {   -- rcRates per rate type: {times, divisor, decimals} for axes 1-3 and collective, shown raw * times / divisor
    [0] = {{1, 1, 0}, {1, 1, 0}}, {{1, 100, 2}, {1, 100, 2}}, {{10, 1, 0}, {1, 4, 1}, DEG_S}, {{1, 100, 2}, {1, 100, 2}},   -- NONE, BETAFLIGHT, RACEFLIGHT, KISS
    {{10, 1, 0}, {1, 4, 1}}, {{1, 100, 2}, {1, 100, 2}}, {{5, 1, 0}, {5, 40, 2}, DEG_S}}   -- ACTUAL, QUICK, ROTORFLIGHT; with the unit of the RC RATE column, the collective there is an angle (firmware: 480 degrees/s are 12 degrees)
local SHIFT, FORMATS = {[0] = 1, 10, 100}, {"%.1f", "%.2f"}
local RATE_AXES = {"@i18n(widgets.dashboard.novafly.roll)@", "@i18n(widgets.dashboard.novafly.pitch)@", "@i18n(widgets.dashboard.novafly.tail)@", "@i18n(widgets.dashboard.novafly.collective)@"}
local rateNumber, rateUnit, ratesFor = {}, {}, nil   -- the four chips, computed once per RC_TUNING read, not per paint
local NONE = {}
local ONE, TWO = {{"", 0, 0}}, {{"", 0, 0}, {"", 0, 0}}   -- the rows of a number without and with its unit, built once and filled before each use: no new tables per paint
local COLUMNS = {"@i18n(widgets.dashboard.novafly.governor)@", "@i18n(widgets.dashboard.novafly.headspeed)@", "@i18n(widgets.dashboard.novafly.spoolup)@", "GAIN"}   -- the head band: governor, target headspeed, spool-up, gain
local columnValue = {}
local GAIN_AXES = {{"@i18n(widgets.dashboard.novafly.roll)@", "roll"}, {"@i18n(widgets.dashboard.novafly.pitch)@", "pitch"}, {"@i18n(widgets.dashboard.novafly.tail)@", "yaw"}}

local RPM_UNIT = "@i18n(widgets.dashboard.novafly.rpm_unit)@"   -- the unit of the headspeed: German U/min, in every other language rpm like the cockpit
local COLUMN_UNITS = {false, RPM_UNIT, "s", false}   -- the units of the head band
local style, S = nil, nil
local nova = {dirty = false, armState = "unknown", flightLog = {}, highDetail = true, italic = nil}
local values = {pid = nil, rc = nil, gov = nil, govProfile = nil, failed = nil}
local readFor = nil                  -- {bank, rate} for which the values were read; a change reads again
local running = false
local generation = 0                     -- the number of the running read chain; an answer with another number (page closed, new chain) is dropped
local TIMEOUT, PAUSE = 14, 3               -- a request without an answer is lost after 14 s; after an error the tick reads again after 3 s
local askedAt, linkNow = 0, 1         -- when the request on its way went out, and which message
local chainFailed, retryAt = false, nil -- a message of this chain did not come; from retryAt (os.clock) the tick reads the same bank and rate again

local CODEC = {PID_TUNING = "lib/msp_pid_tuning.lua", RC_TUNING = "lib/msp_rc_tuning.lua",
               GOVERNOR_CONFIG = "lib/msp_governor_config.lua", GOVERNOR_PROFILE = "lib/msp_governor_profile.lua"}
local function read(name, done)   -- one message over the suite's bus with its codec (the PID fields named by axis: roll_p, pitch_i ...)
    return S.busRead(CODEC[name], done)
end

local CHAIN = {{"PID_TUNING", "pid", "PID"}, {"RC_TUNING", "rc", "@i18n(widgets.dashboard.novafly.rates)@"}, {"GOVERNOR_CONFIG", "gov", "@i18n(widgets.dashboard.novafly.governor)@"}, {"GOVERNOR_PROFILE", "govProfile", "@i18n(widgets.dashboard.novafly.governor)@"}}
local function chain(g, i)   -- reads the four messages one after another; an error stands in the foot and the chain goes on, cleared and armed end it
    local link = CHAIN[i]
    if link == nil then   -- done: without an error the error line goes, with an error the tick reads again after the pause
        running = false
        if chainFailed then retryAt = os.clock() + PAUSE else values.failed, retryAt = nil, nil end
        return
    end
    if (H.state() or NONE).armed == true then running, retryAt = false, os.clock() return end   -- armed meanwhile: the rest is read on the ground
    askedAt, linkNow = os.clock(), i
    if not read(link[1], function(w, reason)
        if g ~= generation then return end
        if reason == "cleared" then running, retryAt = false, os.clock() return end   -- the suite emptied its queue (arming, link lost): the chain ends, the tick reads again on the ground
        if w ~= nil then values[link[2]] = w
        else
            chainFailed = true
            values.failed = link[3]
        end
        chain(g, i + 1)
    end) then
        values.failed, running, retryAt = "MSP", false, os.clock() + PAUSE
    end
end

local function start(s, keep)   -- keep: the same bank and rate once more, what is read already stays
    if running then return end
    if not keep then
        values.pid, values.rc, values.gov, values.govProfile, values.failed = nil, nil, nil, nil, nil
        readFor = {bank = s.bank and floor(s.bank) or nil, rate = s.rate and floor(s.rate) or nil}
    end
    if s.armed == true then retryAt = os.clock() return end   -- armed: the suite keeps configuration traffic off the link (tasks/session.lua), so the page asks nothing until the ground
    running, generation, chainFailed, retryAt = true, generation + 1, false, nil
    chain(generation, 1)
end

local function tick()   -- every wakeup: a change of bank or rate on the FC reads the values again; a lost request and an error are read again
    if style == nil or readFor == nil then return end
    local now = os.clock()
    if running then   -- lost: the timeout is over
        if now - askedAt < TIMEOUT then return end
        generation, running = generation + 1, false
        values.failed, retryAt = CHAIN[linkNow][3], now + PAUSE
    end
    local s = H.state() or {}
    local bank, rate = s.bank and floor(s.bank) or nil, s.rate and floor(s.rate) or nil
    if bank ~= readFor.bank or rate ~= readFor.rate then start(s)
    elseif retryAt ~= nil and now >= retryAt then start(s, true) end
end

local function number(v)
    if v == nil then return "--", style.FIELD_DIM end
    return tostring(floor(v + 0.5)), H.colors.green
end

local function numberRow(cx, cy, z, font, color, unit)   -- the number with the unit small in the same row, centred together
    local segs = unit ~= nil and TWO or ONE
    local a = segs[1]
    a[1], a[2], a[3] = z, color, font
    if unit ~= nil then
        local b = segs[2]
        b[1], b[2], b[3] = unit, style.WHITE, FONT_XS
    end
    S.row(cx, cy, segs)
end

local function chipPlace(c, i)   -- x and width of the i-th chip of a row: all in the same alignment LEFT..RIGHT
    local w = floor((RIGHT - LEFT - (c.n - 1) * c.gap) / c.n)
    return LEFT + (i - 1) * (w + c.gap), w
end

local function pair(x, y, letter, v)
    local z, color = number(v)
    style.label(x, y - 7, letter, style.WHITE, FONT_S)
    style.label(x + 16, y - 8, z, color, FONT_STD)
end

local function governorCompute(g)   -- the name of the mode and the spool-up time of a GOVERNOR_CONFIG
    local m = g.gov_mode and floor(g.gov_mode)
    govName, govFor = m and GOV_MODES[m] or nil, values.gov
    govSpoolup = g.gov_spoolup_time and string.format("%.1f", g.gov_spoolup_time / 10) or nil
end

local function drive()   -- the head band: governor, target headspeed, spool-up, gain in the alignment of the four chips
    local g, p = values.gov or NONE, values.govProfile or NONE
    if values.gov ~= govFor then governorCompute(g) end
    columnValue[1], columnValue[2], columnValue[3], columnValue[4] = govName, p.governor_headspeed, govSpoolup, p.governor_gain
    for i = 1, 4 do
        local x, w = chipPlace(RATE_CHIP, i)
        if i == 1 then x, w = 0, x + w end
        local v = columnValue[i]
        style.labelCentered(x + w / 2, 18, COLUMNS[i], style.WHITE, FONT_XS)
        local z, color
        if i == 1 or i == 3 then z, color = v or "--", v and H.colors.green or style.FIELD_DIM   -- mode and spool-up are already text
        else z, color = number(v) end
        numberRow(x + w / 2, 35, z, FONT_STD, color, v ~= nil and COLUMN_UNITS[i] or nil)
    end
end

local function yOf(value, full, height)   -- the height of a value on the bar: 0 at the bottom, full at the top
    local share = value / full
    if share < 0 then share = 0 elseif share > 1 then share = 1 end
    return BAR.bottom - height * share
end

local function bar(R, s, active)   -- the measured headspeed as a column against the bank's target; without a target (LIMIT, DIRECT, PASSTHROUGH, not read) against the end of the cockpit arc
    local b = BAR
    S.chip(b.x, b.top, b.w, b.bottom - b.top)
    local g, p = values.gov or NONE, values.govProfile or NONE
    local governed = g.gov_mode ~= nil and floor(g.gov_mode) >= GOV_FROM
    local target = governed and p.governor_headspeed or nil
    if target ~= nil and target <= 0 then target = nil end
    local full = target and (target * SCALE) or H.rpmFull()
    local height = b.bottom - b.top
    if target and R then   -- the zones right of the bar and the target mark across it
        local yTarget, yYellow = yOf(target, full, height), yOf(target * YELLOW_FROM, full, height)
        S.fillRect(ZONES_X, yTarget, ZONES_W, b.bottom - yTarget, R.GREEN)
        S.fillRect(ZONES_X, yYellow, ZONES_W, yTarget - yYellow, R.YELLOW)
        S.fillRect(ZONES_X, b.top, ZONES_W, yYellow - b.top, R.RED)
        S.fillRect(b.x - 4, floor(yTarget), b.w + 8, 1, style.WHITE)
        style.labelRight(BANK_RX, yTarget - 6, tostring(floor(target + 0.5)), style.WHITE, FONT_XS)
    end
    local rpm = s.rpm
    if rpm ~= nil and rpm > 0 and R then
        local color = R.GREEN
        if target and rpm > target * YELLOW_FROM then color = R.RED elseif target and rpm > target then color = R.YELLOW end
        local yTop, yBottom = yOf(rpm, full, height), b.bottom - b.rim
        if yTop < b.top + b.rim then yTop = b.top + b.rim end
        if yBottom > yTop then S.fillRect(b.x + b.rim, yTop, b.w - 2 * b.rim, yBottom - yTop, color) end
    end
    local pk = active and H.peaks[active]
    if pk and pk.max and pk.max > 0 then   -- the mark of the highest headspeed of this bank, like the peak marker
        local y = yOf(pk.max, full, height)
        if y < b.top + b.rim then y = b.top + b.rim end
        S.fillRect(b.x + 2, floor(y) - 1, b.w - 4, 2, style.WHITE)
    end
    style.labelCentered(ACTUAL_X + ACTUAL_W / 2, 18, "@i18n(widgets.dashboard.novafly.actual)@", style.WHITE, FONT_XS)
    local z, color = number(rpm)
    numberRow(ACTUAL_X + ACTUAL_W / 2, 35, z, FONT_STD, color, rpm ~= nil and RPM_UNIT or nil)
    for i = 1, 3 do
        style.labelRight(BANK_RX, BANK_Y + (i - 1) * BANK_STEP, "BANK " .. i, active == i and style.WHITE or style.FIELD_DIM, FONT_S)
    end
end

local function ratesCompute(r)   -- the number per axis by the rule of the rate type, with a point like the other numbers of the theme
    local rule = r.rates_type and RATE_RULES[floor(r.rates_type)]
    for i = 1, 4 do
        local raw, m = r["rcRates_" .. i], rule and rule[i < 4 and 1 or 2]
        rateNumber[i], rateUnit[i] = nil, nil
        if raw ~= nil and m ~= nil then
            local shift = SHIFT[m[3]]
            local whole = floor(raw / m[2] * shift * m[1] + 0.5)
            rateNumber[i] = m[3] > 0 and string.format(FORMATS[m[3]], whole / shift) or tostring(whole)
            rateUnit[i] = rule[3] and (i < 4 and rule[3] or DEG) or nil
        end
    end
    ratesFor = values.rc
end

local function paint()
    if style == nil then return end
    style.windowRefresh()
    style.bandDrawn, style.footDrawn = false, false
    S.background()
    S.lines(false)
    local R = H.frame()
    local s = H.state() or NONE
    local active = s.bank and floor(s.bank) or nil
    local rate = s.rate and floor(s.rate) or nil
    drive()

    local r = values.rc or NONE
    local rtype = r.rates_type and RATE_TYPES[floor(r.rates_type)] or nil
    if values.rc ~= ratesFor then ratesCompute(r) end
    for i = 1, 4 do   -- per axis the number as the suite shows it: rotation rate, factor or for the collective the angle
        local x, w = chipPlace(RATE_CHIP, i)
        local y, h = RATE_CHIP.y, RATE_CHIP.h
        S.chip(x, y, w, h, i == 1 and "left" or nil)
        if i == 1 then x, w = 0, x + w end
        style.labelCentered(x + w / 2, y + 15, RATE_AXES[i], style.WHITE, FONT_S)
        local z = rateNumber[i]
        numberRow(x + w / 2, y + 40, z or "--", FONT_L, z and H.colors.green or style.FIELD_DIM, z and rateUnit[i] or nil)
    end

    local p = values.pid or NONE
    for i = 1, 3 do   -- gains per axis: P I D F B O
        local x, w = chipPlace(GAIN_CHIP, i)
        local y, h = GAIN_CHIP.y, GAIN_CHIP.h
        S.chip(x, y, w, h, i == 1 and "left" or nil)
        if i == 1 then x, w = 0, x + w end
        local a = GAIN_AXES[i]
        style.labelCentered(x + w / 2, y + 13, a[1], style.WHITE, FONT_S)
        pair(x + 10, y + 36, "P", p[a[2] .. "_p"])
        pair(x + 62, y + 36, "I", p[a[2] .. "_i"])
        pair(x + 10, y + 58, "D", p[a[2] .. "_d"])
        pair(x + 62, y + 58, "F", p[a[2] .. "_f"])
        pair(x + 10, y + 80, "B", p[a[2] .. "_b"])
        if a[2] ~= "yaw" then pair(x + 62, y + 80, "O", p[a[2] .. "_o"]) end
    end

    bar(R, s, active)
    local foot = "RATE " .. (rate and tostring(rate) or "?")
    if values.failed ~= nil then   -- the red message needs the row: the rate type stays away while it stands
        style.label(140, FOOT_Y, foot, style.WHITE, FONT_S)
        style.label(290, FOOT_Y, "MSP " .. values.failed, style.RED, FONT_S)
    else
        style.label(140, FOOT_Y, foot .. "   " .. (rtype or ""), style.WHITE, FONT_S)
    end
end

local function event()   -- there is nothing to tap on the banks page (cockpit.lua decides what goes to the dashboard)
    return true
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
    start(H.state() or {})
    return true
end

local function leave()   -- an answer still on its way is dropped: the closed page asks nothing any more
    generation, running = generation + 1, false
    style, S = nil, nil
end

return {paint = paint, event = event, open = open, leave = leave, tick = tick, back = NO_ZONE, page = true}
