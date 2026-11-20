-- SEITEN-TEILE: was die zwei Seiten neben dem Cockpit (vorflug.lua, baenke.lua) gemeinsam malen - derselbe Grund wie das
-- Cockpit (Hochglanz, Carbon oder hell, cockpit.lua GRUND), die Linien des Cockpits laufen vom Cockpit her ins Bild und klingen aus
-- (oben am weitesten, unten kurz, rahmen.lua AUSLAUF), Chips aus denselben Linien mit Ecken r 4, Zeilen aus Zahl und Einheit.
-- Die Farben kommen vom Cockpit (H.linien, H.hell), die Linien und Ecken malt rahmen.lua.
local A = ...   -- {H = die Helfer des Cockpits, stil = stil_teile}
local H, stil = A.H, A.stil
local floor = math.floor

local S = {}
S.KOPF = {y = 8, h = 40}      -- die Baender zwischen den Linien, aus tacho_base.png gemessen: Kopf, Mitte, Fuss
S.MITTE = {y = 59, h = 188}
S.FUSS = {y = 258, h = 54}
S.SCHWARZ = lcd.RGB(0, 0, 0)
local URSPRUNG = {WEISS = stil.WEISS, LEISE = stil.LEISE, FELD_LEISE = stil.FELD_LEISE, ROT = stil.ROT}   -- die Farben der Zeichenteile auf dunklem Grund, wie stil_teile.lua sie setzt
local HELL = {WEISS = lcd.RGB(20, 20, 19), LEISE = lcd.RGB(95, 107, 120), FELD_LEISE = lcd.RGB(95, 107, 120), ROT = lcd.RGB(200, 32, 32)}   -- auf hellem Grund: Schrift dunkel, Leise und Rot wie im Cockpit (cockpit.lua PALETTE)
local modusGesetzt = nil
local M = {X = stil.sx, Y = stil.sy, sx = stil.sx, sy = stil.sy}   -- das Fenster der Seite fuer rahmen.lua: die Umrechner von stil_teile selbst, ohne Zwischenruf (Rechenschritte je Malen); M.q haengt rahmen.lua an (R.frisch)

local function suiteModul(pfad)   -- ein Modul der Suite ueber ihren Lader; nil ohne Lader (rfsuite 2.3.x) oder ohne das Modul
    local lader = package.loaded["rfsuite.lib.require"]
    if type(lader) ~= "function" then return nil end
    local ok, m = pcall(lader, pfad)
    if ok and type(m) == "table" then return m end
    return nil
end

function S.busLesen(codecPfad, fertig)   -- ein Satz ueber den Bus "msp.request" der Suite mit ihrem Codec; fertig(werte) einmal, nil bei Fehler; false, wenn nichts abging
    local bus, codec = suiteModul("lib/bus.lua"), codecPfad and suiteModul(codecPfad) or nil
    if bus == nil or type(bus.publish) ~= "function" or codec == nil or type(codec.buildReadMessage) ~= "function" then return false end
    local einmal = false
    local function ende(w)
        if einmal then return end
        einmal = true
        fertig(w)
    end
    local ok, nachricht = pcall(codec.buildReadMessage, function(d) ende(type(d) == "table" and d or nil) end, function() ende(nil) end)
    if not ok or type(nachricht) ~= "table" or not pcall(bus.publish, "msp.request", nachricht) then einmal = true return false end
    return true
end

function S.hell() return type(H.hell) == "function" and H.hell() == true end   -- der Modus des Cockpits

local function farben()   -- die Farben der Zeichenteile nach dem Modus, vor jedem Grund: Beschriftungen, Einheiten, Soll-Linie und Schleppmarke werden auf Weiss dunkel
    local hell = S.hell()
    if modusGesetzt == hell then return end
    modusGesetzt = hell
    local q = hell and HELL or URSPRUNG
    stil.WEISS, stil.LEISE, stil.FELD_LEISE, stil.ROT = q.WEISS, q.LEISE, q.FELD_LEISE, q.ROT
end

function S.wort(text)   -- in der Sprache des Senders; ohne Eintrag bleibt es deutsch
    local t = H.i18n
    if t ~= nil and type(t.wort) == "function" then return t.wort(text) end
    return text
