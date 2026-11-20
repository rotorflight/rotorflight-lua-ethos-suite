-- RAHMEN des Themes: die Linien des Cockpits als Code auf dem einen Grund. Masse aus der Vorlage 480 x 320: Kopfband mit
-- Absatz, drei Felder, Fussreihe, Ecken, Tacho-Bogen, Teilstriche. Eine Linie ist drei Punkte Mittelton mit einem Punkt hellem
-- Kern und aussen je einem Punkt Schein; auf 800 x 480 zwei Punkte Kern, vier Mittelton, sechs Schein (masse). Alles ueber
-- M = {X, Y, sx, sy} (Lage und Mass des Fensters) und F = {mitte, kern, schein, auslauf} (Farben des Bilds, cockpit.lua linien).
-- Der grosse Tacho traegt den Pfeil, die kleinen der Bankseite einen Balken; auf den Seiten laufen die Linien des Cockpits zum
-- Rand hin aus, und die Linien der Seiten kommen vom Rand her ins Cockpit und laufen dort aus (Stacheln): drei Bilder, die zusammengehoeren.
local R = {}
local floor, sin, cos, rad, min = math.floor, math.sin, math.cos, math.rad, math.min

R.GRUEN, R.GELB, R.ROT = lcd.RGB(12, 228, 16), lcd.RGB(245, 224, 26), lcd.RGB(240, 35, 12)
R.GRAU, R.NADEL = lcd.RGB(134, 138, 145), lcd.RGB(255, 80, 80)
local MODUS = {{R.GRUEN, R.GELB, R.ROT, R.GRAU, R.NADEL},   -- Bogen, Zonen, Teilstriche und Pfeil je Modus: dunkel wie aus den Bildern gemessen; hell dunkler, damit Gelb und Gruen auf Weiss stehen
               {lcd.RGB(20, 170, 40), lcd.RGB(214, 170, 0), lcd.RGB(215, 30, 20), lcd.RGB(150, 154, 160), lcd.RGB(215, 30, 20)}}
function R.modus(hell)                   -- cockpit.lua ruft es vor jedem Grund (GRUND.malen): die Farben des Modus, bevor eine Linie faellt
    hell = hell == true
    if R.hell == hell then return end
    R.hell = hell
    local m = MODUS[hell and 2 or 1]
    R.GRUEN, R.GELB, R.ROT, R.GRAU, R.NADEL = m[1], m[2], m[3], m[4], m[5]
end
R.GROSS = {r = 101, anfang = -104.4, ende = 104.4, teile = {-104.4, 104.4, 49, 7, 4}, nadel = {60, 88}}   -- die zwei Tachos: Bogen (anfang, ende; 0 = oben, im Uhrzeigersinn), Teilstriche (von, bis, Anzahl, lang, kurz); gruen bis 78 %, gelb bis 90 %, dann rot
R.KLEIN = {r = 47, anfang = -135, ende = 100, teile = {-135, 100, 29, 5, 3}, balken = 4}          -- die Bankseite
R.STUFEN = 12                            -- Stufen, in denen eine Linie auslaeuft (Farben: cockpit.lua linien, F.auslauf - dort dieselbe Zahl)
R.AUSLAUF_LINKS = {{5, 394}, {55, 200}, {250, 225}, {255, 215}, {314, 120}}   -- je Linie einer Seite: Zeile und wie weit sie vom Cockpit her ins Bild reicht (oben am weitesten, unten kurz); links endet die Linie bei 55 vor dem Foto (x 0-259)
R.AUSLAUF_RECHTS = {{5, 394}, {55, 330}, {250, 225}, {255, 215}, {314, 120}}
R.AUSLAUF_WEICH = 120                    -- Laenge des Verlaufs am Ende einer Linie (bei kurzen Linien 80 % der Linie, R.weich)
R.STACHELN = {links = {{66, 105}, {240, 60}, {262, 45}, {310, 24}}, rechts = {{66, 105}, {124, 60}, {136, 45}, {240, 24}}}   -- die Linien der Seiten, die am Rand ihrer Seite enden und im Cockpit weiterlaufen: von links der AKKU-Kasten (66, 240) und der Fusschip (262, 310) der Vorflugseite, von rechts die Chips der Bankseite (66, 124, 136, 240); je Zeile, wie weit die Linie vom Schirmrand her ins Cockpit reicht - voll am Rand, dann auslaufend, der oberste der laengste, links und rechts gleich (Kevin 20.11.: 'Die Striche muessen von rechts nach links und von links nach rechts in das Bild in der Mitte hineinkommen, nicht umgekehrt. Und da auslaufen.')
R.ABSATZ = {x = 114, y = 34, dateien = {"absatz_schein", "absatz_mitte", "absatz_kern"}}   -- der Absatz oben am Mittelfeld als geglaettete Maske in drei Lagen (gfx/<Name><Endung>.png); Rundung r 5 oben, r 4 an den Seitenlinien
R.ECKE = {{n = 7, nah = 2, fern = 4}, {n = 10, nah = 2, fern = 6}}   -- die Ecken-Masken je Schirmgroesse (gfx/ecke_<Lage>_<Ort><Endung>.png): Kantenlaenge, Abstand des Kerns vom nahen und vom fernen Rand der Maske

