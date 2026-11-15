-- NovaFly-Cockpit als rfsuite-Theme: Bild je Farbe, Werte aus der rfsuite-Telemetrie, Kursivschrift ueber Masken, Langdruck auf den RF007-Kopf schaltet am Boden die Farbe
local BASIS = ...
local BASIS_ALT = tostring(BASIS):gsub("^SCRIPTS:/", "/scripts/")
local rf = package.loaded.rfsuite
if rf == nil and type(package.loaded["rfsuite.lib.require"]) == "function" then
    local ok, r = pcall(package.loaded["rfsuite.lib.require"], "widgets/dashboard/context.lua")
    if ok then rf = r end
end
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local BILDER = {"tacho_base.png", "tacho_magenta.png", "tacho_gruen.png", "tacho_orange.png", "tacho_gelb.png",
                "tacho_carbon.png", "tacho_carbon_gruen.png", "tacho_carbon_violett.png", "tacho_carbon_rot.png"}

local RGB = lcd.RGB
local C_WHITE, C_DIM, C_GRAY, C_RED = RGB(245, 248, 252), RGB(120, 132, 145), RGB(52, 56, 64), RGB(225, 40, 40)
local C_GREEN, C_LGREEN, C_YELLOW = RGB(40, 180, 55), RGB(90, 255, 70), RGB(240, 210, 30)
local C_ORANGE, C_LRED, C_BLACK = RGB(255, 130, 20), RGB(255, 80, 80), RGB(8, 8, 10)
local C_RING, C_NADEL_LICHT, C_NADEL_SCHATTEN = RGB(0, 152, 224), RGB(255, 255, 255), RGB(160, 176, 200)
local SETC = {g = C_LGREEN, y = C_YELLOW, o = C_ORANGE, r = C_LRED, w = C_WHITE}

local F_TINY = FONT_XS or FONT_S or FONT_STD
local F_SM = FONT_S or FONT_STD
local F_STD_T = FONT_STD or FONT_S
local F_MID = FONT_L or FONT_STD
local F_BIG = FONT_XL or FONT_L or FONT_STD
local F_HUGE = FONT_XXL or FONT_XL or FONT_L or FONT_STD
local TREPPE = {F_HUGE, F_BIG, F_MID, F_STD_T, F_SM}

local NACH_STUFE = {}
for _, p in ipairs({{"FONT_XS", "s"}, {"FONT_S", "s"}, {"FONT_STD", "std"}, {"FONT_L", "l"}, {"FONT_XL", "xl"}, {"FONT_XXL", "xxl"}}) do
    local wert = rawget(_G, p[1])
    if wert ~= nil and NACH_STUFE[wert] == nil then NACH_STUFE[wert] = p[2] end
end

local T = {timer = "FLUGTIMER", unbekannt = "ARM ?", link = "NO LINK", scharf = "Heli ist scharf. Setup nur am Boden."}

local VFR_YEL, VFR_RED = 90, 80
local GAUGE = {cx = 239.5, cy = 171.5, d0 = 180, d1 = 0, rTip = 88, rBase = 60}
local BEZUG_OHNE_FLUG = 2000
local LANG, DRIFT, SPERRE_SEK, FARBE_LESEN_SEK, MASKEN_JE_TAKT, MAX_WORTE, KALT_JE_BILD = 0.6, 12, 2.5, 1.0, 8, 160, 4
local BEC_FUELLBYTE, BEC_MIN, BEC_MAX = 25.5, 3.0, 13.0
local RK_OBEN, RK_WORT_WERT, RK_LUECKE = 73, 25, 28
local RICHTUNG = {x = 147, y = 27, r = 16, rand = 1, spitze = 12, fuss = 10, ecke = 145}
local CPU_NAMEN = {"RT Load", "CPU Load", "System Load", "MCU Load"}
-- rfsuite 2.3.1 reicht Y.Winkel und Hoehe nicht mehr durch getSensor; dann liest das Theme die Ethos-Sensoren selbst:
-- S.Port, CRSF, rfsuite-Simulator (rfsuite 2.3.0 sources/sport.lua:62,68, crsf.lua:60,66, sim.lua:42,48)
local YAW_QUELLEN = {0x5210, 0x1103, 0x5022}
local ALT_QUELLEN = {0x0100, 0x10B2, 0x5016}

local function rkWort(block) return RK_OBEN + block * (RK_WORT_WERT + RK_LUECKE) end
local function rkWert(block) return rkWort(block) + RK_WORT_WERT end

local U = {
    arm = {x = 14, y = 14, w = 94, h = 28, f = F_MID, tief = 1},
    rssi = {x = 413, y = 14, f = F_SM},
    vfr = {x = 413, y = 28, f = F_TINY},
    timer = {x = 64, y = 82, f = F_BIG},
    timer2 = {x = 64, y = 108, f = F_STD_T},
    timer3 = {x = 64, y = 130, f = F_STD_T},
    timer4 = {x = 64, y = 152, f = F_STD_T},
    bank = {x = 40, y = 208, f = F_SM},
    rate = {x = 86, y = 208, f = F_SM},
    rpm = {x = 241, y = 126, f = F_BIG},
    bec = {x = 417, y = rkWert(0) - 14, f = F_BIG},
    tx = {x = 417, y = rkWert(1) - 14, f = F_BIG},
    amp = {x = 417, y = rkWert(2) - 14, f = F_BIG},
    cpu = {x = 331, y = 63, f = F_SM},
    pack = {x = 214, y = 273, f = F_HUGE},
    battpct = {x = 307, y = 273, f = F_HUGE},
    modelname = {x = 241, y = 218, f = F_MID},
    batt = {x = 140, y = 294, bw = 12, bh = 5, gap = 1, n = 5},
    temp = {x = 422, y = 282, f = F_BIG},
    mcutemp = {x = 187, y = 51, f = F_SM},
    alt = {x = 203, y = 186, w = 74, h = 22, f = F_SM},
    labels = {{40, 188, "BANK", F_TINY}, {86, 188, "RATE", F_TINY}, {417, rkWort(0) - 6, "BEC"},
              {417, rkWort(1) - 6, "TX"}, {417, rkWort(2) - 6, "ESC", F_TINY}, {421, 264, "ESC", F_TINY},
              {241, 170, "rpm", F_TINY}, {143, 65, "MCU", F_TINY}},
}
local ZONEN = {header = {x = 176, y = 0, w = 184, h = 48}, richtung = {x = 127, y = 7, w = 40, h = 40}}

