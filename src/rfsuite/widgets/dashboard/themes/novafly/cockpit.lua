-- NovaFly-Cockpit als rfsuite-Theme: ein Grund, die Linien als Code in der gewaehlten Farbe (rahmen.lua), Werte aus der
-- rfsuite-Telemetrie in Senderschrift; ein langer Druck auf den Kopf schaltet am Boden die Farbe, Wischen quer blaettert zu
-- den Seiten (vorflug.lua, baenke.lua). Der Modus (configure.lua, Schluessel mode: 1 dunkel, 2 hell) tauscht die Farben der
-- Schrift, den Grund (hell: Baender von Weiss zum Tint der Farbe, wie der Canvas-Verlauf) und die Linien (hell: Kern dunkel).
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
local MODUS = {hell = false, seiten = {},   -- der Modus (hell = true nach der Einstellung mode) und alles, was er tauscht - eine Tabelle: Lua erlaubt 200 lokale Namen je Datei
    palette = {   -- die Farben der Schrift und Flaechen je Modus: dunkel wie bisher; hell nach dem Design-System (Schrift 20,20,19, Leise 95,107,120, Gruen 10,122,36),
        {weiss = {245, 248, 252}, leise = {120, 132, 145}, grau = {52, 56, 64}, gruen = {90, 255, 70}, gelb = {240, 210, 30}, orange = {255, 130, 20}, rot = {255, 80, 80},   -- Gelb, Orange und Rot auf Weiss dunkler, damit sie lesbar bleiben
         grund = {8, 8, 10}, nadelLicht = {255, 255, 255}, nadelSchatten = {160, 176, 200}},
        {weiss = {20, 20, 19}, leise = {95, 107, 120}, grau = {214, 218, 225}, gruen = {10, 122, 36}, gelb = {176, 124, 0}, orange = {196, 96, 10}, rot = {200, 32, 32},
         grund = {243, 245, 248}, nadelLicht = {36, 40, 48}, nadelSchatten = {120, 130, 150}}},
    namen = {"blau", "magenta", "gruen", "orange", "gelb"}, von = {1, 2, 3, 4, 5, 1, 3, 2, 4},   -- die helle Fassung je Farbe des Cockpits (BILDER): die Carbon-Farben auf Blau, Gruen, Magenta, Orange
    mitte = {{238, 243, 249}, {247, 237, 244}, {238, 246, 239}, {249, 241, 234}, {248, 246, 234}},   -- der Grund des Canvas (Tweak Modus hell, 170 Grad): Weiss oben, bei 45 % der Mittelton, unten der Tint der Farbe
    tint = {{221, 231, 243}, {238, 219, 232}, {220, 236, 222}, {241, 226, 211}, {239, 234, 208}},
    linien = {{kern = {11, 90, 168}, mitte = {143, 193, 236}}, {kern = {155, 21, 119}, mitte = {231, 163, 211}}, {kern = {30, 127, 42}, mitte = {166, 220, 172}},   -- die Linien auf hellem Grund: der Kern dunkel, der Mittelton hell
              {kern = {154, 78, 15}, mitte = {240, 191, 142}}, {kern = {138, 122, 10}, mitte = {233, 221, 134}}},
    BAENDER = 20, baender = {}}
local C_WHITE, C_DIM, C_GRAY, C_LGREEN, C_YELLOW, C_ORANGE, C_LRED, C_BLACK, C_NADEL_LICHT, C_NADEL_SCHATTEN   -- gesetzt in MODUS.setzen
local C_RED, C_GREEN, C_RING = RGB(225, 40, 40), RGB(40, 180, 55), RGB(0, 152, 224)   -- die Felder ARMED und DISARMED und der Ring der Richtung: in beiden Modi gleich
local SETC = {feld = RGB(245, 248, 252)}   -- die Farben der Zahlen nach ihrer Grenze; dieselbe Tabelle bleibt, ein Moduswechsel fuellt sie neu; feld = die helle Schrift auf ARMED und DISARMED
function MODUS.setzen(neuHell)   -- die Upvalues der Farben, SETC und die Farben der Seiten (MODUS.seiten = HELFER.farben) neu
    MODUS.hell = neuHell == true
    local p = MODUS.palette[MODUS.hell and 2 or 1]
    local function c(k) return RGB(p[k][1], p[k][2], p[k][3]) end
    C_WHITE, C_DIM, C_GRAY, C_LGREEN, C_YELLOW, C_ORANGE, C_LRED, C_BLACK = c("weiss"), c("leise"), c("grau"), c("gruen"), c("gelb"), c("orange"), c("rot"), c("grund")
    C_NADEL_LICHT, C_NADEL_SCHATTEN = c("nadelLicht"), c("nadelSchatten")
    SETC.g, SETC.y, SETC.o, SETC.r, SETC.w = C_LGREEN, C_YELLOW, C_ORANGE, C_LRED, C_WHITE
    local s = MODUS.seiten
    s.gruen, s.gelb, s.rot, s.weiss, s.leise = C_LGREEN, C_YELLOW, C_LRED, C_WHITE, C_DIM
end
MODUS.setzen(false)

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
local GAUGE = {cx = 239.5, cy = 171.5}   -- die Mitte des Tachos; Bogen und Balken malt rahmen.lua
local BEZUG_OHNE_FLUG = 2000
local LANG, DRIFT, SPERRE_SEK, FARBE_LESEN_SEK, MASKEN_JE_TAKT, MAX_WORTE, KALT_JE_BILD = 0.6, 12, 2.5, 1.0, 8, 160, 4
local BEC_FUELLBYTE, BEC_MIN, BEC_MAX = 25.5, 3.0, 13.0
local RICHTUNG = {x = 147, y = 27, r = 16, rand = 1, spitze = 12, fuss = 10, ecke = 145}
local CPU_NAMEN = {"RT Load", "CPU Load", "System Load", "MCU Load",   -- RT Load ist der lebendige Wert, CPU Load der Durchschnitt (Rotorflight sendet beide)
                   kennungen = {{0x51D2, "RT Load"}, {0x51D0, "CPU Load"}, {0x51D1, "System Load"}}}   -- dieselben Sensoren ueber ihre Kennung, wenn kein Name trifft
local YAW_QUELLEN ={0x5210, 0x1103, 0x5022}   -- rfsuite 2.3.1 reicht Y.Winkel und Hoehe nicht mehr durch getSensor: dann liest das Theme die Ethos-Sensoren selbst (S.Port, CRSF, Simulator der Suite)
local ALT_QUELLEN = {0x0100, 0x10B2, 0x5016}