end

function S.mass() return M end

function S.endung()   -- die Endung der Bilddateien dieser Schirmgroesse (rahmen.lua R.endung): "", "_640" oder "_800"
    local R = H.rahmen()
    return R and R.endung(M) or ""
end

function S.grund()   -- der Grund des Cockpits (H.grund: Hochglanz, Carbon oder hell), ganz; ohne das Bild tiefschwarz; davor die Masse der Linien zum Fenster, einmal je Bild
    farben()
    local R = H.rahmen()
    if R then R.frisch(M) end
    if type(H.grund) == "function" and H.grund() then return end
    lcd.color(S.SCHWARZ)
    lcd.drawFilledRectangle(stil.sx(0), stil.sy(0), stil.sx(480), stil.sy(320))
end

function S.linien(links)   -- die fuenf Linien des Cockpits, auslaufend als Masken ueber dem Grund; links = die Seite links vom Cockpit
    local R = H.rahmen()
    if R then R.seite(M, H.linien(), links, type(H.auslaufMasken) == "function" and H.auslaufMasken(R) or nil) end
end
function S.chip(x, y, w, h, offen)   -- ein Viereck aus den Linien des Cockpits mit Ecken r 4 (Masken); offen = "links" oder "rechts": ohne diese Kante, die Linien laufen zum Schirmrand
    local R = H.rahmen()
    if not R then return end
    local F = H.linien()
    local E = type(H.eckenMasken) == "function" and H.eckenMasken(R) or nil
    local r = 4
    local x0 = (offen == "links") and 0 or (x + r)
    local x1 = (offen == "rechts") and 480 or (x + w - r)
    R.waagrecht(M, F, y, x0, x1)
    R.waagrecht(M, F, y + h, x0, x1)
    if offen ~= "links" then
        R.senkrecht(M, F, x, y + r, y + h - r)
        R.ecke(M, F, x + r, y + r, r, 270, 360, E)
        R.ecke(M, F, x + r, y + h - r, r, 180, 270, E)
    end
    if offen ~= "rechts" then
        R.senkrecht(M, F, x + w, y + r, y + h - r)
        R.ecke(M, F, x + w - r, y + r, r, 0, 90, E)
        R.ecke(M, F, x + w - r, y + h - r, r, 90, 180, E)
    end
end

function S.flaeche(x, y, w, h, farbe)
    lcd.color(farbe)
    lcd.drawFilledRectangle(stil.sx(x), stil.sy(y), stil.sx(w), stil.sy(h))
end

local function zeileMalen(x, cy, segs, breite, hoehe)   -- die Stuecke nebeneinander, unten buendig, die Zeile um cy mittig
    local oben = stil.sy(cy) - floor(hoehe / 2)
    for i = 1, #segs do
        local sg = segs[i]
        local b, h = stil.mass(sg[1], sg[3] or FONT_S)
        stil.textZug(x, oben + hoehe - (h or hoehe) - (i > 1 and 1 or 0), sg[1], sg[2], sg[3] or FONT_S)
        x = x + b + 4
    end
    return breite
end

local function zeileMass(segs)
    local breite, hoehe = -4, 0
    for i = 1, #segs do
        local b, h = stil.mass(segs[i][1], segs[i][3] or FONT_S)
        breite = breite + b + 4
        if (h or 0) > hoehe then hoehe = h end
    end
    return breite, hoehe
end

function S.zeile(cx, cy, segs)   -- eine Zeile aus Stuecken {text, farbe, font}, zusammen mittig um cx: die Zahl gross, die Einheit klein dahinter
    local b, h = zeileMass(segs)
    zeileMalen(stil.sx(cx) - floor(b / 2), cy, segs, b, h)
end

function S.zeileLinks(x, cy, segs)
    local b, h = zeileMass(segs)
    zeileMalen(stil.sx(x), cy, segs, b, h)
end

function S.zeileRechts(rx, cy, segs)
    local b, h = zeileMass(segs)
    zeileMalen(stil.sx(rx) - b, cy, segs, b, h)
end

return S