-- Die Winkeltabelle und die Kursivmasse kommen nicht beim Laden, sondern in zwei Schritten beim ersten Wakeup und
-- beim ersten Malen: Ethos bricht einen Aufruf ab 20 000 Befehlen ab, und der erste Wakeup traegt schon das Laden
-- dieser Datei. Bis beide Schritte durch sind, malt das Cockpit nur den Hintergrund.
local SINT, COST = {}, {}
local MASSE, ZIFFER_VORSCHUB = {}, {}
local tabellenStufe = 0

local function tabellenSchritt()
    if tabellenStufe == 0 then
        for d = -60, 240 do local r = d * math.pi / 180 SINT[d] = math.sin(r) COST[d] = math.cos(r) end
        tabellenStufe = 1
    elseif tabellenStufe == 1 then
        local chunk = loadfile(BASIS .. "kursiv_masse.lua")
        local ok, tab = false, nil
        if chunk then ok, tab = pcall(chunk) end
        if ok and type(tab) == "table" then MASSE = tab end
        -- Tabellenziffern: jede Ziffer bekommt den Vorschub der breitesten Ziffer ihrer Stufe (die 1 hat sonst den
        -- halben), die Maske sitzt mittig in der Zelle - so springt ein mittig gesetzter Wert nicht, wenn eine Ziffer
        -- wechselt
        for stufe, t in pairs(MASSE) do
            if type(t) == "table" and stufe ~= "hoehe" then
                local breit = 0
                for code = 48, 57 do
                    local e = t[code]
                    if e and e[5] > breit then breit = e[5] end
                end
                ZIFFER_VORSCHUB[stufe] = breit
            end
        end
        tabellenStufe = 2
    end
end

local function zelle(stufe, code, e)   -- Vorschub und Versatz eines Zeichens in seiner Zelle
    if code >= 48 and code <= 57 then
        local adv = ZIFFER_VORSCHUB[stufe] or e[5]
        return adv, floor((adv - e[5]) / 2)
    end
    return e[5], 0
end

local ox, oy, fx, fy, kursivAn = 0, 0, 1, 1, false
local function sx(v) return floor(v * fx + 0.5) end
local function sy(v) return floor(v * fy + 0.5) end
local function X(v) return ox + sx(v) end
local function Y(v) return oy + sy(v) end

local masken, wunsch, wunschListe = {}, {}, {}
local worte, worteZahl = {}, 0          -- Beschriftungen: aendern sich kaum
local zahlen, zahlenZahl = {}, 0        -- Zahlen: kommen und gehen mit jedem Wert; wird es voll, bleiben nur die des laufenden Bildes
local MAX_ZAHLEN = 96
local bildZaehler = 0                    -- zaehlt die Bilder: welche Zahl gerade auf dem Schirm steht
local function istZahl(text) return text:find("%d") ~= nil and text:find("%a") == nil end