local U = {
    arm = {x = 14, y = 14, w = 94, h = 28, f = F_MID, tief = 1},
    rssi = {x = 413, y = 14, f = F_SM},
    vfr = {x = 413, y = 28, f = F_TINY},
    timer = {x = 58, y = 89, f = F_BIG},         -- das linke Feld reicht von 0 bis zur Linie 116: Mitte 58; der Block mittig in y 55-250
    rate = {x = 58, y = 150, f = F_MID},         -- RATE in der Mitte zwischen FLUGTIMER und BANK, gleiche Luft (37) nach oben und unten
    bank = {x = 58, y = 215, f = F_MID},
    rpm = {x = 241, y = 126, f = F_BIG},
    bec = {x = 421, y = 89, f = F_BIG},          -- das rechte Feld reicht von der Linie 363 bis 480: Mitte 421; die drei Bloecke rechts auf den Hoehen der drei links: BEC wie FLUGTIMER, TX wie RATE, ESC wie BANK
    tx = {x = 421, y = 150, f = F_BIG},
    amp = {x = 421, y = 215, f = F_BIG},
    cpu = {x = 331, y = 63, f = F_SM},
    pack = {x = 164, y = 273, f = F_HUGE, lage = "links"},      -- die Spannung beginnt nach der Batterie, der Stand endet am Feldrand: das V bleibt bei seiner Zahl
    battpct = {x = 346, y = 273, f = F_HUGE, lage = "rechts"},   -- endet vor der Linie bei 358
    modelname = {x = 239.5, y = 218, f = F_MID},   -- mittig unter dem Bogen
    batt = {x = 140, y = 294, bw = 12, bh = 5, gap = 1, n = 5},
    tank = {x = 370, y = 243, bw = 23, bh = 5, gap = 1, n = 4},   -- die vier Balken unter dem ESC-Wert (x 370-465, y 243-247): unter dem Stachel der Bankseite bei 240, ueber der Linie 250
    temp = {x = 422, y = 282, f = F_BIG},
    mcutemp = {x = 187, y = 51, f = F_SM},
    alt = {x = 58, y = 280, f = F_BIG},          -- die Hoehe links unten, mittig im Fussfeld (x 0-117, y 255-314)
    labels = {{58, 134, "RATE"}, {58, 195, "BANK"}, {421, 71, "BEC"},   -- die Beschriftungen in der kleinen Stufe (drei Groessen auf allen Schirmen: klein, mittel, gross); nur VFR unter RSSI bleibt winzig; BEC auf der Hoehe von FLUGTIMER (77), TX wie RATE, ESC wie BANK
              {421, 134, "TX"}, {421, 195, "ESC"}, {421, 262, "ESC"},
              {241, 170, "rpm"}, {143, 65, "MCU"}, {58, 266, "ALT"}},
}
local ZONEN = {header = {x = 176, y = 0, w = 184, h = 48}, richtung = {x = 127, y = 7, w = 40, h = 40}}

local SINT, COST = {}, {}   -- Winkeltabelle und Kursivmasse kommen in zwei Schritten beim ersten Wakeup und beim ersten Malen (Ethos bricht einen Aufruf ab 20 000 Befehlen ab); bis dahin malt das Cockpit nur den Grund
local MASSE, ZIFFER_VORSCHUB = {}, {}
local tabellenStufe = 0

local function tabellenSchritt()   -- Winkel- und Maskentabellen (SINT/COST, kursiv_masse.lua) liest seit der Senderschrift niemand mehr:
    tabellenStufe = 2              -- nichts mehr bauen, nichts mehr laden (Lua-Speicher am X18)
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
local function X(v) return ox + floor(v * fx + 0.5) end   -- wie sx, ohne Zwischenruf: jeder Zeichenbefehl geht hier durch (Rechenschritte je Malen)
local function Y(v) return oy + floor(v * fy + 0.5) end

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

local SPRACHE = nil   -- die Texte in der Sprache des Senders, dieselben wie in NovaFly; laedt die Datei nicht, bleibt das Cockpit deutsch
do
    local chunk = laden(loadfile, "i18n_teile.lua")
    local ok, tab = false, nil
    if chunk then ok, tab = pcall(chunk, {laden = laden}) end
    if ok and type(tab) == "table" then
        SPRACHE = tab
        T = {timer = tab.wort(T.timer), unbekannt = tab.b_arm_unbekannt, link = tab.f_kein_heli, scharf = tab.f_setup_scharf}
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

local function wert2(fld, zahl, einheit, farbe, yoff, font)   -- gibt den rechten Rand zurueck; font ersetzt fld.f
    font = font or fld.f
    zahl = tostring(zahl)
    local zb, th = mass(zahl, font)
    local eb = mass(einheit, font)
    local luecke = max(1, sx(2))   -- die Einheit dicht an ihrer Zahl
    local links   -- mittig um fld.x, oder ab fld.x (lage links), oder bis fld.x (lage rechts)
    if fld.lage == "links" then links = X(fld.x)
    elseif fld.lage == "rechts" then links = X(fld.x) - (zb + luecke + eb)
    else links = X(fld.x) - floor((zb + luecke + eb) / 2) end
    local oben = Y(fld.y + (yoff or 14)) - floor((th or 12) / 2)
    textZug(links, oben, zahl, farbe, font)
    textZug(links + zb + luecke, oben, einheit, C_WHITE, font)
    return links + zb + luecke + eb
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

