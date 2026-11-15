-- Zeichenteile der NovaFly-Schirme fuer das Theme: wortgleiche Auszuege aus novasetup/lib/stil.lua.
-- Von einem Skript erzeugt - nie von Hand aendern.
local H = ...
local nova = H.nova
local stil = {}

stil.GRUND    = lcd.RGB(8, 10, 13)        -- #080a0d
stil.CYAN     = lcd.RGB(60, 200, 255)     -- links
stil.MAGENTA  = lcd.RGB(255, 60, 130)     -- rechts
stil.WEISS    = lcd.RGB(240, 244, 248)
stil.LEISE    = lcd.RGB(152, 164, 178)
stil.LINIE    = lcd.RGB(188, 200, 214)
stil.ROT      = lcd.RGB(255, 70, 70)
stil.GELB     = lcd.RGB(255, 200, 60)
stil.GRUEN    = lcd.RGB(90, 220, 130)     -- der gruene Haken (Leiter)
stil.ZEICHEN  = lcd.RGB(100, 205, 125)   -- die Zeichen unter der Wortmarke - eigener Ton, damit GRUEN allein "bestaetigt" heisst
stil.NEON     = lcd.RGB(90, 255, 70)
stil.BALKEN_RAND    = lcd.RGB(62, 24, 28)
stil.BALKEN_BETT    = lcd.RGB(58, 62, 70)
stil.BETT_DUNKEL    = lcd.RGB(26, 29, 34)
stil.BUBBLE         = lcd.RGB(20, 23, 28)
stil.ANSCHLAG_LEISE = lcd.RGB(120, 66, 90)
stil.BETT_ROT = lcd.RGB(58, 18, 24)
stil.SPUR     = lcd.RGB(120, 126, 136)

stil.RGB_VON = {
    [stil.CYAN]    = {60, 200, 255},
    [stil.MAGENTA] = {255, 60, 130},
    [stil.WEISS]   = {240, 244, 248},
    [stil.GRUEN]   = {90, 220, 130},
    [stil.GELB]    = {255, 200, 60},
    [stil.ROT]     = {255, 70, 70},
    [stil.LINIE]   = {170, 182, 196},
    [stil.NEON]    = {90, 255, 70},
}

local G_R, G_G, G_B = 8, 10, 13
stil.LEUCHT_RINGE = 3
stil.RAHMEN_DICK = 4

local leuchtVorrat = {}

function stil.leuchtstufe(farbe, anteil)
    local c = stil.RGB_VON[farbe]
    if c == nil then return nil end
    local fach = leuchtVorrat[farbe]
    if fach == nil then fach = {}; leuchtVorrat[farbe] = fach end
    local stufe = math.floor(anteil * 100)
    local fertig = fach[stufe]
    if fertig ~= nil then return fertig end
    fertig = lcd.RGB(math.floor(G_R + (c[1] - G_R) * anteil),
                     math.floor(G_G + (c[2] - G_G) * anteil),
                     math.floor(G_B + (c[3] - G_B) * anteil))
    fach[stufe] = fertig
    return fertig
end

stil.REF_B, stil.REF_H = 480, 320

local fx, fy, fb, fh = nil, nil, nil, nil

function stil.fensterFrisch()
    fx, fy, fb, fh = nil, nil, nil, nil
    local k = nova.kursiv
    if k then k.fensterNeu() end
end

function stil.fenster()
    if fb ~= nil then return fb, fh end
    fb, fh = lcd.getWindowSize()
    fx, fy = fb / stil.REF_B, fh / stil.REF_H
    return fb, fh
end

local function faktoren()
    if fx ~= nil then return fx, fy end
    stil.fenster()
    return fx, fy
end

local floor = math.floor

function stil.sx(x)                           -- jeder Zeichenbefehl geht hier durch: ohne Umweg ueber faktoren()
    if fx == nil then faktoren() end
    return floor(x * fx + 0.5)
end

function stil.sy(y)
    if fy == nil then faktoren() end
    return floor(y * fy + 0.5)
end

function stil.hintergrund(x, y, w, h)
    lcd.color(stil.GRUND)
    lcd.drawFilledRectangle(stil.sx(x), stil.sy(y), stil.sx(w), stil.sy(h))