local function maske(stufe, code)
    local k = stufe .. "/" .. code
    local m = masken[k]
    if m ~= nil then return m or nil end
    if not wunsch[k] then
        wunsch[k] = true
        wunschListe[#wunschListe + 1] = {stufe, code, k}
    end
    return nil
end

local function laden(fn, datei)
    local ok, x, grund = pcall(fn, BASIS .. datei)
    if ok and x then return x end
    local erster = ok and grund or x
    ok, x, grund = pcall(fn, BASIS_ALT .. datei)
    if ok and x then return x end
    return nil, tostring(erster or (ok and grund) or x)
end

local function merken(text)   -- eine Zeile fuer die Fehlersuche auf die Karte; geht das Schreiben nicht, bleibt es still
    local ok, f = pcall(io.open, "LOGS:/novafly_theme.log", "a")
    if not ok or not f then return end
    pcall(f.write, f, string.format("%.1f %s\n", os.clock(), tostring(text)))
    pcall(f.close, f)
end

local SPRACHE = nil   -- die Texte in der Sprache des Senders, dieselben wie in NovaFly; laedt die Datei nicht, bleibt das Cockpit deutsch
do
    local chunk, grund = laden(loadfile, "i18n_teile.lua")
    local ok, tab = false, nil
    if chunk then ok, tab = pcall(chunk, {laden = laden}) end
    if ok and type(tab) == "table" then
        SPRACHE = tab
        T = {timer = tab.wort(T.timer), unbekannt = tab.b_arm_unbekannt, link = tab.f_kein_heli, scharf = tab.f_setup_scharf}
    else
        merken("i18n_teile.lua laedt nicht: " .. tostring(grund or tab))
    end
end

local function maskenLaden(n)
    if type(lcd.loadMask) ~= "function" then return end
    for _ = 1, n do
        local w = table.remove(wunschListe, 1)
        if w == nil then return end
        masken[w[3]] = laden(lcd.loadMask, "gfx/kursiv/" .. w[1] .. "/" .. w[2] .. ".png") or false
        wunsch[w[3]] = nil
    end
end

local function codes(text)
    if not text:find("[\128-\255]") then return {text:byte(1, -1)} end
    local aus, i = {}, 1
    while i <= #text do
        local b = text:byte(i)
        if b == 194 and i < #text then
            aus[#aus + 1] = text:byte(i + 1)
            i = i + 2
        elseif b >= 192 then
            return nil
        else
            aus[#aus + 1] = b
            i = i + 1
        end
    end
    return aus
end

local function masze(text, stufe)
    local tab = MASSE[stufe]
    if tab == nil then return nil end
    local cs = codes(text)
    if cs == nil then return nil end
    local marke, links, rechts = 0, nil, nil
    for i = 1, #cs do
        local e = tab[cs[i]]
        if e == nil then return nil end
        local adv, versatz = zelle(stufe, cs[i], e)
        if cs[i] >= 48 and cs[i] <= 57 then   -- eine Ziffer zaehlt mit ihrer ganzen Zelle, sonst wandert die Mitte mit der Tinte der 1
            if links == nil or marke < links then links = marke end
            if rechts == nil or marke + adv > rechts then rechts = marke + adv end
        elseif e[3] > 0 then
            local l, r = marke + versatz + e[1], marke + versatz + e[1] + e[3]
            if links == nil or l < links then links = l end
            if rechts == nil or r > rechts then rechts = r end
        end
        marke = marke + adv
    end
    if links == nil then return marke, MASSE.hoehe[stufe], cs, 0 end
    return rechts - links, MASSE.hoehe[stufe], cs, -links
end

local kaltRest = 0   -- kalte Woerter je Bild: das Bild rechnet hoechstens KALT_JE_BILD neue Woerter, der Rest malt in Ethos-Schrift und kommt im naechsten Bild

local function zuegeBauen(w)   -- die Masken zu einem gemessenen Wort; false, solange eine noch nicht geladen ist
    local tab, cs, zuege, px, ganz = MASSE[w.stufe], w.cs, {}, w.v, true
    for i = 1, #cs do
        local e = tab[cs[i]]
        local adv, versatz = zelle(w.stufe, cs[i], e)
        if e[3] > 0 then
            local m = maske(w.stufe, cs[i])
            if m == nil then ganz = false else zuege[#zuege + 1] = {px + versatz + e[1], e[2], m} end
        end
        px = px + adv
    end
    if ganz then w.zuege, w.cs, w.v = zuege, nil, nil end
    return ganz
end

local function wort(text, font)
    if not kursivAn or type(lcd.drawMask) ~= "function" then return nil end
    local stufe = NACH_STUFE[font]
    if stufe == nil or MASSE[stufe] == nil or MASSE.hoehe == nil then return nil end
    local key = stufe .. "|" .. text
    local zahl = istZahl(text)
    local lager = zahl and zahlen or worte
    local w = lager[key]
    if w == false then return nil end   -- schon einmal nicht messbar (ein Zeichen ohne Maske): kostet kein kaltes Wort mehr
    if w then
        w.bild = bildZaehler
        if w.zuege then return w end
        if kaltRest <= 0 then return nil end   -- auch ein nachgeholtes Wort zaehlt: ein Bild baut hoechstens KALT_JE_BILD
        kaltRest = kaltRest - 1
        if zuegeBauen(w) then return w end
        return nil
    end
    if kaltRest <= 0 then return nil end
    kaltRest = kaltRest - 1
    local b, h, cs, v = masze(text, stufe)
    if b == nil then lager[key] = false; return nil end
    if zahl then
        if zahlenZahl >= MAX_ZAHLEN then   -- voll: nur die Zahlen behalten, die im laufenden oder vorigen Bild standen - kein Bild faellt in die Ethos-Schrift
            local rest, n = {}, 0
            for k2, w2 in pairs(zahlen) do
                if w2 and w2.bild ~= nil and w2.bild >= bildZaehler - 1 then rest[k2], n = w2, n + 1 end
            end
            zahlen, zahlenZahl, lager = rest, n, rest
        end
        zahlenZahl = zahlenZahl + 1
    else
        if worteZahl >= MAX_WORTE then worte, worteZahl = {}, 0; lager = worte end
        worteZahl = worteZahl + 1
    end
    w = {breite = b, hoehe = h, stufe = stufe, cs = cs, v = v, bild = bildZaehler}
    lager[key] = w
    if zuegeBauen(w) then return w end
    return nil
end

local function mass(text, font)
    local w = wort(text, font)
    if w then return w.breite, w.hoehe end
    lcd.font(font or F_SM)
    return lcd.getTextSize(text)
end

local function textZug(px, py, text, farbe, font)
    lcd.color(farbe or C_WHITE)
    local w = wort(text, font)
    if w then
        local z = w.zuege
        for i = 1, #z do lcd.drawMask(floor(px) + z[i][1], floor(py) + z[i][2], z[i][3]) end
        return w.breite
    end
    lcd.font(font or F_SM)
    lcd.drawText(floor(px), floor(py), text)
    return (lcd.getTextSize(text))
end

local function beschriftungMittig(cx, cy, text, farbe, font)
    text = tostring(text or "")
    if text == "" then return end
    local tb, th = mass(text, font or F_SM)
    textZug(X(cx) - floor(tb / 2), Y(cy) - floor((th or 12) / 2), text, farbe, font or F_SM)
end

local function beschriftungMittigPasst(cx, cy, text, farbe, font, maxRef)
    text = tostring(text or "")
    if text == "" then return end
    local grenze, f, start = sx(maxRef), font, false
    for _, stufe in ipairs(TREPPE) do
        if stufe == font then start = true end
        if start then
            f = stufe
            if mass(text, stufe) <= grenze then break end
        end
    end
    beschriftungMittig(cx, cy, text, farbe, f)
end

local function systemMittig(cx, cy, text, farbe, font)
    text = tostring(text or "")
    if text == "" then return end
    lcd.font(font or F_SM)
    local tb, th = lcd.getTextSize(text)
    lcd.color(farbe or C_DIM)
    lcd.drawText(X(cx) - floor((tb or 0) / 2), Y(cy) - floor((th or 12) / 2), text)
end

local function wert(fld, text, farbe, yoff) beschriftungMittig(fld.x, fld.y + (yoff or 14), text, farbe, fld.f) end
local function wertSystem(fld, text, farbe, yoff) systemMittig(fld.x, fld.y + (yoff or 14), text, farbe, fld.f) end

local function wert2(fld, zahl, einheit, farbe, yoff)
    zahl = tostring(zahl)
    local zb, th = mass(zahl, fld.f)
    local eb = mass(einheit, fld.f)
    local luecke = max(2, sx(4))
    local links = X(fld.x) - floor((zb + luecke + eb) / 2)
    local oben = Y(fld.y + (yoff or 14)) - floor((th or 12) / 2)
    textZug(links, oben, zahl, farbe, fld.f)
    textZug(links + zb + luecke, oben, einheit, C_WHITE, fld.f)
end

local function timerZeile(fld, kz, zeit, farbe)
    local zb, zh = mass(zeit, fld.f)
    local kb = 0
    if kz and kz ~= "" then kb = mass(kz, F_TINY) end
    local luecke = (kb > 0) and max(2, sx(5)) or 0
    local links = X(fld.x) - floor((kb + luecke + zb) / 2)
    local grund = Y(fld.y + 14) + floor((zh or 15) / 2)
    if kb > 0 then
        local _, kh = mass(kz, F_TINY)
        textZug(links, grund - (kh or 12), kz, C_DIM, F_TINY)
    end
    textZug(links + kb + luecke, grund - (zh or 15), zeit, farbe, fld.f)
end

local function flaeche(x, y, w, h, farbe)
    lcd.color(farbe)
    lcd.drawFilledRectangle(X(x), Y(y), sx(w), sy(h))
end

local function kreisVoll(x, y, r)
    if type(lcd.drawFilledCircle) == "function" then lcd.drawFilledCircle(x, y, r) else lcd.drawFilledRectangle(x - r, y - r, 2 * r, 2 * r) end
end

local function radius(eh)
    if eh < 22 then return 0 end
    return max(3, min(12, floor(eh / 4)))
end

local function flaecheRund(x, y, w, h, farbe)
    local ex, ey, ew, eh = X(x), Y(y), sx(w), sy(h)
    local r = radius(eh)
    lcd.color(farbe)
    if r == 0 then lcd.drawFilledRectangle(ex, ey, ew, eh) return end
    lcd.drawFilledRectangle(ex + r, ey, ew - 2 * r, eh)
    lcd.drawFilledRectangle(ex, ey + r, r, eh - 2 * r)
    lcd.drawFilledRectangle(ex + ew - r, ey + r, r, eh - 2 * r)
    kreisVoll(ex + r, ey + r, r)
    kreisVoll(ex + ew - r - 1, ey + r, r)
    kreisVoll(ex + r, ey + eh - r - 1, r)
    kreisVoll(ex + ew - r - 1, ey + eh - r - 1, r)
end

local function rahmen(z, farbe)
    local x, y, w, h = X(z.x), Y(z.y), sx(z.w), sy(z.h)
    lcd.color(farbe)
    local r = (type(lcd.drawAnnulusSector) == "function") and radius(h) or 0
    if r == 0 then
        lcd.drawRectangle(x, y, w, h)
        lcd.drawRectangle(x + 1, y + 1, w - 2, h - 2)
        return
    end
    lcd.drawFilledRectangle(x + r, y, w - 2 * r, 2)
    lcd.drawFilledRectangle(x + r, y + h - 2, w - 2 * r, 2)
    lcd.drawFilledRectangle(x, y + r, 2, h - 2 * r)
    lcd.drawFilledRectangle(x + w - 2, y + r, 2, h - 2 * r)
    lcd.drawAnnulusSector(x + w - r - 1, y + r, r - 2, r, 0, 90)
    lcd.drawAnnulusSector(x + w - r - 1, y + h - r - 1, r - 2, r, 90, 180)
    lcd.drawAnnulusSector(x + r, y + h - r - 1, r - 2, r, 180, 270)
    lcd.drawAnnulusSector(x + r, y + r, r - 2, r, 270, 360)
end

local bild, bildNr, bildVersuche = nil, nil, 0
local function bildMalen(nr)
    if bildNr ~= nr then bild, bildNr, bildVersuche = nil, nr, 0 end
    if bild == nil and bildVersuche < 20 then
        bildVersuche = bildVersuche + 1
        bild = laden(lcd.loadBitmap, "gfx/" .. BILDER[nr])
    end
    if bild and pcall(lcd.drawBitmap, X(0), Y(0), bild, sx(480), sy(320)) then return true end
    lcd.color(C_BLACK)
    lcd.drawFilledRectangle(X(0), Y(0), sx(480), sy(320))
    return false
end

local farbeNr, farbeGelesen, txSrc, cpuSrc, cpuName, quellenSuche = 1, -99, nil, nil, nil, -99
local yawSrc, altSrc = nil, nil

local function quelleWert(src)
    if not src then return nil end
    local ok, v = pcall(function() return src:value() end)
    if ok then return tonumber(v) end
    return nil
end

local function sensorSuchen(ids)   -- der erste Sensor, der gerade einen Wert liefert; ein Modell kann alte Sensoren ohne Wert fuehren
    for _, id in ipairs(ids) do
        local ok, src = pcall(system.getSource, {category = CATEGORY_TELEMETRY_SENSOR, appId = id})
        if ok and src then
            local ov, v = pcall(function() return src:value() end)
            if ov and tonumber(v) ~= nil then return src end
        end
    end
    return nil
end

local function dash() return rf and rf.widgets and rf.widgets.dashboard end

local function farbeLesen()
    local d = dash()
    local v = d and d.getPreference and tonumber(d.getPreference("farbe"))
    if v and BILDER[v] then farbeNr = floor(v) end
end

local function farbeWeiter()
    farbeNr = farbeNr % #BILDER + 1
    local d = dash()
    if d and d.savePreference then pcall(d.savePreference, "farbe", farbeNr) end
end

local function quellenFinden()
    if not (system and system.getSource) then return end
    if txSrc == nil and CATEGORY_SYSTEM and MAIN_VOLTAGE ~= nil then
        local ok, src = pcall(system.getSource, {category = CATEGORY_SYSTEM, member = MAIN_VOLTAGE})
        if ok and src then
            local ov, v = pcall(function() return src:value() end)
            if ov and tonumber(v) and tonumber(v) > 4 and tonumber(v) < 13 then txSrc = src end
        end
    end
    if cpuSrc == nil and CATEGORY_TELEMETRY_SENSOR then
        for _, n in ipairs(CPU_NAMEN) do
            local ok, src = pcall(system.getSource, {category = CATEGORY_TELEMETRY_SENSOR, name = n})
            if ok and src then cpuSrc, cpuName = src, n break end
        end
    end
    if CATEGORY_TELEMETRY_SENSOR then
        if yawSrc ~= nil and quelleWert(yawSrc) == nil then yawSrc = nil end   -- Sensor verstummt: in 5 s neu suchen
        if altSrc ~= nil and quelleWert(altSrc) == nil then altSrc = nil end
        if yawSrc == nil then yawSrc = sensorSuchen(YAW_QUELLEN) end
        if altSrc == nil then altSrc = sensorSuchen(ALT_QUELLEN) end
    end
end

local lebt, lebtModell = {}, nil
local function ohneNull(key, v)
    if v == nil then return nil end
    if v ~= 0 then lebt[key] = true end
    if lebt[key] then return v end
    return nil
end

local function becEcht(v)
    if v == nil then return nil end
    if abs(v - BEC_FUELLBYTE) < 0.05 or v < BEC_MIN or v > BEC_MAX then return nil end
    return v
end

local function modellName()
    if model and model.name then
        local ok, n = pcall(model.name)
        if ok and n and tostring(n) ~= "" then return tostring(n) end
    end
    return nil
end

local bezug, gefasst = nil, false
local function gradLesen(tele)
    local v = tele.getSensor and tonumber((tele.getSensor("attyaw")))
    local q = nil
    if v ~= nil then
        q = tele.getSensorSource and tele.getSensorSource("attyaw")
    elseif yawSrc then
        v, q = quelleWert(yawSrc), yawSrc
    end
    if v == nil then return nil end
    if q and type(q.protocolDecimals) == "function" then
        local ok, n = pcall(q.protocolDecimals, q)
        if ok and n == 0 then v = v / 10 end
    end
    return v % 360
end

local function richtungTakt(grad, scharf)
    if grad == nil then
        if not gefasst then bezug = nil end
        return
    end
    if scharf then
        if not gefasst then bezug = grad end
        gefasst = true
    else
        gefasst = false
        if bezug == nil then bezug = grad end
    end
end

local rpmHoch, cellF = 0, nil
local st = {link = false}
local schlepp = {}   -- je Bank Min und Max der Drehzahl, solange scharf: der Schleppmonitor im BANK-Monitor liest hier

local function lesen(tele)
    local s = {link = tele.active and tele.active() or false}
    local mn = modellName()
    if mn ~= lebtModell then
        lebt, lebtModell, rpmHoch, cellF = {}, mn, 0, nil
        for k in pairs(schlepp) do schlepp[k] = nil end
    end
    s.modell = mn
    if s.link then
        local function g(k) return tonumber((tele.getSensor(k))) end
        s.pack = ohneNull("pack", g("voltage"))
        s.cell = ohneNull("cell", g("cell_voltage"))
        local zellen = g("cell_count")
        if s.cell == nil and s.pack ~= nil and zellen ~= nil and zellen >= 1 then s.cell = s.pack / zellen end
        if s.cell ~= nil then
            if cellF == nil or abs(s.cell - cellF) > 0.3 then cellF = s.cell else cellF = cellF * 0.9 + s.cell * 0.1 end
            s.cellF = cellF
        end
        s.rssi, s.vfr = g("link"), g("vfr")
        s.rpm = g("rpm")
        if s.rpm and s.rpm > rpmHoch then rpmHoch = s.rpm end
        s.temp = ohneNull("temp", g("temp_esc"))
        s.mcutemp = g("temp_mcu")
        if s.mcutemp ~= nil and (s.mcutemp < 10 or s.mcutemp > 130) then s.mcutemp = nil end
        local arm = g("armflags")
        if arm ~= nil then s.scharf = floor(arm) % 2 == 1 end
        s.bec = ohneNull("bec", becEcht(g("bec_voltage")))
        s.bank, s.rate = g("pid_profile"), g("rate_profile")
        s.last = ohneNull("last", g("current"))
        local alt = g("altitude")
        if alt == nil and altSrc then alt = quelleWert(altSrc) end
        s.alt = ohneNull("alt", alt)
        s.cpu = quelleWert(cpuSrc)
        if s.cpu ~= nil and (s.cpu < 0 or s.cpu > 100) then s.cpu = nil end
        s.grad = gradLesen(tele)
    end
    if s.scharf == true and s.rpm ~= nil and s.rpm > 0 and s.bank ~= nil then
        local b = floor(s.bank)
        local sl = schlepp[b]
        if sl == nil then
            schlepp[b] = {min = s.rpm, max = s.rpm}
        else
            if s.rpm < sl.min then sl.min = s.rpm end
            if s.rpm > sl.max then sl.max = s.rpm end
        end
    end
    s.tx = quelleWert(txSrc)
    local tm = rf and rf.session and rf.session.timer
    s.timer = tm and tonumber(tm.live) or nil
    richtungTakt(s.grad, s.scharf == true)
    s.winkel = (bezug ~= nil and s.grad ~= nil) and (s.grad - bezug) % 360 or nil
    return s
end

local function fmt(n, u, d)
    if n == nil then return "" end
    return string.format("%." .. (d or 0) .. "f", n) .. (u or "")
end

local function fmtT(sec)
    if sec == nil then return "" end
    sec = max(0, floor(sec + 0.5))
    return string.format("%02d:%02d", floor(sec / 60), sec % 60)
end

local function cellKey(v)
    if v == nil then return "w" end
    if v < 3.45 then return "r" end
    if v < 3.65 then return "o" end
    if v < 3.75 then return "y" end
    return "g"
end

local function cellBars(v, n)
    if v == nil then return 0 end
    local p = (v - 3.5) / (4.2 - 3.5)
    if p < 0 then p = 0 elseif p > 1 then p = 1 end
    return floor(p * n + 0.5)
end

local function armInfo(s)
    if not s.link then return T.link, C_GRAY, C_LRED end
    if s.scharf == true then return "ARMED", C_GREEN, C_WHITE end
    if s.scharf == false then return "DISARMED", C_RED, C_WHITE end
    return T.unbekannt, C_GRAY, C_WHITE
end

local function rpmDeg(v)
    if v == nil then return nil end
    local voll = max(BEZUG_OHNE_FLUG, rpmHoch) * 1.25
    if v < 0 then v = 0 elseif v > voll then v = voll end
    local d = floor(GAUGE.d0 + (GAUGE.d1 - GAUGE.d0) * v / voll + 0.5)
    if d < -60 then d = -60 elseif d > 240 then d = 240 end
    return d
end

local function polar(r, d) return GAUGE.cx + r * COST[d], GAUGE.cy - r * SINT[d] end

local function nadelMalen(rpm)
    local d = rpmDeg(rpm)
    if d == nil then return end
    local xt, yt = polar(GAUGE.rTip, d)
    lcd.color(C_LRED)
    if type(lcd.drawFilledTriangle) == "function" then
        local x1, y1 = polar(GAUGE.rBase, max(d - 7, -60))
        local x2, y2 = polar(GAUGE.rBase, min(d + 7, 240))
        pcall(lcd.drawFilledTriangle, X(x1), Y(y1), X(x2), Y(y2), X(xt), Y(yt))
    else
        lcd.drawLine(X(GAUGE.cx), Y(GAUGE.cy), X(xt), Y(yt))
    end
end

local function richtungMalen(w)
    local R = RICHTUNG
    lcd.color(C_RING)
    kreisVoll(X(R.x), Y(R.y), max(1, floor(sx(R.r) + 0.5)))
    lcd.color(C_BLACK)
    kreisVoll(X(R.x), Y(R.y), max(1, floor(sx(R.r - R.rand) + 0.5)))
    if w == nil then return end
    local function ecke(r, grad)
        local a = math.rad(w + grad)
        return X(R.x + r * math.sin(a)), Y(R.y - r * math.cos(a))
    end
    local x1, y1 = ecke(R.spitze, 0)
    if type(lcd.drawFilledTriangle) == "function" then
        local x2, y2 = ecke(R.fuss, R.ecke)
        local x3, y3 = ecke(R.fuss, -R.ecke)
        local xm, ym = ecke(R.fuss * math.cos(math.rad(180 - R.ecke)), 180)
        lcd.color(C_NADEL_LICHT)
        lcd.drawFilledTriangle(x1, y1, x3, y3, xm, ym)
        lcd.color(C_NADEL_SCHATTEN)
        lcd.drawFilledTriangle(x1, y1, xm, ym, x2, y2)
    else
        lcd.color(C_NADEL_LICHT)
        lcd.drawLine(X(R.x), Y(R.y), x1, y1)
    end
end

local gesperrtBis = 0

-- Monitore: Vollbilder ueber dem Cockpit, geoeffnet durch Antippen einer Tuer-Zone, geschlossen ueber ihre ZURUECK-Zone.
-- MONITORE[name] = {malen = fn(x, y, w, h, s), ereignis = fn oder nil, zurueck = {x, y, w, h}}; TUEREN: {zone = {x, y, w, h}, ziel = name}
-- LADER[name] laedt die Datei eines Schirms erst beim Oeffnen; beim Schliessen gibt das Cockpit ihn wieder frei - im Ruhezustand traegt das Theme keinen Schirm
local MONITORE, TUEREN, LADER = {}, {}, {}
local monitorAktiv = nil

local function monitorOeffnen(name)
    local m = MONITORE[name]
    if m == nil and LADER[name] then m = LADER[name]() end
    if m == nil then return false end
    if m.oeffnen then
        local ok, auf, grund = pcall(m.oeffnen)
        if not ok or auf == false then
            merken(name .. " oeffnet nicht: " .. tostring(grund or auf))
            return false
        end
    end
    MONITORE[name], monitorAktiv = m, name
    return true
end

local function monitorZu()
    local name = monitorAktiv
    local m = name and MONITORE[name]
    monitorAktiv = nil
    if m and m.verlassen then m.verlassen() end
    if name and LADER[name] then MONITORE[name] = nil end
end

local function malen(x, y, w, h, s)
    ox, oy, fx, fy = x, y, w / 480, h / 320
    kursivAn = (w == 480 and h == 320)
    if tabellenStufe < 2 then
        tabellenSchritt()
        bildMalen(farbeNr)
        return
    end
    kaltRest, bildZaehler = KALT_JE_BILD, bildZaehler + 1
    s = s or st
    local m = monitorAktiv and MONITORE[monitorAktiv]
    if m then
        m.malen(x, y, w, h, s)
        return
    end
    bildMalen(farbeNr)
    for _, L in ipairs(U.labels) do beschriftungMittig(L[1], L[2] + 6, L[3], C_WHITE, L[4] or F_SM) end

    local at, ac, atc = armInfo(s)
    flaecheRund(U.arm.x, U.arm.y, U.arm.w, U.arm.h, ac)
    beschriftungMittigPasst(U.arm.x + U.arm.w / 2, U.arm.y + U.arm.h / 2 + U.arm.tief, at, atc, U.arm.f, U.arm.w - 4)
    richtungMalen(s.winkel)

    if s.rssi then wertSystem(U.rssi, "RSSI " .. fmt(s.rssi, "dB", 0), C_WHITE, 8) end
    if s.vfr then
        local vk = (s.vfr >= VFR_YEL) and "w" or ((s.vfr >= VFR_RED) and "y" or "r")
        wertSystem(U.vfr, "VFR " .. fmt(s.vfr, "", 0), SETC[vk], 8)
    end
    beschriftungMittig(64, 70, T.timer, C_WHITE, F_SM)
    if s.timer ~= nil then timerZeile(U.timer, "", fmtT(s.timer), C_LGREEN) else timerZeile(U.timer, "", "--:--", C_DIM) end
    for _, fld in ipairs({U.timer2, U.timer3, U.timer4}) do timerZeile(fld, "", "--:--", C_DIM) end

    local bf = (s.bank ~= nil and s.rate ~= nil and s.bank ~= s.rate) and C_LRED or C_LGREEN
    if s.bank ~= nil then wert(U.bank, fmt(s.bank, "", 0), bf) else wert(U.bank, "?", C_DIM) end
    if s.rate ~= nil then wert(U.rate, fmt(s.rate, "", 0), bf) else wert(U.rate, "?", C_DIM) end

    if s.alt ~= nil then
        rahmen(U.alt, C_DIM)
        systemMittig(U.alt.x + U.alt.w / 2, U.alt.y + U.alt.h / 2, fmt(s.alt, " m", 0), C_WHITE, U.alt.f)
        systemMittig(U.alt.x - 17, U.alt.y + U.alt.h / 2, "ALT", C_DIM, F_TINY)
    end

    nadelMalen(s.rpm)
    if s.modell then wert(U.modelname, (#s.modell > 16) and s.modell:sub(1, 16) or s.modell, C_WHITE, 10) end
    if s.rpm then wert(U.rpm, fmt(s.rpm, "", 0), C_LGREEN, 16) end

    if s.bec then wert2(U.bec, fmt(s.bec, "", 1), "V", (s.bec >= 5.0) and C_LGREEN or C_YELLOW) else wert(U.bec, "--", C_DIM) end
    if s.tx then
        wert2(U.tx, fmt(s.tx, "", 1), "V", (s.tx >= 7.4) and C_LGREEN or ((s.tx >= 7.0) and C_YELLOW or C_LRED))
    else wert(U.tx, "--", C_DIM) end
    if s.last then wert2(U.amp, fmt(s.last, "", 1), "A", C_LGREEN) else wert(U.amp, "--", C_DIM) end
    beschriftungMittig(289, 59, (cpuName == "RT Load") and "RT" or "CPU", C_WHITE, F_TINY)
    if s.cpu then
        wert2(U.cpu, fmt(s.cpu, "", 0), "%", (s.cpu < 50) and C_LGREEN or ((s.cpu < 80) and C_YELLOW or C_LRED), 8)
    else wert(U.cpu, "--", C_DIM, 8) end

    local sperre = os.clock() < gesperrtBis
    local cv = s.cellF or s.cell
    if s.pack and not sperre then wert2(U.pack, fmt(s.pack, "", 1), "V", SETC[cellKey(cv)], 16) end
    if cv and not sperre then
        local p = (cv - 3.5) / 0.7 * 100
        if p < 0 then p = 0 elseif p > 100 then p = 100 end
        wert2(U.battpct, fmt(p, "", 0), "%", SETC[cellKey(cv)], 16)
    end
    local bars, hc = cellBars(cv, U.batt.n), SETC[cellKey(cv)]
    for i = 1, bars do flaeche(U.batt.x, U.batt.y - (i - 1) * (U.batt.bh + U.batt.gap), U.batt.bw, U.batt.bh, hc) end

    if s.temp then
        wert2(U.temp, fmt(s.temp, "", 0), "\194\176C", (s.temp < 60) and C_LGREEN or ((s.temp < 80) and C_YELLOW or C_LRED))
    else wert(U.temp, "--", C_DIM) end
    if s.mcutemp then
        wert2(U.mcutemp, fmt(s.mcutemp, "", 0), "\194\176C", (s.mcutemp < 70) and C_LGREEN or ((s.mcutemp < 90) and C_YELLOW or C_LRED), 8)
    else wert(U.mcutemp, "--", C_DIM, 8) end

    if sperre then beschriftungMittigPasst(252, 300, T.scharf, C_LRED, F_SM, 196) end
end

local druck = nil
local fingerUnser = false                       -- der Finger hat auf einer Zone des Themes aufgesetzt und sie nicht verlassen
local TOUCH_LANG = rawget(_G, "TOUCH_LONG")     -- Ethos: langer Druck

local function ton(hz, ms) if system and type(system.playTone) == "function" then pcall(system.playTone, hz, ms, 0) end end

local function scharfJetzt() return (st.scharf == true) or (rf ~= nil and rf.session ~= nil and rf.session.isArmed == true) end

local function kopfLang()
    druck = nil
    if scharfJetzt() then
        gesperrtBis = os.clock() + SPERRE_SEK
        ton(200, 90)
    else
        farbeWeiter()
        ton(880, 120)
    end
end

local function langdruckPruefen()
    local d = druck
    if d == nil or d.zone ~= "header" or os.clock() - d.seit < LANG then return end
    kopfLang()
end

local erstesWach = true
local function wach(box, tele)
    if erstesWach then erstesWach = false   -- der erste Wakeup traegt schon das Laden dieser Datei
    elseif tabellenStufe < 2 then tabellenSchritt() end
    local jetzt = os.clock()
    langdruckPruefen()
    if jetzt - farbeGelesen >= FARBE_LESEN_SEK then
        farbeGelesen = jetzt
        farbeLesen()
    end
    if jetzt - quellenSuche >= 5 then
        quellenSuche = jetzt
        quellenFinden()
    end
    maskenLaden(MASKEN_JE_TAKT)
    if tele then st = lesen(tele) end
    local m = monitorAktiv and MONITORE[monitorAktiv]
    if m and m.takt then m.takt() end
    return st
end

local function trifft(z, x, y)
    return x ~= nil and y ~= nil and x >= X(z.x) and x < X(z.x) + sx(z.w) and y >= Y(z.y) and y < Y(z.y) + sy(z.h)
end

local function ereignis(widget, category, value, x, y)
    if category ~= EVT_TOUCH then return false end
    local m = monitorAktiv and MONITORE[monitorAktiv]
    if m then   -- im Monitor gelten nur seine ZURUECK-Zone und sein eigenes Ereignis; die Cockpit-Zonen sind zu
        if value == TOUCH_START then
            druck = trifft(m.zurueck, x, y) and {zone = "zurueck", seit = os.clock(), x = x, y = y} or nil
        elseif value == TOUCH_MOVE then
            if druck and x and y and (abs(x - druck.x) > DRIFT or abs(y - druck.y) > DRIFT) then druck = nil end
        elseif (value == TOUCH_END or value == TOUCH_LANG) and druck ~= nil then
            local d = druck
            druck = nil
            if d.zone == "zurueck" then   -- wie die Knoepfe in NovaFly: es zaehlt das Loslassen auf dem Knopf, nicht die Dauer des Drucks
                ton(880, 120)   -- derselbe Ton wie Plus, Minus und SPEICHERN im Schirm
                monitorZu()
                if widget then lcd.invalidate(widget) end
                return true
            end
        end
        if m.ereignis then m.ereignis(widget, category, value, x, y) end
        return true   -- im offenen Schirm gehoert jede Beruehrung dem Theme: eine nicht verbrauchte Bewegung nimmt Ethos zum Blaettern, dann kommt kein TOUCH_END
    end
    if value == TOUCH_START then
        druck = nil
        if trifft(ZONEN.header, x, y) then druck = {zone = "header", seit = os.clock(), x = x, y = y}
        elseif trifft(ZONEN.richtung, x, y) then druck = {zone = "richtung", seit = os.clock(), x = x, y = y}
        else
            for i = 1, #TUEREN do
                local t = TUEREN[i]
                if trifft(t.zone, x, y) then
                    druck = {zone = "tuer", ziel = t.ziel, seit = os.clock(), x = x, y = y}
                    break
                end
            end
        end
        fingerUnser = (druck ~= nil)
        return druck ~= nil   -- setzt der Finger auf einer Zone auf, behaelt ihn das Theme
    end
    if value == TOUCH_MOVE then
        if druck and x and y and (abs(x - druck.x) > DRIFT or abs(y - druck.y) > DRIFT) then druck, fingerUnser = nil, false end
        return druck ~= nil   -- liegt der Finger noch auf seiner Zone, verbraucht das Theme die Bewegung: sonst nimmt Ethos ihn zum Blaettern und TOUCH_END bleibt aus
    end
    if value == TOUCH_LANG then   -- nach etwa einer Sekunde meldet Ethos den langen Druck selbst, ein TOUCH_END kommt danach nicht mehr
        local d = druck
        if d and d.zone == "header" then
            kopfLang()
        else
            druck = nil
            if d and d.zone == "tuer" and monitorOeffnen(d.ziel) then
                ton(880, 120)   -- auch beim langen Druck piept die Tuer
                if widget then lcd.invalidate(widget) end
            end
        end
        return fingerUnser   -- lag der Finger auf einer Zone, ist der lange Druck verbraucht: Ethos legt nichts Eigenes darueber
    end
    if value ~= TOUCH_END or druck == nil then return false end
    local d = druck
    druck = nil
    if d.zone == "tuer" then
        if monitorOeffnen(d.ziel) then   -- eine Tuer oeffnet beim Loslassen, gleich wie lange der Finger lag
            ton(880, 120)   -- eine Tuer, die aufgeht, piept wie der Kompass
            if widget then lcd.invalidate(widget) end
            return true
        end
        return false
    end
    if d.zone ~= "richtung" or os.clock() - d.seit >= LANG then return false end
    if st.grad ~= nil and not scharfJetzt() then
        bezug = st.grad
        ton(880, 120)
    else
        ton(200, 90)
    end
    if widget then lcd.invalidate(widget) end
    return true
end

-- die Kursivschrift fuer die Zeichenteile der Schirme (stil_teile.lua): messen geht immer, gemalt wird, sobald die Masken geladen sind
local kursivHelfer = {abgeschaltet = false, unfertig = false, fensterNeu = function() end}
local massMerk, massMerkN = {}, 0   -- Masse je Stufe und Text: jedes Wort wird einmal gemessen, nicht je Bild

function kursivHelfer.breite(text, font)
    if not kursivAn then return nil end
    local stufe = NACH_STUFE[font]
    if stufe == nil or MASSE[stufe] == nil or MASSE.hoehe == nil then return nil end
    local key = stufe .. "|" .. text
    local m = massMerk[key]
    if m == nil then
        local b, h = masze(text, stufe)
        if massMerkN >= 200 then massMerk, massMerkN = {}, 0 end
        m = (b ~= nil) and {b, h} or false
        massMerk[key], massMerkN = m, massMerkN + 1
    end
    if m == false then return nil end
    return m[1], m[2]
end

function kursivHelfer.sparen() kaltRest = 0 end   -- dieses Bild baut kein neues Wort: es traegt schon eine andere einmalige Last

function kursivHelfer.malen(px, py, text, font)
    local w = wort(text, font)
    if w == nil then
        if kursivHelfer.breite(text, font) ~= nil then kursivHelfer.unfertig = true end
        return nil
    end
    local z = w.zuege
    for i = 1, #z do lcd.drawMask(floor(px) + z[i][1], floor(py) + z[i][2], z[i][3]) end
    return w.breite
end

do   -- der BANK-Schirm: eigene Datei, bekommt die Kursivschrift, den Schlepp-Merker, einen Merker ueber das Schliessen hinaus und rfsuite
    local HELFER = {trifft = trifft, ton = ton, schlepp = schlepp, kursiv = kursivHelfer, laden = laden, merk = {},
                    i18n = SPRACHE, rf = function() return rf end, stand = function() return st end}
    -- Tuer: BANK/RATE-Feld -> BANK
    local MODULE = {{"bank", {x = 20, y = 184, w = 92, h = 44}}}
    for _, m in ipairs(MODULE) do
        LADER[m[1]] = function()
            local chunk, grund = laden(loadfile, m[1] .. ".lua")
            if not chunk then merken(m[1] .. ".lua laedt nicht: " .. tostring(grund)) return nil end
            local ok, mon = pcall(chunk, HELFER)
            if ok and type(mon) == "table" then return mon end
            merken(m[1] .. ".lua bricht ab: " .. tostring(mon))
            return nil
        end
        TUEREN[#TUEREN + 1] = {zone = m[2], ziel = m[1]}
    end
end

local BOX = {col = 1, row = 1, type = "func", wakeupinterval = 0.1, wakeup = wach, paint = function(x, y, w, h, box, cache) malen(x, y, w, h, cache) end}

local ZUSTAND = {layout = {cols = 1, rows = 1, padding = 0}, boxes = {BOX}, event = ereignis,
                 scheduler = {spread_scheduling = false, spread_scheduling_paint = false, spread_ratio = 1.0}}

return {zustand = function() return ZUSTAND end, malen = malen, lesen = lesen, wach = wach, ereignis = ereignis, BILDER = BILDER,
        monitore = MONITORE, tueren = TUEREN, monitorOeffnen = monitorOeffnen, monitorZu = monitorZu,
        aktiverMonitor = function() return monitorAktiv end}