local LIN = {tab = nil, aktiv = nil, nr = nil, rahmen = nil, absatz = {}, ecken = {}, auslauf = {}, M = {X = X, Y = Y, sx = sx, sy = sy}}   -- die Linienfarben je Bild aus linien.lua, einmal entpackt; die Seiten malen mit denselben (Merker in einer Tabelle: 200 lokale Namen je Datei)
local function linien(nr)
    local hell = MODUS.hell
    if LIN.aktiv ~= nil and LIN.nr == nr and LIN.hell == hell then return LIN.aktiv end
    if LIN.tab == nil then
        local chunk = laden(loadfile, "linien.lua")
        local ok, tab = false, nil
        if chunk then ok, tab = pcall(chunk) end
        LIN.tab = (ok and type(tab) == "table") and tab or {}
    end
    local e = LIN.tab[nr] or LIN.tab[1] or {mitte = {29, 126, 208}, kern = {153, 255, 255}, grund = {9, 10, 14}}
    if hell then   -- auf hellem Grund die Linie des Canvas: Kern dunkel, Mittelton hell, der Grund die helle Flaeche
        local h = MODUS.linien[MODUS.von[nr] or 1]
        e = {mitte = h.mitte, kern = h.kern, grund = MODUS.palette[2].grund}
    end
    local auslauf = {}   -- die Stufen, in denen eine Linie der Seiten in den Grund des Bilds auslaeuft (rahmen.lua R.STUFEN), einmal gemischt
    local g = e.grund or {0, 0, 0}
    local function misch(farbe, faktor, anteil)   -- die Farbe (mal faktor) zum Grund hin: anteil 1 die Farbe, 0 der Grund
        return RGB(floor(g[1] + (farbe[1] * faktor - g[1]) * anteil + 0.5), floor(g[2] + (farbe[2] * faktor - g[2]) * anteil + 0.5),
                   floor(g[3] + (farbe[3] * faktor - g[3]) * anteil + 0.5))
    end
    for i = 1, 12 do
        local anteil = (i - 0.5) / 12
        auslauf[i] = {misch(e.mitte, 1, anteil), misch(e.kern, 1, anteil), hell and misch(e.mitte, 1, anteil * 0.3) or misch(e.mitte, 0.3, anteil)}
    end
    LIN.aktiv = {mitte = RGB(e.mitte[1], e.mitte[2], e.mitte[3]), kern = RGB(e.kern[1], e.kern[2], e.kern[3]),   -- der Schein aussen an jeder Linie: 30 % des Mitteltons, wie im Bild tacho_base.png (Zeile 48 neben Zeile 49); hell 30 % des Mitteltons ueber dem Grund
                 schein = hell and misch(e.mitte, 1, 0.3) or RGB(floor(e.mitte[1] * 0.3 + 0.5), floor(e.mitte[2] * 0.3 + 0.5), floor(e.mitte[3] * 0.3 + 0.5)), auslauf = auslauf}
    LIN.nr, LIN.hell = nr, hell
    return LIN.aktiv
end

local function bildPfad(b)   -- das Modellbild des Piloten: Ethos nennt nur den Dateinamen; wie rfsuite (objects/image/model.lua) liegt es unter BITMAPS:/models/ - die Kartenwurzeln stehen nur hier und in zustand.lua
    if b:match("^/bitmaps/") then return (b:gsub("^/bitmaps", "BITMAPS:", 1)) end
    if b:match("^/scripts/") then return (b:gsub("^/scripts", "SCRIPTS:", 1)) end
    if b:match("^/system/") then return (b:gsub("^/system", "SYSTEM:", 1)) end
    if not b:match("^[A-Z]+:") and not b:match("^/") then return "BITMAPS:/models/" .. b end
    return b
end

local function rahmen()   -- die Linien des Cockpits als Code (rahmen.lua), einmal geladen; false, wenn die Datei fehlt
    if LIN.rahmen == nil then
        local chunk = laden(loadfile, "rahmen.lua")
        local ok, r = false, nil
        if chunk then ok, r = pcall(chunk) end
        LIN.rahmen = (ok and type(r) == "table") and r or false
    end
    return LIN.rahmen or nil
end

local function absatzMasken(R)   -- die drei Lagen des Absatzes als Masken je Schirmgroesse (rahmen.lua R.ABSATZ, R.endung), einmal geladen; nil, wenn eine fehlt
    local e = R.endung(LIN.M)
    local m = LIN.absatz[e]
    if m == nil then
        local d = R.ABSATZ.dateien
        m = {schein = laden(lcd.loadMask, "gfx/" .. d[1] .. e .. ".png"), mitte = laden(lcd.loadMask, "gfx/" .. d[2] .. e .. ".png"), kern = laden(lcd.loadMask, "gfx/" .. d[3] .. e .. ".png")}
        m = (m.schein and m.mitte and m.kern) and m or false
        LIN.absatz[e] = m
    end
    return m or nil
end

function LIN.eckenMasken(R)   -- die Ecken r 4 des Rahmens als Masken je Schirmgroesse, drei Lagen je Lage der Ecke (rahmen.lua R.ecke, gfx/ecke_*.png),
    local e = R.endung(LIN.M)   -- einmal geladen; nil, wenn eine fehlt - dann kommen die Ecken als Ringstuecke
    local ecken = LIN.ecken[e]
    if ecken == nil then
        local t, alle = {}, true
        for _, ort in ipairs({"lo", "ro", "lu", "ru"}) do
            t[ort] = {schein = laden(lcd.loadMask, "gfx/ecke_schein_" .. ort .. e .. ".png"), mitte = laden(lcd.loadMask, "gfx/ecke_mitte_" .. ort .. e .. ".png"),
                      kern = laden(lcd.loadMask, "gfx/ecke_kern_" .. ort .. e .. ".png")}
            if not (t[ort].schein and t[ort].mitte and t[ort].kern) then alle = false end
        end
        ecken = alle and t or false
        LIN.ecken[e] = ecken
    end
    return ecken or nil
end

function LIN.auslaufMasken(R)   -- der Auslauf der Linien auf den Seiten als Masken je Schirmgroesse: je Richtung und Laenge drei Lagen (rahmen.lua R.auslaufend,
    local e = R.endung(LIN.M)   -- gfx/auslauf_*.png), einmal geladen, wenn eine Seite aufgeht; nil, wenn eine fehlt - dann kommt der Auslauf als Stufen
    local a = LIN.auslauf[e]
    if a == nil then
        local t, alle = {links = {}, rechts = {}}, true
        for _, richtung in ipairs({"links", "rechts"}) do
            for _, laenge in ipairs(R.auslaufLaengen()) do
                local name = richtung .. "_" .. laenge .. e .. ".png"
                local m = {schein = laden(lcd.loadMask, "gfx/auslauf_schein_" .. name), mitte = laden(lcd.loadMask, "gfx/auslauf_mitte_" .. name), kern = laden(lcd.loadMask, "gfx/auslauf_kern_" .. name)}
                if not (m.schein and m.mitte and m.kern) then alle = false end
                t[richtung][laenge] = m
            end
        end
        a = alle and t or false
        LIN.auslauf[e] = a
    end
    return a or nil
end