function R.frisch(M)                     -- die Masse der Linien zum Fenster M, einmal je Bild gerechnet (seite_teile.lua S.grund, cockpit.lua bildMalen) und an M gehaengt (M.q; kein Merker mit M als Schluessel - Lua-Speicher je Seite, 20.11.): 480 x 320: Kern 1, Mittelton 3, Schein 5 in der Lage von M; ab 700 Punkten Breite (800 x 480): Kern 2, Mittelton 4, Schein 6, die Lage als erste Spalte und Zeile des Kerns - Spalte x0 + (x*w+160)/480, Zeile y0 + (y*h+80)/320 abgerundet, x0/y0 die Lage des Fensters
    local w, h, x0, y0 = M.sx(480), M.sy(320), M.X(0), M.Y(0)
    local q = M.q
    if q and q.w == w and q.h == h and q.x0 == x0 and q.y0 == y0 then return q end
    if w < 700 then
        q = {w = w, h = h, x0 = x0, y0 = y0, k = 1, endung = "", ecke = R.ECKE[1], x = M.X, y = M.Y}
    else
        q = {w = w, h = h, x0 = x0, y0 = y0, k = 2, endung = "_800", ecke = R.ECKE[2],
             x = function(v) return x0 + floor((v * w + 160) / 480) end,
             y = function(v) return y0 + floor((v * h + 80) / 320) end}
    end
    M.q = q
    return q
end

local function masse(M)                  -- die Masse aus M, ohne Rechnung (jeder Zeichenbefehl geht hier durch: Rechenschritte je Malen, Kevin 20.11. 'Max instructions count reached' auf 800 x 480)
    return M.q or R.frisch(M)
end

function R.endung(M) return masse(M).endung end   -- die Endung der Maskendateien dieser Schirmgroesse: "" oder "_800"

function R.waagrecht(M, F, y, x0, x1)    -- Kern in Zeile y, Mittelton eine Zeile darueber und darunter, aussen je eine Zeile Schein (auf 800 x 480 der Kern zwei Zeilen)
    local q = masse(M)
    local X, Y, k = q.x(x0), q.y(y), q.k
    local w = q.x(x1) - X
    lcd.color(F.schein)
    lcd.drawFilledRectangle(X, Y - 2, w, k + 4)
    lcd.color(F.mitte)
    lcd.drawFilledRectangle(X, Y - 1, w, k + 2)
    lcd.color(F.kern)
    lcd.drawFilledRectangle(X, Y, w, k)
end

function R.senkrecht(M, F, x, y0, y1)
    local q = masse(M)
    local X, Y, k = q.x(x), q.y(y0), q.k
    local h = q.y(y1) - Y
    lcd.color(F.schein)
    lcd.drawFilledRectangle(X - 2, Y, k + 4, h)
    lcd.color(F.mitte)
    lcd.drawFilledRectangle(X - 1, Y, k + 2, h)
    lcd.color(F.kern)
    lcd.drawFilledRectangle(X, Y, k, h)
end

function R.schraeg(M, F, x0, y0, x1, y1)
    lcd.color(F.schein)
    for d = -2, 2 do lcd.drawLine(M.X(x0), M.Y(y0 + d), M.X(x1), M.Y(y1 + d)) end
    lcd.color(F.mitte)
    for d = -1, 1 do lcd.drawLine(M.X(x0), M.Y(y0 + d), M.X(x1), M.Y(y1 + d)) end
    lcd.color(F.kern)
    lcd.drawLine(M.X(x0), M.Y(y0), M.X(x1), M.Y(y1))
end