end

function stil.flaeche(x, y, w, h, farbe)
    lcd.color(farbe or stil.WEISS)
    lcd.drawFilledRectangle(stil.sx(x), stil.sy(y), stil.sx(w), stil.sy(h))
end

local HAT_KREIS = type(lcd.drawFilledCircle) == "function"   -- einmal beim Laden, nicht je Ecke (Bildbudget)
local function kreisVoll(x, y, r)
    if HAT_KREIS then
        lcd.drawFilledCircle(x, y, r)
    else
        lcd.drawFilledRectangle(x - r, y - r, 2 * r, 2 * r)
    end
end

local HAT_SEKTOR = type(lcd.drawAnnulusSector) == "function"   -- Ethos ab 1.1.0: ein Bogen ist EIN Aufruf statt zwoelf Dreiecke

local function misch(r1, g1, b1, r2, g2, b2, t)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return lcd.RGB(math.floor(r1 + (r2 - r1) * t),
                   math.floor(g1 + (g2 - g1) * t),
                   math.floor(b1 + (b2 - b1) * t))
end

local function ue(text)                           -- SPRACHE: jeder Text, der gemessen oder gemalt wird, geht durch i18n t.wort (Deutsch: unveraendert)
    local tt = nova.i18n
    if tt and tt.wort then return tt.wort(text) end
    return text
end

function stil.mass(text, font)
    text = ue(tostring(text or ""))
    local k = nova.kursiv
    if k then
        local b, h = k.breite(text, font)
        if b then return b, h end
    end
    lcd.font(font or FONT_S)
    local b, h = lcd.getTextSize(text)
    return b, h
end

function stil.textZug(px, py, text, farbe, font)
    text = ue(tostring(text or ""))
    lcd.color(farbe or stil.WEISS)
    local k = nova.kursiv
    if k then
        local b = k.malen(px, py, text, font)
        if b then return b end
    end
    lcd.font(font or FONT_S)
    lcd.drawText(math.floor(px), math.floor(py), text)
    return (lcd.getTextSize(text))
end