local GRUND = {bild = nil, name = nil, versuche = 0}   -- der eine Grund (Hochglanz, bei den Carbon-Farben Carbon) fuer das Cockpit und die zwei Seiten, je Schirmgroesse ein Bild (gfx/glanz<Endung>.png: Ethos passt ein Bild mit festem Seitenverhaeltnis ins Fenster ein, ein 480er-Bild liesse auf 800 x 480 beidseits 40 Punkte frei); ohne das Bild tiefschwarz
function GRUND.hell(nr)   -- der helle Grund: 20 Baender ueber die Hoehe, von Weiss zum Tint der Farbe (der Canvas-Verlauf in Stufen); kein Bild, kein Speicher
    local f = MODUS.von[nr] or 1
    local b = MODUS.baender[f]
    if b == nil then
        b = {}
        for i = 0, MODUS.BAENDER - 1 do   -- die Farbe des i-ten Bands (0 oben): bis 45 % von Weiss zum Mittelton, dann zum Tint; dieselbe Rechnung steckt in fotorand_hell_<Farbe>.png
            local t = (i + 0.5) / MODUS.BAENDER
            local a, c, u
            if t < 0.45 then a, c, u = {255, 255, 255}, MODUS.mitte[f], t / 0.45 else a, c, u = MODUS.mitte[f], MODUS.tint[f], (t - 0.45) / 0.55 end
            b[i + 1] = RGB(floor(a[1] + (c[1] - a[1]) * u + 0.5), floor(a[2] + (c[2] - a[2]) * u + 0.5), floor(a[3] + (c[3] - a[3]) * u + 0.5))
        end
        MODUS.baender[f] = b
    end
    local schritt = 320 / MODUS.BAENDER
    for i = 1, MODUS.BAENDER do
        lcd.color(b[i])
        lcd.drawFilledRectangle(X(0), Y((i - 1) * schritt), sx(480), Y(i * schritt) - Y((i - 1) * schritt))
    end
end
function GRUND.malen(nr, R)
    if R then R.modus(MODUS.hell) end   -- Bogen, Zonen, Teilstriche und Pfeil in den Farben des Modus, bevor eine Linie faellt
    if MODUS.hell then
        GRUND.hell(nr)
        return true
    end
    local name = (BILDER[nr]:find("carbon", 1, true) and "carbon" or "glanz") .. (R and R.endung(LIN.M) or "") .. ".png"
    if GRUND.name ~= name then GRUND.bild, GRUND.name, GRUND.versuche = nil, name, 0 end
    if GRUND.bild == nil and GRUND.versuche < 20 then
        GRUND.versuche = GRUND.versuche + 1
        GRUND.bild = laden(lcd.loadBitmap, "gfx/" .. name)
    end
    local gemalt = GRUND.bild and pcall(lcd.drawBitmap, X(0), Y(0), GRUND.bild, sx(480), sy(320))
    if not gemalt then
        lcd.color(C_BLACK)
        lcd.drawFilledRectangle(X(0), Y(0), sx(480), sy(320))
    end
    return gemalt == true
end
local LOGO = {bild = {}, versuche = {}}   -- das Logo der Suite oben in der Mitte des Kopfbands, je Schirmgroesse ein Bild (gfx/rotorflight<Endung>.png, 24 bzw. 36 Punkte hoch, Breite im Verhaeltnis 400 : 84); hell die dunkle Fassung rotorflight_hell<Endung>.png
function LOGO.malen(R)
    local e = (MODUS.hell and "_hell" or "") .. (R and R.endung(LIN.M) or "")
    local versuche = LOGO.versuche[e] or 0
    if LOGO.bild[e] == nil and versuche < 20 then
        LOGO.versuche[e] = versuche + 1
        LOGO.bild[e] = laden(lcd.loadBitmap, "gfx/rotorflight" .. e .. ".png")
    end
    local bild = LOGO.bild[e]
    if not bild then return false end
    local h = sy(24)
    local w = floor(h * 400 / 84 + 0.5)
    return pcall(lcd.drawBitmap, X(240) - floor(w / 2), Y(11), bild, w, h) == true
end
local function bildMalen(nr)
    local R = rahmen()
    if R then R.frisch(LIN.M) end   -- die Masse der Linien zum Fenster, einmal je Bild (rahmen.lua masse liest sie dann ohne Rechnung)
    local gemalt = GRUND.malen(nr, R)
    if R then R.cockpit(LIN.M, linien(nr), absatzMasken(R), LIN.eckenMasken(R), LIN.auslaufMasken(R)) end
    LOGO.malen(R)
    return gemalt
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
    local v = d and d.getPreference and tonumber(d.getPreference("color"))   -- englische Schluessel (Regel der Betreuer)
    if v and BILDER[v] then farbeNr = floor(v) end
    local m = d and d.getPreference and tonumber(d.getPreference("mode"))   -- 1 dunkel, 2 hell (configure.lua); ohne Eintrag bleibt der Modus
    if m ~= nil and (m == 2) ~= MODUS.hell then MODUS.setzen(m == 2) end
end

local farbeAblage = nil   -- ohne gemeinsame Tabelle haelt rfsuite savePreference nur im Speicher: dann schreibt das Theme die Farbe selbst, in zwei Wakeups (Datei, dann Meldung)
local function farbeDateiSchreiben()
    local laden = package.loaded["rfsuite.lib.require"]
    if type(laden) ~= "function" then return false end
    local ok, ablage = pcall(laden, "lib/settings_store.lua")
    if not ok or type(ablage) ~= "table" or type(ablage.setDashboardTheme) ~= "function" then return false end
    local einstellungen = ablage.load()
    ablage.setDashboardTheme(einstellungen, "novafly", {color = farbeNr, mode = MODUS.hell and 2 or 1})
    return ablage.save(einstellungen) == true
end
local function farbeMelden()                   -- gemeldet wird, was JETZT in der Datei steht: hat eine Einstellungsseite seit dem Schreiben gespeichert, gilt ihr Stand
    local laden = package.loaded["rfsuite.lib.require"]
    local okA, ablage = pcall(laden, "lib/settings_store.lua")
    local okB, bus = pcall(laden, "lib/bus.lua")
    if not (okA and type(ablage) == "table" and type(ablage.load) == "function") then return end
    if okB and type(bus) == "table" and type(bus.publish) == "function" then bus.publish("settings.update", ablage.load()) end
end
local function farbeAblageTakt()
    if farbeAblage == 1 then
        farbeAblage = 2
        local ok, geschrieben = pcall(farbeDateiSchreiben)
        if not (ok and geschrieben) then farbeAblage = nil end
    elseif farbeAblage == 2 then
        farbeAblage = nil
        pcall(farbeMelden)
    end
end