function R.ecke(M, F, cx, cy, r, a0, a1, E)   -- eine runde Ecke r 4 um (cx, cy) als Maske je Lage (E aus cockpit.lua): Ethos malt einen Ring einschliesslich beider Radien, ein Kern von einem Punkt ist so nicht zu haben; ohne Masken Ringstuecke
    if E then
        local q = masse(M)
        local ort = (a0 == 270) and "lo" or ((a0 == 0) and "ro" or ((a0 == 90) and "ru" or "lu"))
        local links, oben = (ort == "lo" or ort == "lu"), (ort == "lo" or ort == "ro")
        local m, e = E[ort], q.ecke
        local X = q.x(links and (cx - r) or (cx + r)) - (links and e.nah or e.fern)   -- die Maske liegt an den zwei Linien, die sie verbindet: der senkrechten bei cx -+ r, der waagrechten bei cy -+ r
        local Y = q.y(oben and (cy - r) or (cy + r)) - (oben and e.nah or e.fern)
        lcd.color(F.schein)
        lcd.drawMask(X, Y, m.schein)
        lcd.color(F.mitte)
        lcd.drawMask(X, Y, m.mitte)
        lcd.color(F.kern)
        lcd.drawMask(X, Y, m.kern)
        return
    end
    lcd.color(F.schein)
    lcd.drawAnnulusSector(M.X(cx), M.Y(cy), M.sx(r - 2), M.sx(r + 2), a0, a1)
    lcd.color(F.mitte)
    lcd.drawAnnulusSector(M.X(cx), M.Y(cy), M.sx(r - 1), M.sx(r + 1), a0, a1)
    lcd.color(F.kern)
    lcd.drawAnnulusSector(M.X(cx), M.Y(cy), M.sx(r), M.sx(r + 1), a0, a1)
end

function R.rechteck(M, F, x, y, w, h)    -- ein duenner Rahmen im Kern (Tank, Batterie)
    lcd.color(F.kern)
    lcd.drawRectangle(M.X(x), M.Y(y), M.sx(w), M.sy(h))
end

function R.weich(weit) return min(R.AUSLAUF_WEICH, floor(weit * 0.8)) end   -- wie lang eine Linie der Seiten auslaeuft, die weit ins Bild reicht