function stil.kuerzen(text, font, maxEcht)
    local voll = stil.mass(text, font)
    if voll <= maxEcht then return text end
    local n = #text
    if n <= 4 then return text end
    local jeZeichen = voll / n
    local passt = math.floor(maxEcht / jeZeichen) - 3
    if passt < 4 then passt = 4 end
    if passt > n then passt = n end
    text = text:sub(1, passt)
    local schutz = 0
    while #text > 4 and stil.mass(text .. "...", font) > maxEcht and schutz < 40 do
        text = text:sub(1, #text - 1)
        schutz = schutz + 1
    end
    return text .. "..."
end

local function beschriftungRoh(x, y, text, farbe, font)
    return stil.textZug(x, y, text, farbe or stil.LEISE, font or FONT_S)
end

function stil.beschriftung(x, y, text, farbe, font)
    beschriftungRoh(stil.sx(x), stil.sy(y), text, farbe, font)
end

local TREPPE_AB = {}
do
    local treppe = {"FONT_XXL", "FONT_XL", "FONT_L", "FONT_STD", "FONT_S"}
    local vorige = nil
    for _, name in ipairs(treppe) do
        local wert = rawget(_G, name)
        if wert ~= nil then
            if vorige ~= nil then TREPPE_AB[vorige] = wert end
            vorige = wert
        end
    end
end

local treppeMerk, treppeMerkN = {}, 0
local TREPPE_MERK_MAX = 64                       -- ein voller Schirm traegt mehr als 16 Woerter: mit 16 wurde er jedes Bild neu gerechnet
function stil.treppeMerkerStand() return treppeMerkN end   -- fuer den Pruefstand
function stil.merkerLeeren() treppeMerk, treppeMerkN = {}, 0 end   -- die Treppen-Entscheide gehoeren dem Schirm, der sie brauchte

local function treppeEntscheid(text, f, maxEcht)
    text = ue(text)
    local k = nova.kursiv
    local fb = stil.fenster()
    local schluessel = ((k and k.abgeschaltet) and "g" or "k")
                       .. "\1" .. fb .. "\1" .. tostring(f) .. "\1" .. maxEcht .. "\1" .. text
    local e = treppeMerk[schluessel]
    if e then return e.f, e.text, e.dy end
    local urspruenglich = schluessel
    local hGross, hKlein
    while true do
        local b, h = stil.mass(text, f)
        hGross, hKlein = hGross or h, h
        if b <= maxEcht then break end
        local kleiner = TREPPE_AB[f]
        if not kleiner then
            text = stil.kuerzen(text, f, maxEcht)
            break
        end
        f = kleiner
    end
    local dy = 0
    if hGross and hKlein and hGross > hKlein then
        dy = math.floor((hGross - hKlein) / 2)   -- kleiner gesetzt: das Wort bleibt auf der Mitte der Zeile, in der es gross gestanden haette
    end
    if treppeMerkN >= TREPPE_MERK_MAX then treppeMerk, treppeMerkN = {}, 0 end
    treppeMerk[urspruenglich] = {f = f, text = text, dy = dy}
    treppeMerkN = treppeMerkN + 1
    return f, text, dy
end

function stil.passend(text, font, maxBreiteRef)   -- in welcher Schrift und mit welchem Text ein ...Passt-Aufruf das Wort malt (zum Vorbereiten)
    return treppeEntscheid(tostring(text or ""), font or FONT_STD, stil.sx(maxBreiteRef))
end

function stil.beschriftungPasst(x, y, text, farbe, font, maxBreiteRef)
    text = tostring(text or "")
    if text == "" then return end
    local maxRef = maxBreiteRef or (stil.REF_B - x - 4)
    local f, dy
    f, text, dy = treppeEntscheid(text, font or FONT_STD, stil.sx(maxRef))
    beschriftungRoh(stil.sx(x), stil.sy(y) + dy, text, farbe, f)
end

local function systemMass(text, font)
    lcd.font(font or FONT_STD)
    return lcd.getTextSize(ue(text))
end

local function systemZug(px, py, text, farbe, font)
    text = ue(text)
    lcd.font(font or FONT_STD)
    lcd.color(farbe or stil.LEISE)
    lcd.drawText(math.floor(px), math.floor(py), text)
    return (lcd.getTextSize(text))
end

local function treppeSystem(text, f, maxEcht)
    text = ue(text)                              -- erst uebersetzen, dann kuerzen: sonst steht gekuerztes Deutsch auf einem fremdsprachigen Sender
    local fb = stil.fenster()
    local schluessel = "y\1" .. fb .. "\1" .. tostring(f) .. "\1" .. maxEcht .. "\1" .. text
    local e = treppeMerk[schluessel]
    if e then return e.f, e.text end
    local urspruenglich = schluessel
    while systemMass(text, f) > maxEcht do
        local kleiner = TREPPE_AB[f]
        if kleiner then
            f = kleiner
        else
            while #text > 4 and systemMass(text .. "...", f) > maxEcht do
                text = text:sub(1, #text - 1)
            end
            text = text .. "..."
            break
        end
    end
    if treppeMerkN >= TREPPE_MERK_MAX then treppeMerk, treppeMerkN = {}, 0 end
    treppeMerk[urspruenglich] = {f = f, text = text}
    treppeMerkN = treppeMerkN + 1
    return f, text
end

function stil.arbeitswort(text)   -- die Woerter, die nur sagen, dass gearbeitet wird: die Meldezeile malt sie nicht mehr, ui.paint malt dafuer den Balken
    if text == nil or text == "" then return false end
    local t = nova.i18n
    return text == t.laeuft or text == t.laeuft_still or text == t.k_warten or text == t.fi_loeschen_laeuft
        or text == t.m_ansage_startet or text == t.grund.msp_nicht_bereit   -- auch "Moment" sagt nur, dass gearbeitet wird
end

function stil.arbeit()                         -- ein Schirm, der frueher mitten im Bild "laeuft ..." schrieb, meldet hier nur noch, dass gearbeitet wird
    stil.arbeitGewuenscht = true
end

function stil.meldezeile(text, farbe, links, linksFarbe)
    text = tostring(text or "")
    if stil.satzUnten and (text == nova.i18n.laeuft or text == "") then text = stil.satzUnten end   -- der RF007 spricht nur in dieser Zeile
    if stil.arbeitswort(text) then stil.arbeitGewuenscht = true; text = "" end
    links = links and tostring(links) or nil
    if text == "" and not links then return end
    stil.bandGemalt = true

    local bw, bh = stil.fenster()

    local _, th = systemMass("Ag", FONT_STD)
    local hoehe = (th or 19) + 2
    lcd.color(stil.GRUND)
    lcd.drawFilledRectangle(0, bh - hoehe - stil.RAHMEN_DICK, bw,
                            hoehe + stil.RAHMEN_DICK)
    local y = bh - hoehe - stil.RAHMEN_DICK + 1

    local x = 8
    if links then
        x = x + systemZug(x, y, links, linksFarbe or stil.LEISE, FONT_STD) + 8
    end
    if text == "" then return end

    if farbe == nil or farbe == stil.LEISE then farbe = stil.NEON end
    local f
    f, text = treppeSystem(text, FONT_STD, bw - x - 4)
    stil.bandEnde = x + systemZug(x, y, text, farbe, f)   -- rechte Kante des Worts: dort beginnt der Speicherbalken
end

stil.BALKEN_FELDER = 4   -- der Speichervorgang: vier Felder rechts in der Meldezeile, je eines je Funkschritt
local function balken(stufe, farbe)
    local bw, bh = stil.fenster()
    local _, th = systemMass("Ag", FONT_STD)
    local hoehe = (th or 19) + 2
    if not stil.bandGemalt then              -- kein Satz davor: der Streifen bekommt seinen Grund hier
        lcd.color(stil.GRUND)
        lcd.drawFilledRectangle(0, bh - hoehe - stil.RAHMEN_DICK, bw, hoehe + stil.RAHMEN_DICK)
        stil.bandGemalt = true
    end
    local links = math.max((stil.bandEnde or 0) + stil.sx(12), stil.sx(250))   -- rechts vom Wort, nie darauf
    local rechts, luft = bw - stil.sx(8), stil.sx(4)
    local w = math.floor((rechts - links - luft * (stil.BALKEN_FELDER - 1)) / stil.BALKEN_FELDER)
    local h = hoehe - 6
    if h < 4 or rechts - links < 20 then return false end   -- gar kein Platz: nicht gemalt, und das sagt der Rueckgabewert
    if w < 4 then w = 4 end                      -- ein langer Satz laesst wenig Platz: der Balken wird schmal, faellt aber nicht still weg
    local y = bh - hoehe - stil.RAHMEN_DICK + 4
    for i = 1, stil.BALKEN_FELDER do
        local x = links + (i - 1) * (w + luft)
        if i <= stufe then
            lcd.color(farbe)
            lcd.drawFilledRectangle(x, y, w, h)
        else
            lcd.color(stil.LINIE)
            lcd.drawRectangle(x, y, w, h)
        end
    end
    return true
end

function stil.speicherbalken(stufe)
    if balken(stufe, stil.GRUEN) then stil.balkenGemalt = "speichern" end   -- quittiert = gruen, wie jede Bestaetigung; nicht gemalt = nicht gemalt
end

function stil.arbeitsbalken(felder)   -- es wird gelesen oder gewartet: blau
    if balken(felder or 0, stil.CYAN) then stil.balkenGemalt = "arbeit" end
end

function stil.beschriftungMittigPasst(cx, cy, text, farbe, font, maxBreiteRef)
    text = tostring(text or "")
    if text == "" then return end
    local maxEcht = stil.sx(maxBreiteRef or (stil.REF_B - 8))
    local f
    f, text = treppeEntscheid(text, font or FONT_STD, maxEcht)
    local tb, th = stil.mass(text, f)
    beschriftungRoh(stil.sx(cx) - math.floor(tb / 2),
                    stil.sy(cy) - math.floor((th or 12) / 2), text, farbe, f)
end

function stil.beschriftungMittig(cx, cy, text, farbe, font)
    local tb, th = stil.mass(text, font or FONT_S)
    beschriftungRoh(stil.sx(cx) - math.floor(tb / 2), stil.sy(cy) - math.floor((th or 12) / 2),
                    text, farbe, font)
end

function stil.systemMittig(cx, cy, text, farbe, font)
    text = tostring(text or "")
    if text == "" then return end
    lcd.font(font or FONT_S)
    local tb, th = lcd.getTextSize(text)
    lcd.color(farbe or stil.LEISE)
    lcd.drawText(stil.sx(cx) - math.floor((tb or 0) / 2),
                 stil.sy(cy) - math.floor((th or 12) / 2), text)
end

function stil.grundlinie(px, gl, text, farbe, font)
    text = tostring(text or "")
    if text == "" then return 0 end
    local _, th = stil.mass(text, font or FONT_S)
    return stil.textZug(px, stil.sy(gl) - (th or 12), text, farbe, font)
end

function stil.titel(text, farbe, font)
    farbe = farbe or stil.WEISS
    local f = font or FONT_XL
    stil.beschriftungMittig(240, 26, text, farbe, f)
end

function stil.textZugRechts(rx, py, text, farbe, font)
    text = ue(tostring(text or ""))
    local k = nova.kursiv
    if k and k.malenRechts then
        lcd.color(farbe or stil.WEISS)
        local b = k.malenRechts(rx, py, text, font)
        if b then return b end
    end
    local tb = stil.mass(text, font)
    stil.textZug(rx - tb, py, text, farbe, font)
    return tb
end

function stil.beschriftungRechts(rx, y, text, farbe, font)
    return stil.textZugRechts(stil.sx(rx), stil.sy(y), text, farbe, font)
end

function stil.beschriftungRechtsPasst(rx, y, text, farbe, font, maxBreiteRef)
    text = tostring(text or "")
    if text == "" then return 0 end
    local maxEcht = stil.sx(maxBreiteRef or rx)
    local f, dy
    f, text, dy = treppeEntscheid(text, font or FONT_S, maxEcht)
    return stil.textZugRechts(stil.sx(rx), stil.sy(y) + dy, text, farbe, f)
end

stil.FUSS_Y      = 276
stil.FUSS_Y_TIEF = 292

stil.KNOPF_PAD_X = 8
stil.KNOPF_PAD_Y = 4

stil.KNOPF_GRUND = lcd.RGB(16, 42, 56)
stil.KNOPF_LEISE = lcd.RGB(140, 152, 164)

stil.FELD_LEISE = lcd.RGB(158, 170, 184)
stil.FELD_ROT   = lcd.RGB(255, 96, 96)     -- rot AUF dem roten Feld (Glanz), am Wort geheilt

local function rundVoll(x, y, w, h, r)             -- nach rfsuite (GPLv3): gefuelltes Rechteck mit runden Ecken
    lcd.drawFilledRectangle(x + r, y, w - 2 * r, h)
    lcd.drawFilledRectangle(x, y + r, r, h - 2 * r)
    lcd.drawFilledRectangle(x + w - r, y + r, r, h - 2 * r)
    kreisVoll(x + r, y + r, r)
    kreisVoll(x + w - r - 1, y + r, r)
    kreisVoll(x + r, y + h - r - 1, r)
    kreisVoll(x + w - r - 1, y + h - r - 1, r)
end

stil.M_ABSATZ    = lcd.RGB(5, 7, 11)
stil.KACHEL          = lcd.RGB(9, 13, 18)
stil.KACHEL_KANTE    = lcd.RGB(43, 54, 66)
stil.KACHEL_OFFEN    = lcd.RGB(36, 52, 66)
stil.KACHEL_SCHIMMER = {lcd.RGB(92, 38, 62), lcd.RGB(150, 46, 88)}   -- magenta Schimmer hinter dem Wort, aussen nach innen
stil.M_FLAECHE   = lcd.RGB(23, 29, 38)
stil.M_SHEEN     = lcd.RGB(30, 37, 49)
stil.M_LICHT     = lcd.RGB(46, 57, 73)
stil.M_SCHATTEN  = lcd.RGB(4, 6, 10)
stil.M_FLAECHE_G = lcd.RGB(28, 36, 47)
stil.M_SHEEN_G   = lcd.RGB(38, 48, 63)
stil.M_LICHT_G   = lcd.RGB(61, 76, 96)
stil.M_TIEF      = lcd.RGB(8, 10, 14)
stil.M_TIEF_KANTE = lcd.RGB(35, 43, 54)
stil.GLANZ_RGB = {
    normal   = {{46, 57, 73}, {23, 29, 38}},
    gewaehlt = {{61, 76, 96}, {28, 36, 47}},
    rot      = {{74, 44, 56}, {32, 20, 26}},
}

stil.M_FLAECHE_R = lcd.RGB(32, 20, 26)
stil.M_SHEEN_R   = lcd.RGB(42, 26, 34)
stil.M_LICHT_R   = lcd.RGB(74, 44, 56)

local glanzVorrat, glanzVorratN = {}, 0      -- Reihen je (Breite, Hoehe, Radius, Farbpaar): einmal gerechnet

local function glanzZeilen(w, h, r, paar)
    local schluessel = w .. "/" .. h .. "/" .. r .. "/" .. tostring(paar)
    local z = glanzVorrat[schluessel]
    if z then return z end
    if h > 64 then h = 64 end                -- der Glanz endet, die Kachel nicht
    local sh = (h > 11) and 2 or 1           -- ab ~28 px Feld: 2-px-Reihen (Kosten)
    local n = math.max(2, math.floor(h / sh))
    local A, B = paar[1], paar[2]
    z = {sh = sh}
    for i = 0, n - 1 do
        local yy = i * sh
        local dx = 0                         -- oben der Rundung folgen (Kreissehne)
        if r > 0 and yy < r then
            local d = r - yy
            dx = r - math.floor(math.sqrt(r * r - d * d))
        end
        local ww = w - 2 * dx - yy           -- je Reihe so viel kuerzer wie hoch: 45 Grad
        if ww < 4 then break end
        z[#z + 1] = {dx, yy, ww,             -- Ton nur jede zweite Reihe (Kosten)
                     (i % 2 == 0) and misch(A[1], A[2], A[3], B[1], B[2], B[3], i / (n - 1)) or false}
    end
    if glanzVorratN >= 96 then glanzVorrat, glanzVorratN = {}, 0 end
    glanzVorrat[schluessel] = z
    glanzVorratN = glanzVorratN + 1
    return z
end

local function glanzSchraeg(x, y, w, h, r, paar)
    local z = glanzZeilen(w, h, r, paar)
    local sh = z.sh
    for i = 1, #z do
        local e = z[i]
        if e[4] then lcd.color(e[4]) end
        lcd.drawFilledRectangle(x + e[1], y + e[2], e[3], sh)
    end
end

local function kantenMalen(x, y, w, h, r, licht)
    local k = math.max(1, r)
    lcd.color(licht)                         -- Licht von oben links; den Schatten
    lcd.drawFilledRectangle(x + k, y, w - 2 * k, 1)     -- macht der Absatz
    lcd.drawFilledRectangle(x, y + k, 1, h - 2 * k)
end

local function form(x, y, w, h, r)
    if r == 0 then lcd.drawFilledRectangle(x, y, w, h)
    else rundVoll(x, y, w, h, r) end
end

local function feldMalen(ex, ey, ew, eh, r, akzent, art)
    local k = math.max(2, r)

    if art == "tief" then
        lcd.color(stil.M_TIEF)
        form(ex, ey, ew, eh, r)
        lcd.color(stil.M_TIEF_KANTE)
        lcd.drawFilledRectangle(ex + k, ey + eh - 1, ew - 2 * k, 1)
        lcd.drawFilledRectangle(ex + ew - 1, ey + k, 1, eh - 2 * k)
        return
    end

    local fl, sh, li = stil.M_FLAECHE, stil.M_SHEEN, stil.M_LICHT
    local paar = stil.GLANZ_RGB.normal
    if art == "gewaehlt" then
        fl, sh, li = stil.M_FLAECHE_G, stil.M_SHEEN_G, stil.M_LICHT_G
        paar = stil.GLANZ_RGB.gewaehlt
    elseif art == "rot" then
        fl, sh, li = stil.M_FLAECHE_R, stil.M_SHEEN_R, stil.M_LICHT_R
        paar = stil.GLANZ_RGB.rot
    end

    local schmal = akzent ~= nil and ew < stil.sx(200)
    if schmal then
        if nova.hohesDetail ~= false and stil.RGB_VON[akzent] ~= nil then
            for i = stil.LEUCHT_RINGE, 1, -1 do
                local f = stil.leuchtstufe(akzent, 0.75 / (i + 1))
                if f then
                    lcd.color(f)
                    form(ex - i, ey - i, ew + 2 * i, eh + 2 * i, r + i)
                end
            end
        end
        lcd.color(akzent)
        form(ex, ey, ew, eh, r)
        ex, ey, ew, eh = ex + 2, ey + 2, ew - 4, eh - 4
        r = math.max(0, r - 2)
    end

    if nova.hohesDetail == false then
        lcd.color(li)
        lcd.drawFilledRectangle(ex, ey, ew, eh)
        lcd.color(fl)
        lcd.drawFilledRectangle(ex + 1, ey + 1, ew - 2, eh - 2)
    else
        local a = (eh >= 40) and 2 or 1
        lcd.color(stil.M_ABSATZ)
        form(ex + a, ey + a, ew, eh, r)
        lcd.color(fl)
        form(ex, ey, ew, eh, r)
        local sheenH = math.max(1, math.floor((eh - 2) * 0.45))
        glanzSchraeg(ex, ey, ew, sheenH, r, paar)
        kantenMalen(ex, ey, ew, eh, r, li)
    end

    if akzent ~= nil and not schmal then         -- breite Felder: der Balken links
        lcd.color(akzent)
        local av = 1
        if r > 0 then av = r - math.floor(math.sqrt(4 * r - 4)) + 1 end
        lcd.drawFilledRectangle(ex + 2, ey + av, math.max(3, stil.sx(4)),
                                eh - 2 * av)
    end
end

local function feldRadius(eh)   -- EIN Radius fuer Felder, Rahmen und runde Flaechen
    if eh < 22 then return 0 end
    return math.max(3, math.min(12, math.floor(eh / 4)))
end

function stil.feld(x, y, w, h, akzent, art)
    local ex, ey = stil.sx(x), stil.sy(y)
    local ew, eh = stil.sx(w), stil.sy(h)
    if ew < 6 or eh < 6 then return end
    feldMalen(ex, ey, ew, eh, feldRadius(eh), akzent, art)
end

function stil.flaecheRund(x, y, w, h, farbe)
    local ex, ey = stil.sx(x), stil.sy(y)
    local ew, eh = stil.sx(w), stil.sy(h)
    lcd.color(farbe or stil.WEISS)
    form(ex, ey, ew, eh, feldRadius(eh))
end

function stil.chip(rechtsX, cy, text, farbe, font, minB)
    text = tostring(text or "")
    if text == "" then return end
    local f = font or FONT_S
    local tw, th = stil.mass(text, f)
    th = th or 12
    local px, py = 9, 4
    local b = math.max(tw + 2 * px, minB or 0)
    local hh = th + 2 * py
    local ex, ey = stil.sx(rechtsX - b), stil.sy(cy - hh / 2)
    local ew, eh = stil.sx(b), stil.sy(hh)
    if ew >= 6 and eh >= 6 then feldMalen(ex, ey, ew, eh, 0, nil, "tief") end
    stil.beschriftungRechts(rechtsX - px, cy - th / 2, text, farbe, f)
end

function stil.leerstrich(cx, cy, farbe, lang, dick)
    lang, dick = lang or 30, dick or 4
    stil.flaeche(cx - lang / 2, cy - dick / 2, lang, dick, farbe or stil.LEISE)
end

local function knopfMalen(x, y, tw, th, wort, farbe, f)
    if farbe == stil.LEISE then farbe = stil.KNOPF_LEISE end
    local px = math.max(2, stil.sx(stil.KNOPF_PAD_X))
    local py = math.max(2, stil.sy(stil.KNOPF_PAD_Y))
    local bx, by = x - px, y - py
    local bw, bh = tw + 2 * px, th + 2 * py
    local r = math.max(3, math.floor(bh / 3))
    local deckel = math.floor((math.min(bw, bh) - 2) / 2)
    if r > deckel then r = deckel end
    lcd.color(stil.CYAN)
    rundVoll(bx, by, bw, bh, r)
    lcd.color(stil.KNOPF_GRUND)
    rundVoll(bx + 1, by + 1, bw - 2, bh - 2, math.max(2, r - 1))
    beschriftungRoh(x, y, wort, farbe, f)
end

function stil.knopfMittig(cx, cy, wort, farbe, font)
    wort = tostring(wort or "")
    if wort == "" then return end
    local f = TREPPE_AB[font] or font or FONT_STD
    local tw, th = stil.mass(wort, f)
    th = th or 12
    local x = stil.sx(cx) - math.floor(tw / 2)
    local y = stil.sy(cy) - math.floor(th / 2)
    knopfMalen(x, y, tw, th, wort, farbe, f)
end

function stil.knopf(xRef, cy, wort, farbe, font, rechtsbuendig, maxBreiteRef)
    wort = tostring(wort or "")
    if wort == "" then return end
    local f = TREPPE_AB[font] or font or FONT_STD
    if maxBreiteRef then
        local rand = 2 * math.max(2, stil.sx(stil.KNOPF_PAD_X))
        f, wort = treppeEntscheid(wort, f, math.max(8, stil.sx(maxBreiteRef) - rand))
    end
    local tw, th = stil.mass(wort, f)
    th = th or 12
    local x = stil.sx(xRef)
    if rechtsbuendig then x = x - tw end
    local y = stil.sy(cy) - math.floor(th / 2)
    knopfMalen(x, y, tw, th, wort, farbe, f)
end

stil.FUSS_ZK = 228          -- rechte Wortkante von ZURUECK
stil.FUSS_OK = 252          -- linke Wortkante von SPEICHERN/OK

function stil.fusszeile(cy, links, farbeLinks, rechts, farbeRechts,
                        fontLinks, fontRechts, linksX)
    stil.fussGemalt = true   -- nur Schirme mit Fusszeile bekommen unten den RF-Satz
    if links then
        stil.knopf(stil.FUSS_ZK, cy, links, farbeLinks, fontLinks, true)
    end
    if rechts then
        stil.knopf(stil.FUSS_OK, cy, rechts, farbeRechts, fontRechts, false)
    end
end

function stil.rahmen(z, farbe)
    local x, y = stil.sx(z.x), stil.sy(z.y)
    local w, h = stil.sx(z.w), stil.sy(z.h)
    lcd.color(farbe or stil.WEISS)
    local r = HAT_SEKTOR and feldRadius(h) or 0   -- rund wie jedes Feld
    if r == 0 then
        lcd.drawRectangle(x, y, w, h)
        lcd.drawRectangle(x + 1, y + 1, w - 2, h - 2)
        return
    end
    lcd.drawFilledRectangle(x + r, y, w - 2 * r, 2)
    lcd.drawFilledRectangle(x + r, y + h - 2, w - 2 * r, 2)
    lcd.drawFilledRectangle(x, y + r, 2, h - 2 * r)
    lcd.drawFilledRectangle(x + w - 2, y + r, 2, h - 2 * r)
    lcd.drawAnnulusSector(x + w - r - 1, y + r, r - 2, r, 0, 90)      -- Winkel: 0 = oben (12 Uhr), im Uhrzeigersinn
    lcd.drawAnnulusSector(x + w - r - 1, y + h - r - 1, r - 2, r, 90, 180)
    lcd.drawAnnulusSector(x + r, y + h - r - 1, r - 2, r, 180, 270)
    lcd.drawAnnulusSector(x + r, y + r, r - 2, r, 270, 360)
end

local grund, grundVersuche = {}, {}
function stil.bildGrund(x, y, w, h, datei)
    local bmp = grund[datei]
    if bmp == nil and (grundVersuche[datei] or 0) < 20 and type(lcd.loadBitmap) == "function" then
        grundVersuche[datei] = (grundVersuche[datei] or 0) + 1
        bmp = H.laden(lcd.loadBitmap, "gfx/" .. datei)
        grund[datei] = bmp
    end
    if bmp and pcall(lcd.drawBitmap, stil.sx(x), stil.sy(y), bmp, stil.sx(w), stil.sy(h)) then return true end
    return false
end

return stil