local function farbeWeiter()                   -- false, wenn die Farbe nirgends gespeichert wird: rfsuite 2.3.x haelt sie je Modell und hat ohne Verbindung kein Modell
    local neu = farbeNr % #BILDER + 1
    local d = dash()
    if d and d.savePreference then
        local ok, gespeichert = pcall(d.savePreference, "color", neu)
        if ok and gespeichert == false then return false end
    end
    farbeNr = neu
    farbeAblage = 1
    return true
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
    if cpuSrc ~= nil and quelleWert(cpuSrc) == nil then cpuSrc = nil end   -- Sensor verstummt: in 5 s neu suchen
    if cpuSrc == nil and CATEGORY_TELEMETRY_SENSOR then
        for _, n in ipairs(CPU_NAMEN) do
            local ok, src = pcall(system.getSource, {category = CATEGORY_TELEMETRY_SENSOR, name = n})
            if ok and src and quelleWert(src) ~= nil then cpuSrc, cpuName = src, n break end
        end
        if cpuSrc == nil then   -- die Liste des Senders durchgehen, wie NovaSetup (sensoren.lua): Namen vergleichen, dann die Kennung
            local ok, liste = pcall(system.getSources, CATEGORY_TELEMETRY_SENSOR)
            if ok and type(liste) == "table" then
                for _, src in ipairs(liste) do
                    local on, n = pcall(function() return src:name() end)
                    for _, wunsch in ipairs(CPU_NAMEN) do
                        if on and n == wunsch and quelleWert(src) ~= nil then cpuSrc, cpuName = src, n break end
                    end
                    if cpuSrc ~= nil then break end
                end
            end
        end
        if cpuSrc == nil then
            for _, q in ipairs(CPU_NAMEN.kennungen) do
                local src = sensorSuchen({q[1]})
                if src then cpuSrc, cpuName = src, q[2] break end
            end
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
local letzterFlug = {}   -- Strom-Hoechstwert, verbrauchte mAh und Bank des letzten Flugs: die Seiten vor und nach dem Flug lesen hier
local flug = {laeuft = false, ende = false, mahStart = nil, stromMax = nil, bank = {0, 0, 0}, uhr = nil}   -- der laufende Flug; die Uhr je Bank zaehlt scharf mit drehendem Rotor, ab dem Scharfmachen von null, nach dem Flug bleibt sie stehen
flug.sitzung = {}   -- Hoehe und Steigen/Sinken seit dem Verbinden, scharf oder nicht: die Seite links zeigt sie, solange hier kein Flug aufgezeichnet ist
local function celsius(v, fahrenheit) return fahrenheit and (v - 32) * 5 / 9 or v end   -- die Farbgrenzen stehen in °C
local function gradZeichen(fahrenheit) return fahrenheit and "\194\176F" or "\194\176C" end

function flug.hoehe(t, alt, jetzt)   -- die hoechste Hoehe und das staerkste Steigen und Sinken, gerechnet aus der Hoehe ueber mindestens eine halbe Sekunde (t = flug oder flug.sitzung)
    if t.altMax == nil or alt > t.altMax then t.altMax = alt end
    if t.altZeit == nil then t.altVor, t.altZeit = alt, jetzt
    elseif jetzt - t.altZeit >= 0.5 then
        local rate = (alt - t.altVor) / (jetzt - t.altZeit)
        if t.steigMax == nil or rate > t.steigMax then t.steigMax = rate end
        if t.sinkMax == nil or rate < t.sinkMax then t.sinkMax = rate end
        t.altVor, t.altZeit = alt, jetzt
    end
end

function flug.letzteZeit()   -- die Flugzeit des letzten Flugs, wie die Suite sie je Modell merkt (lastflighttime in Sekunden, tasks/scheduler/timer/timer.lua); nil ohne Eintrag
    local ini = rf and rf.ini
    local prefs = rf and rf.session and rf.session.modelPreferences
    if type(ini) ~= "table" or type(ini.getvalue) ~= "function" or type(prefs) ~= "table" then return nil end
    local ok, v = pcall(ini.getvalue, prefs, "general", "lastflighttime")
    v = ok and tonumber(v) or nil
    if v ~= nil and v > 0 then return v end
    return nil
end

local function lesen(tele)
    local s = {link = tele.active and tele.active() or false}
    local mn = modellName()
    if mn ~= lebtModell then
        lebt, lebtModell, rpmHoch, cellF = {}, mn, 0, nil
        for k in pairs(schlepp) do schlepp[k] = nil end
        for k in pairs(flug.sitzung) do flug.sitzung[k] = nil end
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
        local function gTemp(k)   -- Temperaturen in der Einheit des Senders: bei Fahrenheit liefert rfsuite den Wert in °F und nennt die Einheit (zweiter bzw. dritter Rueckgabewert); Grenzen und Zeichen folgen ihr
            local v, a, b = tele.getSensor(k)
            local einheit = (type(a) == "string" and a:find("\194\176") and a) or (type(b) == "string" and b:find("\194\176") and b) or nil
            return tonumber(v), einheit == "\194\176F"
        end
        local tempEsc, escF = gTemp("temp_esc")
        s.temp, s.tempF = ohneNull("temp", tempEsc), escF
        local tempMcu, mcuF = gTemp("temp_mcu")
        s.mcutemp, s.mcutempF = tempMcu, mcuF
        if s.mcutemp ~= nil and (celsius(s.mcutemp, mcuF) < 10 or celsius(s.mcutemp, mcuF) > 130) then s.mcutemp = nil end
        local arm = g("armflags")
        if arm ~= nil then s.scharf = floor(arm) % 2 == 1 end
        s.bec = ohneNull("bec", becEcht(g("bec_voltage")))
        s.bank, s.rate = g("pid_profile"), g("rate_profile")
        s.last = ohneNull("last", g("current"))
        s.fuel = g("fuel")
        if s.fuel ~= nil and (s.fuel < 0 or s.fuel > 100) then s.fuel = nil end
        s.zellen = zellen
        s.verbrauch = g("consumption")
        local alt = g("altitude")
        if alt == nil and altSrc then alt = quelleWert(altSrc) end
        s.alt = ohneNull("alt", alt)
        local loc = rf and rf.preferences and rf.preferences.localizations   -- die Einheit, wie sie in der Suite eingestellt ist: rfsuite.preferences.localizations.altitude_unit 1 = Fuss (sensor_table.lua)
        s.altFt = (type(loc) == "table" and loc.altitude_unit == 1) or false
        if s.alt ~= nil and s.altFt then s.alt = s.alt * 3.28084 end
        if s.alt ~= nil then flug.hoehe(flug.sitzung, s.alt, os.clock()) end
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
    if s.scharf == true then   -- der Flug: Strom-Hoechstwert, Verbrauch und die Uhr je Bank laufen mit, bis der Heli entschaerft
        if not flug.laeuft then
            flug.laeuft, flug.mahStart, flug.stromMax, flug.bank, flug.uhr = true, s.verbrauch, nil, {0, 0, 0}, nil
            flug.altMax, flug.steigMax, flug.sinkMax, flug.altVor, flug.altZeit = nil, nil, nil, nil, nil
        end
        if s.last ~= nil and (flug.stromMax == nil or s.last > flug.stromMax) then flug.stromMax = s.last end
        local jetzt, b = os.clock(), s.bank and floor(s.bank) or nil
        if flug.uhr ~= nil and s.rpm ~= nil and s.rpm > 0 and b ~= nil and flug.bank[b] ~= nil then flug.bank[b] = flug.bank[b] + (jetzt - flug.uhr) end
        flug.uhr = jetzt
        if s.alt ~= nil then flug.hoehe(flug, s.alt, jetzt) end   -- die hoechste Hoehe und das staerkste Steigen und Sinken des Flugs
    elseif flug.laeuft then
        flug.laeuft, flug.ende, flug.uhr = false, true, nil
        letzterFlug = {strom = flug.stromMax, bank = s.bank and floor(s.bank) or nil,
                       mah = (s.verbrauch ~= nil and flug.mahStart ~= nil) and (s.verbrauch - flug.mahStart) or nil,
                       alt = flug.altMax, steig = flug.steigMax, sink = flug.sinkMax, zeit = flug.bank[1] + flug.bank[2] + flug.bank[3]}
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
    if s.scharf == true then return "ARMED", C_GREEN, SETC.feld end
    if s.scharf == false then return "DISARMED", C_RED, SETC.feld end
    return T.unbekannt, C_GRAY, C_WHITE