function R.auslaufLaengen()              -- die Laengen des Auslaufs, die auf den Seiten und an den Stacheln des Cockpits vorkommen (fuer die Masken)
    local t, da = {}, {}
    local function merken(l)
        if not da[l] then da[l] = true t[#t + 1] = l end
    end
    for _, tab in ipairs({R.AUSLAUF_LINKS, R.AUSLAUF_RECHTS}) do
        for _, l in ipairs(tab) do merken(R.weich(l[2])) end
    end
    for _, tab in ipairs({R.STACHELN.links, R.STACHELN.rechts}) do
        for _, s in ipairs(tab) do merken(s[2]) end
    end
    return t
end

function R.auslaufend(M, F, y, x0, x1, nachLinks, A)   -- die Linie laeuft zwischen x0 und x1 aus: voll bei x1 (nachLinks) bzw. x0, am anderen Ende nichts; A = die Masken je Richtung und Laenge (cockpit.lua) - der Grund bleibt darunter; ohne Masken Stufen voller Rechtecke auf F.auslauf
    local q = masse(M)
    local X0, X1, Y, k = q.x(x0), q.x(x1), q.y(y), q.k
    local m = A and A[nachLinks and "links" or "rechts"][x1 - x0]
    if m then
        lcd.color(F.schein)
        lcd.drawMask(X0, Y - 2, m.schein)
        lcd.color(F.mitte)
        lcd.drawMask(X0, Y - 1, m.mitte)
        lcd.color(F.kern)
        lcd.drawMask(X0, Y, m.kern)
        return
    end
    local breite = (X1 - X0) / R.STUFEN
    local b = floor(breite) + 1
    for i = 0, R.STUFEN - 1 do
        local stufe = F.auslauf[nachLinks and (i + 1) or (R.STUFEN - i)]
        local x = floor(X0 + i * breite + 0.5)
        lcd.color(stufe[3])
        lcd.drawFilledRectangle(x, Y - 2, b, k + 4)
        lcd.color(stufe[1])
        lcd.drawFilledRectangle(x, Y - 1, b, k + 2)
        lcd.color(stufe[2])
        lcd.drawFilledRectangle(x, Y, b, k)
    end
end

function R.seite(M, F, links, A)         -- die fuenf Linien einer Seite: vom Cockpit her ins Bild, dann auslaufend (A = die Auslauf-Masken)
    for _, l in ipairs(links and R.AUSLAUF_LINKS or R.AUSLAUF_RECHTS) do
        local y, weit = l[1], l[2]
        local weich = R.weich(weit)
        if links then
            R.waagrecht(M, F, y, 480 - weit + weich, 480)
            R.auslaufend(M, F, y, 480 - weit, 480 - weit + weich, true, A)
        else
            R.waagrecht(M, F, y, 0, weit - weich)
            R.auslaufend(M, F, y, weit - weich, weit, false, A)
        end
    end
end

function R.absatz(M, F, masken)          -- der Absatz mit Anlauf und Rundungen: als Maske in drei Lagen, ohne Masken als Striche
    if masken then
        local q = masse(M)
        local X, Y = q.x(R.ABSATZ.x), q.y(R.ABSATZ.y)
        lcd.color(F.schein)
        lcd.drawMask(X, Y, masken.schein)
        lcd.color(F.mitte)
        lcd.drawMask(X, Y, masken.mitte)
        lcd.color(F.kern)
        lcd.drawMask(X, Y, masken.kern)
        return
    end
    R.schraeg(M, F, 141, 50, 175, 40)
    R.waagrecht(M, F, 40, 175, 306)
    R.schraeg(M, F, 306, 40, 341, 50)
    R.schraeg(M, F, 141, 50, 125, 56)
    R.ecke(M, F, 125, 60, 4, 270, 360)
    R.ecke(M, F, 354, 60, 4, 0, 90)
    R.schraeg(M, F, 341, 50, 354, 56)
end

function R.stacheln(M, F, A)             -- die Stacheln (R.STACHELN): die Linien der Seiten kommen vom Schirmrand her ins Cockpit, voll am Rand, und laufen aus wie die Linien auf den Seiten (A = die Auslauf-Masken; ohne Masken Stufen)
    for _, s in ipairs(R.STACHELN.links) do R.auslaufend(M, F, s[1], 0, s[2], false, A) end
    for _, s in ipairs(R.STACHELN.rechts) do R.auslaufend(M, F, s[1], 480 - s[2], 480, true, A) end
end

function R.cockpit(M, F, masken, E, A)   -- der ganze Rahmen des Cockpits, links und rechts offen (die Linien laufen bis zum Rand und auf den Seiten weiter); E = die Ecken-Masken, A = die Auslauf-Masken der Stacheln
    local function ecke(cx, cy, a0, a1) R.ecke(M, F, cx, cy, 4, a0, a1, E) end
    R.waagrecht(M, F, 5, 0, 480)
    R.absatz(M, F, masken)   -- das Kopfband hat unten keine Linie neben dem Mittelfeld; der Absatz: von (141,50) hinauf auf 40, 175-306, hinab auf (341,50)
    R.stacheln(M, F, A)   -- die Linien der Seiten, die ins Cockpit hereinkommen
    R.waagrecht(M, F, 55, 0, 112)   -- das linke Feld (bis x 116) und das rechte (ab 363), Ecken r 4
    ecke(112, 59, 0, 90)
    R.senkrecht(M, F, 116, 59, 246)
    ecke(112, 246, 90, 180)
    R.waagrecht(M, F, 250, 0, 112)
    R.waagrecht(M, F, 55, 367, 480)
    ecke(367, 59, 270, 360)
    R.senkrecht(M, F, 363, 59, 246)
    ecke(367, 246, 180, 270)
    R.waagrecht(M, F, 250, 367, 480)
    R.senkrecht(M, F, 121, 60, 248)   -- das Mittelfeld (x 121-358): vom Absatz mit Rundung r 4 in die Seitenlinie, der Knick auf der Oberkante der Seitenfelder; unten bei 252, die Fussreihe liegt bei 255 an
    ecke(125, 248, 180, 270)
    R.waagrecht(M, F, 252, 125, 354)
    ecke(354, 248, 90, 180)
    R.senkrecht(M, F, 358, 60, 248)
    R.waagrecht(M, F, 255, 0, 113)   -- die Fussreihe (y 255-314): drei Felder, links und rechts offen, Ecken r 4
    ecke(113, 259, 0, 90)
    R.senkrecht(M, F, 117, 259, 310)
    ecke(113, 310, 90, 180)
    R.waagrecht(M, F, 314, 0, 113)
    R.waagrecht(M, F, 255, 125, 354)
    ecke(125, 259, 270, 360)
    R.senkrecht(M, F, 121, 259, 310)
    ecke(125, 310, 180, 270)
    R.waagrecht(M, F, 314, 125, 354)
    ecke(354, 259, 0, 90)
    R.senkrecht(M, F, 358, 259, 310)
    ecke(354, 310, 90, 180)
    R.waagrecht(M, F, 255, 366, 480)
    ecke(366, 259, 270, 360)
    R.senkrecht(M, F, 362, 259, 310)
    ecke(366, 310, 180, 270)
    R.waagrecht(M, F, 314, 366, 480)
    R.rechteck(M, F, 136, 267, 20, 35)   -- die Batterie unten (ihre Balken malt das Cockpit); die Balken des Tanks stehen frei, ohne Kasten
    lcd.color(F.kern)
    lcd.drawFilledRectangle(M.X(142), M.Y(263), M.sx(8), M.sy(4))
end

local STRICHE = {}                       -- die Teilstriche je Tacho und Lage, fertig in Fensterpixeln, einmal gerechnet
local function striche(M, art, cx, cy)
    local X, Y = M.X(cx), M.Y(cy)
    local key = art.r .. "|" .. X .. "|" .. Y .. "|" .. M.sx(1000)
    local t = STRICHE[key]
    if t then return t end
    local von, bis, n, lang, kurz = art.teile[1], art.teile[2], art.teile[3], art.teile[4], art.teile[5]
    local ra = art.r - 4
    t = {}
    for i = 0, n - 1 do
        local a = rad(von + i * (bis - von) / (n - 1))
        local l = (i % 4 == 0) and lang or kurz
        local dx, dy = sin(a), -cos(a)
        t[#t + 1] = {M.X(cx + dx * ra), M.Y(cy + dy * ra), M.X(cx + dx * (ra - l)), M.Y(cy + dy * (ra - l))}
    end
    STRICHE[key] = t
    return t
end

local function sektor(X, Y, ri, ro, a0, a1)   -- ein Ringstueck von a0 bis a1 Grad, auch ueber die 0 hinweg (Ethos zaehlt 0 bis 360)
    if a1 <= a0 then return end
    if a0 < 0 then a0 = a0 + 360 end
    if a1 <= 0 then a1 = a1 + 360 end
    if a0 < a1 then
        lcd.drawAnnulusSector(X, Y, ri, ro, a0, a1)
    else
        lcd.drawAnnulusSector(X, Y, ri, ro, a0, 360)
        if a1 > 0 then lcd.drawAnnulusSector(X, Y, ri, ro, 0, a1) end
    end
end

function R.tacho(M, F, art, cx, cy, anteil)   -- ein Tacho der Art R.GROSS oder R.KLEIN: Teilstriche, der Bogen gruen-gelb-rot, der Wert (anteil 0..1 vom Bogen, nil = keiner) als Pfeil (GROSS) oder als Balken innen am Bogen (KLEIN)
    lcd.color(R.GRAU)
    local t = striche(M, art, cx, cy)
    for i = 1, #t do
        local s = t[i]
        lcd.drawLine(s[1], s[2], s[3], s[4])
    end
    local X, Y, r = M.X(cx), M.Y(cy), art.r
    local ri, ro = M.sx(r - 1), M.sx(r + 1)
    local anfang, ende = art.anfang, art.ende
    local gruenBis, gelbBis = anfang + (ende - anfang) * 0.78, anfang + (ende - anfang) * 0.90
    lcd.color(R.GRUEN)
    sektor(X, Y, ri, ro, anfang, gruenBis)
    lcd.color(R.GELB)
    sektor(X, Y, ri, ro, gruenBis, gelbBis)
    lcd.color(R.ROT)
    sektor(X, Y, ri, ro, gelbBis, ende)
    if anteil == nil then return end
    if anteil < 0 then anteil = 0 elseif anteil > 1 then anteil = 1 end
    local a = anfang + (ende - anfang) * anteil
    if art.nadel then
        local fuss, spitze = art.nadel[1], art.nadel[2]
        local w, w1, w2 = rad(a), rad(a - 7), rad(a + 7)
        local xs, ys = M.X(cx + spitze * sin(w)), M.Y(cy - spitze * cos(w))
        lcd.color(R.NADEL)
        if type(lcd.drawFilledTriangle) == "function" then
            lcd.drawFilledTriangle(M.X(cx + fuss * sin(w1)), M.Y(cy - fuss * cos(w1)), M.X(cx + fuss * sin(w2)), M.Y(cy - fuss * cos(w2)), xs, ys)
        else
            lcd.drawLine(X, Y, xs, ys)
        end
    elseif art.balken then
        local aussen = r - 4 - art.teile[4] - 2   -- innen an den Teilstrichen
        lcd.color(F.mitte)
        sektor(X, Y, M.sx(aussen - art.balken), M.sx(aussen), anfang, a)
    end
end

return R