end

local function rpmAnteil(v)   -- der Wert als Anteil des Bogens (0 unten links, 1 rechts); die hoechste geflogene Drehzahl liegt bei 0,8
    if v == nil then return nil end
    local voll = max(BEZUG_OHNE_FLUG, rpmHoch) * 1.25
    if v < 0 then v = 0 elseif v > voll then v = voll end
    return v / voll
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

local MONITORE, TUEREN, LADER = {}, {}, {}   -- Monitore: Vollbilder ueber dem Cockpit; MONITORE[name] = {malen, ereignis, zurueck}, TUEREN = {zone, ziel}; LADER[name] laedt einen Schirm erst beim Oeffnen und gibt ihn beim Schliessen wieder frei
local monitorAktiv = nil
local SEITEN = {vorflug = -1, baenke = 1}   -- die Seiten neben dem Cockpit: links die vor dem Flug, rechts die Baenke

local function monitorOeffnen(name)
    local m = MONITORE[name]
    if m == nil and LADER[name] then
        collectgarbage("collect")   -- erst Platz machen: rfsuite und NovaSetup teilen sich mit dem Theme 2 MB (am X18 gesehen)
        m = LADER[name]()
    end
    if m == nil then return false end
    if m.oeffnen then
        local ok, auf = pcall(m.oeffnen)
        if not ok or auf == false then return false end
    end
    MONITORE[name], monitorAktiv = m, name
    return true
end

local function monitorZu()
    local name = monitorAktiv
    local m = name and MONITORE[name]
    monitorAktiv = nil
    if m and m.verlassen then m.verlassen() end
    if name and LADER[name] then
        MONITORE[name] = nil
        collectgarbage("collect")   -- die Seite ist frei: ihr Speicher soll jetzt gehen, nicht irgendwann (am X18 gesehen)
    end
end

local function malen(x, y, w, h, s)
    ox, oy, fx, fy = x, y, w / 480, h / 320
    kursivAn = false   -- Senderschrift (Regel der Betreuer); die Masken bleiben nur als Lader im Code
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
    beschriftungMittig(58, 77, T.timer, C_WHITE, F_SM)
    if s.timer ~= nil then timerZeile(U.timer, "", fmtT(s.timer), C_LGREEN) else timerZeile(U.timer, "", "--:--", C_DIM) end   -- die drei Striche darunter sind weg

    local bf = (s.bank ~= nil and s.rate ~= nil and s.bank ~= s.rate) and C_LRED or C_LGREEN
    if s.bank ~= nil then wert(U.bank, fmt(s.bank, "", 0), bf) else wert(U.bank, "?", C_DIM) end
    if s.rate ~= nil then wert(U.rate, fmt(s.rate, "", 0), bf) else wert(U.rate, "?", C_DIM) end

    if s.alt ~= nil then wert2(U.alt, fmt(s.alt, "", 0), s.altFt and "ft" or "m", C_LGREEN) else wert(U.alt, "--", C_DIM) end

    local R = rahmen()
    if R then R.tacho(LIN.M, linien(farbeNr), R.GROSS, GAUGE.cx, GAUGE.cy, rpmAnteil(s.rpm)) end   -- Bogen, Teilstriche und der Pfeil wie gehabt
    if s.modell then
        local name = (#s.modell > 16) and s.modell:sub(1, 16) or s.modell
        local b, h = mass(name, U.modelname.f)
        textZug(X(U.modelname.x) - floor(b / 2), Y(U.modelname.y + 10) - h / 2, name, C_WHITE, U.modelname.f)
    end
    if s.rpm then wert(U.rpm, fmt(s.rpm, "", 0), C_LGREEN, 16) end

    if s.bec then wert2(U.bec, fmt(s.bec, "", 1), "V", (s.bec >= 5.0) and C_LGREEN or C_YELLOW) else wert(U.bec, "--", C_DIM) end
    if s.tx then
        wert2(U.tx, fmt(s.tx, "", 1), "V", (s.tx >= 7.4) and C_LGREEN or ((s.tx >= 7.0) and C_YELLOW or C_LRED))
    else wert(U.tx, "--", C_DIM) end
    if s.last then wert2(U.amp, fmt(s.last, "", 1), "A", C_LGREEN) else wert(U.amp, "--", C_DIM) end
    beschriftungMittig(289, 59, (cpuName == "RT Load") and "RT" or "CPU", C_WHITE, F_SM)
    if s.cpu then
        wert2(U.cpu, fmt(s.cpu, "", 0), "%", (s.cpu < 50) and C_LGREEN or ((s.cpu < 80) and C_YELLOW or C_LRED), 8)
    else wert(U.cpu, "--", C_DIM, 8) end

    local sperre = os.clock() < gesperrtBis
    local cv = s.cellF or s.cell
    local packEnde = nil
    if s.pack and not sperre then packEnde = wert2(U.pack, fmt(s.pack, "", 1), "V", SETC[cellKey(cv)], 16) end
    local p = s.fuel   -- der Stand, wie die Suite ihn rechnet (derselbe wie die Balken im Tank); ohne fuel-Sensor aus der Zelle geschaetzt
    if p == nil and cv then p = (cv - 3.5) / 0.7 * 100 end
    if p ~= nil and not sperre then
        if p < 0 then p = 0 elseif p > 100 then p = 100 end
        local text, font = fmt(p, "", 0), U.battpct.f
        if packEnde ~= nil and X(U.battpct.x) - (mass(text, font) + max(1, sx(2)) + mass("%", font)) < packEnde + sx(8) then font = F_BIG end   -- 100 % liefe sonst in das V der Spannung: eine Schrift kleiner, dieselbe Lage
        wert2(U.battpct, text, "%", SETC[cellKey(cv)], 16, font)
    end
    local bars, hc = cellBars(cv, U.batt.n), SETC[cellKey(cv)]
    for i = 1, bars do flaeche(U.batt.x, U.batt.y - (i - 1) * (U.batt.bh + U.batt.gap), U.batt.bw, U.batt.bh, hc) end
    if s.fuel then   -- der Tank: der Verbrauch gegen die Akkukapazitaet, im Rahmen unter ESC, Farbe wie der Akku-Balken; ohne Sensor bleibt der Rahmen leer
        for i = 1, floor(s.fuel / (100 / U.tank.n)) do   -- 100 % durch die vier Balken: je volles Viertel ein Balken
            flaeche(U.tank.x + (i - 1) * (U.tank.bw + U.tank.gap), U.tank.y, U.tank.bw, U.tank.bh, hc)
        end
    end

    if s.temp then
        local tc = celsius(s.temp, s.tempF)
        wert2(U.temp, fmt(s.temp, "", 0), gradZeichen(s.tempF), (tc < 60) and C_LGREEN or ((tc < 80) and C_YELLOW or C_LRED))
    else wert(U.temp, "--", C_DIM) end
    if s.mcutemp then
        local tc = celsius(s.mcutemp, s.mcutempF)
        wert2(U.mcutemp, fmt(s.mcutemp, "", 0), gradZeichen(s.mcutempF), (tc < 70) and C_LGREEN or ((tc < 90) and C_YELLOW or C_LRED), 8)
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
    elseif farbeWeiter() then
        ton(880, 120)
    else
        ton(200, 90)                               -- nichts gespeichert, nichts gewechselt
    end
end

local function langdruckPruefen()
    local d = druck
    if d == nil or d.zone ~= "header" or os.clock() - d.seit < LANG then return end
    kopfLang()
end

local erstesWach = true
local SEITEN_WORTE = {"GOVERNOR", "DREHZAHL", "HOCHLAUF", "GAIN", "IST", "BANK", "RATE", "ROLL", "NICK", "HECK", "KOLL.",
                      "AKKU", "ZELLE", "VERBRAUCH", "HOEHE MAX", "STEIGEN MAX", "SINKEN MAX", "FLUGZEIT", "PID", "RATEN", "MSP"}
local wortVorrat = 1   -- die Woerter der Seiten, je Wakeup eines vorab uebersetzt: sonst uebersetzt das erste Malen einer Seite alle auf einmal (Rechenschritte)
local function wach(box, tele)
    if erstesWach then erstesWach = false   -- der erste Wakeup traegt schon das Laden dieser Datei
    elseif tabellenStufe < 2 then tabellenSchritt()
    elseif farbeAblage ~= nil then farbeAblageTakt()
    elseif SPRACHE ~= nil and wortVorrat <= #SEITEN_WORTE then
        pcall(SPRACHE.wort, SEITEN_WORTE[wortVorrat])
        wortVorrat = wortVorrat + 1
    end
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
    if flug.ende then   -- nach dem Flug geht die Bankseite von selbst auf
        flug.ende = false
        if monitorAktiv == nil then monitorOeffnen("baenke") end
    end
    local m = monitorAktiv and MONITORE[monitorAktiv]
    if m and m.takt then m.takt() end
    return st
end

local function trifft(z, x, y)
    return x ~= nil and y ~= nil and x >= X(z.x) and x < X(z.x) + sx(z.w) and y >= Y(z.y) and y < Y(z.y) + sy(z.h)
end

local wisch = nil   -- Wischen quer ueber freie Flaeche blaettert zwischen den Seiten (links davor, Mitte das Cockpit, rechts danach); senkrecht bleibt bei Ethos und der Suite; in einer offenen Seite gehoert jede Beruehrung dem Theme
local WISCH_WEIT, WISCH_ENTSCHEID = 50, 6
local function blaettern(richtung)   -- -1: nach links gewischt = die Seite danach; +1: nach rechts gewischt = die Seite davor
    local lage = monitorAktiv and SEITEN[monitorAktiv]
    if monitorAktiv == nil then return monitorOeffnen(richtung < 0 and "baenke" or "vorflug") end
    if lage == nil then return false end   -- ein Schirm ohne Seitenlage (BANK) blaettert nicht
    if (lage > 0 and richtung > 0) or (lage < 0 and richtung < 0) then monitorZu() return true end   -- zurueck zum Cockpit
    return false   -- ueber die Seite hinaus gibt es keine weitere
end
local function wischen(value, x, y, inSeite)   -- true = verbraucht, false = fuer Ethos, nil = kein Wischen (der Tipp laeuft weiter)
    if value == TOUCH_START then
        wisch = (x ~= nil and y ~= nil) and {x = x, y = y, quer = nil, bis = x} or nil
        return nil
    end
    if wisch == nil then return nil end
    if value == TOUCH_MOVE then
        if x == nil or y == nil then return nil end
        local dx, dy = x - wisch.x, y - wisch.y
        if wisch.quer == nil then
            if abs(dx) < WISCH_ENTSCHEID and abs(dy) < WISCH_ENTSCHEID then return true end   -- noch unentschieden: der Finger bleibt beim Theme
            if abs(dy) > abs(dx) then   -- senkrecht
                wisch = nil
                return inSeite and true or false
            end
            wisch.quer = true
        end
        wisch.bis = x
        return true
    end
    if value == TOUCH_END then
        local w = wisch
        wisch = nil
        if not w.quer then return nil end
        local dx = (x or w.bis) - w.x
        if dx <= -WISCH_WEIT then blaettern(-1) elseif dx >= WISCH_WEIT then blaettern(1) end
        return true   -- ein Wischen quer bleibt verbraucht, auch wenn es nichts blaettert
    end
    if TOUCH_LANG ~= nil and value == TOUCH_LANG then wisch = nil end
    return nil
end

local function ereignis(widget, category, value, x, y)
    if category ~= EVT_TOUCH then return false end
    local m = monitorAktiv and MONITORE[monitorAktiv]
    if m then   -- im Monitor gelten nur seine ZURUECK-Zone und sein eigenes Ereignis; die Cockpit-Zonen sind zu
        if value == TOUCH_START then
            druck = trifft(m.zurueck, x, y) and {zone = "zurueck", seit = os.clock(), x = x, y = y} or nil
            if druck == nil and m.seite then wischen(TOUCH_START, x, y, true) end
        elseif value == TOUCH_MOVE then
            if druck and x and y and (abs(x - druck.x) > DRIFT or abs(y - druck.y) > DRIFT) then druck = nil end
            if druck == nil and m.seite then wischen(TOUCH_MOVE, x, y, true) end
        elseif value == TOUCH_END and druck == nil and m.seite and wischen(TOUCH_END, x, y, true) then
            if widget then lcd.invalidate(widget) end
            return true
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
        if druck == nil then wischen(TOUCH_START, x, y, false) end   -- freie Flaeche: wird daraus ein Wischen quer, blaettert das Theme
        return druck ~= nil   -- setzt der Finger auf einer Zone auf, behaelt ihn das Theme
    end
    if value == TOUCH_MOVE then
        if druck and x and y and (abs(x - druck.x) > DRIFT or abs(y - druck.y) > DRIFT) then druck, fingerUnser = nil, false end
        if druck ~= nil then return true end   -- liegt der Finger noch auf seiner Zone, verbraucht das Theme die Bewegung: sonst nimmt Ethos ihn zum Blaettern und TOUCH_END bleibt aus
        local r = wischen(TOUCH_MOVE, x, y, false)
        return r == true
    end
    if value == TOUCH_END and druck == nil and wischen(TOUCH_END, x, y, false) then
        if widget then lcd.invalidate(widget) end
        return true
    end
    if value == TOUCH_LANG then   -- nach etwa einer Sekunde meldet Ethos den langen Druck selbst, ein TOUCH_END kommt danach nicht mehr
        wisch = nil
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

local kursivHelfer = {abgeschaltet = false, unfertig = false, fensterNeu = function() end}   -- die Kursivschrift fuer die Zeichenteile der Schirme (stil_teile.lua): messen geht immer, gemalt wird, sobald die Masken geladen sind
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

do   -- die Seiten neben dem Cockpit: eigene Dateien, bekommen den Schlepp-Merker, einen Merker ueber das Schliessen hinaus und rfsuite
    local HELFER = {trifft = trifft, ton = ton, schlepp = schlepp, kursiv = kursivHelfer, laden = laden, auslaufMasken = LIN.auslaufMasken, eckenMasken = LIN.eckenMasken, merk = {},
                    i18n = SPRACHE, rf = function() return rf end, stand = function() return st end,
                    oeffnen = function(name) return monitorOeffnen(name) end, zu = function() monitorZu() end,
                    farbe = function() return farbeNr end, bild = function() return BILDER[farbeNr] end,
                    hell = function() return MODUS.hell end, hellName = function() return MODUS.namen[MODUS.von[farbeNr] or 1] end,   -- der Modus und die helle Fassung der Farbe (fotorand_hell_<Name>.png)
                    grund = function() return GRUND.malen(farbeNr, rahmen()) end,   -- der Grund des Cockpits, ganz; die Seiten malen ihn zuerst
                    linien = function() return linien(farbeNr) end, rahmen = rahmen, bildPfad = bildPfad,
                    rpmVoll = function() return max(BEZUG_OHNE_FLUG, rpmHoch) * 1.25 end,   -- das Ende des Bogens, wie im Cockpit
                    flug = function() return letzterFlug end, bankZeit = function() return flug.bank end,
                    sitzung = function() return flug.sitzung end, letzteFlugzeit = flug.letzteZeit,   -- ohne Flug hier: die Hoechstwerte seit dem Verbinden und die letzte Flugzeit der Suite
                    farben = MODUS.seiten,   -- die Farben der Zahlen: dieselben Grenzen wie im Cockpit, nach dem Modus (MODUS.setzen fuellt die Tabelle neu)
                    zellFarbe = function(cell) return SETC[cellKey(cell)] end,
                    linkFarbe = function(s) return s.vfr and SETC[(s.vfr >= VFR_YEL) and "w" or ((s.vfr >= VFR_RED) and "y" or "r")] or C_WHITE end}
    local MODULE = {{"vorflug"}, {"baenke", {x = 20, y = 184, w = 92, h = 44}}}   -- Tuer: das BANK/RATE-Feld oeffnet die Bankseite; die Seite links hat keine Tuer, beide auch durch Wischen quer; bank.lua wird nicht mehr geladen
    for _, m in ipairs(MODULE) do
        LADER[m[1]] = function()
            local chunk = laden(loadfile, m[1] .. ".lua")
            if not chunk then return nil end
            local ok, mon = pcall(chunk, HELFER)
            if ok and type(mon) == "table" then return mon end
            return nil
        end
        if m[2] then TUEREN[#TUEREN + 1] = {zone = m[2], ziel = m[1]} end
    end
end

local BOX = {col = 1, row = 1, type = "func", wakeupinterval = 0.1, wakeup = wach, paint = function(x, y, w, h, box, cache) malen(x, y, w, h, cache) end}

local ZUSTAND = {layout = {cols = 1, rows = 1, padding = 0}, boxes = {BOX}, event = ereignis,
                 scheduler = {spread_scheduling = false, spread_scheduling_paint = false, spread_ratio = 1.0}}

return {zustand = function() return ZUSTAND end, malen = malen, lesen = lesen, wach = wach, ereignis = ereignis, BILDER = BILDER,
        monitore = MONITORE, tueren = TUEREN, monitorOeffnen = monitorOeffnen, monitorZu = monitorZu,
        aktiverMonitor = function() return monitorAktiv end}
