-- VORFLUG: die Seite links vom Cockpit auf dessen Grund (seite_teile.lua S.grund); die Linien des Cockpits laufen von rechts
-- herein und klingen aus. Kopfband: links der Flugmodus, mittig der Modellname, rechts RSSI und VFR je als fuenf Balken ohne Zahlen;
-- links das Modellbild des Piloten mit weichem Rand, rechts eine Umrandung mit Akku (Stand, Spannung, Zellen, Kapazitaet), Zelle
-- und Verbrauch, offen zum rechten Rand; im Fussband vier Chips mit dem letzten Flug: Hoehe, Steigen, Sinken, Flugzeit.
-- Geoeffnet und geschlossen wird die Seite durch Wischen quer (cockpit.lua).
local H = ...
local floor = math.floor

local FOTO = {x = 10, y = 66, h = 168}           -- das Fotofeld, 4:3 aus der Hoehe; dieselben Masse hat der Fotorand (gfx/fotorand*.png)
local BALKEN = {rssi = 398, vfr = 438, unten = 36, breite = 4, schritt = 6}   -- je fuenf Empfangsbalken wie am Sender, steigend 6 bis 18; beide Gruppen rechts oben nebeneinander, die Zahlen stehen im Cockpit
local RSSI_STUFEN = {42, 50, 60, 70, 85}         -- dB je Balken; 42 ist die Warnschwelle des Senders
local VFR_STUFEN = {20, 40, 60, 80, 95}          -- Prozent je Balken
local KOPF_Y = 28                                 -- die Mitte des Kopfbands (y 8-47)
local MODUS = {x = 12, wort = 16, wert = 34}      -- links im Kopfband: FLUGMODUS klein, darunter der Modus gruen (je die Mitte der Zeile)
local AKKU = {x = 246, y = 66, w = 234, h = 174}  -- die Umrandung rechts, offen zum Rand; unten bei 240 wie der Chip der Bankseite gegenueber, alles parallel
local FUSS = {y = 262, h = 48, w = 112, luecke = 6, x = 10}
local KEINE_ZONE = {x = 0, y = 0, w = 0, h = 0}   -- ZURUECK gibt es auf einer Seite nicht: zurueck geht das Wischen
local AKKU_PAUSE = 3                              -- s bis zur naechsten Frage nach BATTERY_CONFIG, wenn eine scheiterte oder nicht abging

local t = H.i18n
local stil, S = nil, nil
local nova = {dirty = false, armLage = "unbekannt", flugbuch = {}, hohesDetail = true, kursiv = nil,   -- Senderschrift, keine Masken
              i18n = setmetatable({wort = function(text) return text end}, {__index = t})}   -- die Seite uebersetzt ihre Woerter selbst (S.wort); was stil_teile malt, geht kein zweites Mal durch die Sprache
local BILDER = H.merk.bilder or {}   -- Foto und Fotorand bleiben ueber das Schliessen der Seite hinaus geladen: jedes Oeffnen lud sie
H.merk.bilder = BILDER               -- sonst neu, und der X18 blieb stehen
local foto = nil
local akku, akkuFuer = nil, nil   -- die Suite ohne session.batteryConfig: BATTERY_CONFIG ueber den Bus, und der Heli (mcu_id), fuer den er gilt
local frage = {heli = nil, ab = 0}   -- die Frage ohne Antwort (fuer welchen Heli) und ab wann die naechste gehen darf

local function fotoLaden()   -- das Modellbild, das der Pilot in Ethos dem Modell gegeben hat; den Ort auf der Karte kennt das Cockpit (H.bildPfad)
    local name = nil
    if type(model) == "table" and type(model.bitmap) == "function" then
        local ok, b = pcall(model.bitmap)
        if ok and type(b) == "string" then name = b end
    end
    if BILDER.foto ~= nil and BILDER.fotoName == name then foto = BILDER.foto or nil return end   -- gemerkt nach dem Namen des Bilds: ein anderes Modell, ein anderes Bild
    foto, BILDER.foto, BILDER.fotoName = nil, nil, name   -- das vorige Bild loslassen: kein Verweis haelt es mehr
    local pfad = (name ~= nil and name ~= "" and not name:find("default_", 1, true)) and H.bildPfad(name) or nil
    if pfad ~= nil and type(lcd.loadBitmap) == "function" then
        local ok, bmp = pcall(lcd.loadBitmap, pfad)
        if ok and bmp then foto = bmp end
    end
    BILDER.foto = foto or false
end

local function fotoBox()   -- Lage und Mass des Fotos im Fenster: die Hoehe aus der Vorlage, die Breite 4 : 3 dazu (Ethos haelt das Seitenverhaeltnis eines Bilds)
    local h = stil.sy(FOTO.h)
    return stil.sx(FOTO.x), stil.sy(FOTO.y), floor(h * 4 / 3 + 0.5), h
end

local function fotoRand()   -- der weiche Rand ueber dem Foto: aussen der Grund der Seite an der Stelle des Fotos (Hochglanz fotorand.png, bei den Carbon-Farben
    local hell = S.hell()   -- fotorand_carbon.png, hell fotorand_hell_<Farbe>.png mit den Baendern des hellen Grunds), je Schirmgroesse ein Bild (S.endung)
    local carbon = not hell and type(H.bild) == "function" and tostring(H.bild()):find("carbon", 1, true)
    local name = "fotorand" .. (hell and ("_hell_" .. H.hellName()) or (carbon and "_carbon" or "")) .. S.endung() .. ".png"
    if BILDER.randName ~= name then BILDER.rand, BILDER.randName = nil, name end
    if BILDER.rand == nil then BILDER.rand = H.laden(lcd.loadBitmap, "gfx/" .. name) or false end
    if BILDER.rand then
        local x, y, w, h = fotoBox()
        pcall(lcd.drawBitmap, x, y, BILDER.rand, w, h)
    end
end

local function stufen(wert, liste)
    if wert == nil then return 0 end
    local n = 0
    for i = 1, #liste do if wert >= liste[i] then n = i end end
    return n
end

local function empfang(x, voll, farbe)   -- fuenf Balken, steigend von links nach rechts; die vollen in der Farbe des Links, die leeren leise
    for i = 0, 4 do
        local h = 6 + i * 3
        S.flaeche(x + i * BALKEN.schritt, BALKEN.unten - h, BALKEN.breite, h, i < voll and farbe or stil.FELD_LEISE)
    end
end

local function modusWort(v)   -- der Flugmodus aus den Bits der Firmware (runtime_config.h) wie NovaSetup (sensoren.lua flugmodus): HORIZON vor ANGLE, sonst Acro; RESCUE (32) liegt mit ANGLE an und geht vor
    if v == nil then return nil end
    v = floor(v)
    if floor(v / 32) % 2 == 1 then return "RETTUNG" end
    if floor(v / 4) % 2 == 1 then return "HORIZONT" end
    if floor(v / 2) % 2 == 1 then return "WINKEL" end
    return "ACRO"
end

local function zahl(v, muster)
    if v == nil then return "--", stil.FELD_LEISE end
    if muster == nil then v = floor(v + 0.5) end   -- ganze Zahl: %d nimmt keinen Bruch
    local z = string.format(muster or "%d", v)
    if type(v) == "number" and v <= 0 and z:find("^%-[0.]*$") then z = z:sub(2) end   -- was auf null rundet, steht ohne Minus ("-0.0" bei Sinken genau 0)
    return z, H.farben.gruen
end

local function malen()
    if stil == nil then return end
    stil.fensterFrisch()
    stil.bandGemalt, stil.fussGemalt = false, false
    S.grund()
    S.linien(true)
    local s = H.stand() or {}
    local link = H.linkFarbe(s)   -- weiss bei gutem Link, gelb und rot nach den Grenzen des Cockpits; gut heisst hier gruen wie die Zahlen
    if link == H.farben.weiss then link = H.farben.gruen end
    empfang(BALKEN.rssi, stufen(s.rssi, RSSI_STUFEN), link)
    empfang(BALKEN.vfr, stufen(s.vfr, VFR_STUFEN), link)
    local modus = modusWort(s.flugmodus)
    S.zeileLinks(MODUS.x, MODUS.wort, {{S.wort("FLUGMODUS"), stil.WEISS, FONT_XS}})
    S.zeileLinks(MODUS.x, MODUS.wert, {{modus and S.wort(modus) or "--", modus and H.farben.gruen or stil.FELD_LEISE, FONT_S}})
    local z, f
    stil.beschriftungMittigPasst(240, KOPF_Y, s.modell or "", stil.WEISS, FONT_L, 280)
    fotoLaden()
    local fx, fy, fw, fh = fotoBox()
    if foto ~= nil and pcall(lcd.drawBitmap, fx, fy, foto, fw, fh) then fotoRand() end

    local a = AKKU
    S.chip(a.x, a.y, a.w, a.h, "rechts")
    local cx = a.x + a.w / 2
    local zelle = H.zellFarbe(s.cellF or s.cell)   -- die Farbe des Akkus nach der Zelle, wie das Cockpit
    stil.beschriftungMittig(cx, a.y + 17, S.wort("AKKU"), stil.WEISS, FONT_S)
    z, f = zahl(s.fuel ~= nil and floor(s.fuel + 0.5) or nil)
    S.zeile(cx, a.y + 45, {{z, s.fuel ~= nil and zelle or f, FONT_XL}, {"%", stil.WEISS, FONT_S}})
    local rf = H.rf()
    local bc = rf and rf.session and rf.session.batteryConfig
    local wahl = type(bc) == "table" and type(bc.profiles) == "table" and tonumber(bc.profiles[rf.session.activeBatteryType]) or nil   -- rfsuite 2.3.x: die Kapazitaet des gewaehlten Akkus (session.activeBatteryType, 0 bis 5), wie die Suite selbst rechnet
    if type(bc) ~= "table" then bc = akku end
    local kap = (wahl ~= nil and wahl > 0) and wahl or (type(bc) == "table" and tonumber(bc.batteryCapacity) or nil)   -- ohne Wahl oder ohne Kapazitaet im Profil die vom Verbinden
    if kap ~= nil and kap <= 0 then kap = nil end
    local zellen = s.zellen or (type(bc) == "table" and tonumber(bc.batteryCellCount)) or nil
    if zellen ~= nil and zellen <= 0 then zellen = nil end
    local segs = {}
    local function seg(text, farbe) segs[#segs + 1] = {text, farbe, FONT_XS} end
    z, f = zahl(s.pack, "%.1f") seg(z, s.pack ~= nil and zelle or f) seg("V  ", stil.WEISS)
    seg((zellen ~= nil and tostring(floor(zellen)) or "--") .. "S  ", zellen ~= nil and stil.WEISS or stil.FELD_LEISE)
    z, f = zahl(kap) seg(z, f) seg("mAh", stil.WEISS)
    S.zeile(cx, a.y + 74, segs)
    local lx, rx = a.x + a.w / 4, a.x + a.w * 3 / 4
    stil.beschriftungMittig(lx, a.y + 108, S.wort("ZELLE"), stil.WEISS, FONT_XS)
    z, f = zahl(s.cell, "%.2f")
    S.zeile(lx, a.y + 133, {{z, s.cell ~= nil and zelle or f, FONT_L}, {"V", stil.WEISS, FONT_S}})
    stil.beschriftungMittig(rx, a.y + 108, S.wort("VERBRAUCH"), stil.WEISS, FONT_XS)
    z, f = zahl(s.verbrauch ~= nil and floor(s.verbrauch + 0.5) or nil)
    S.zeile(rx, a.y + 133, {{z, f, FONT_L}, {"mAh", stil.WEISS, FONT_S}})

    local fl = H.flug() or {}   -- der letzte Flug hier: Hoehe und Steigen/Sinken aus dem Hoehensensor, die Flugzeit scharf mit drehendem Rotor;
    local sz = type(H.sitzung) == "function" and H.sitzung() or {}   -- ohne Flug hier die Hoechstwerte seit dem Verbinden und die letzte Flugzeit, wie die Suite sie merkt
    local hoehe, rate = s.altFt and "ft" or "m", s.altFt and "ft/s" or "m/s"
    local sek = fl.zeit
    if sek == nil and type(H.letzteFlugzeit) == "function" then sek = H.letzteFlugzeit() end
    local zeit = sek ~= nil and string.format("%d:%02d", floor(sek / 60), floor(sek % 60)) or nil
    local alt, steig, sink = fl.alt or sz.altMax, fl.steig or sz.steigMax, fl.sink or sz.sinkMax
    local chips = {{"HOEHE MAX", alt, "%.0f", hoehe}, {"STEIGEN MAX", steig, "%.1f", rate},
                   {"SINKEN MAX", sink ~= nil and -sink or nil, "%.1f", rate}, {"FLUGZEIT", zeit, "%s", "min"}}
    for i = 1, 4 do
        local x = FUSS.x + (i - 1) * (FUSS.w + FUSS.luecke)
        local w = (i == 4) and (480 - x) or FUSS.w
        S.chip(x, FUSS.y, w, FUSS.h, i == 4 and "rechts" or nil)
        local c = chips[i]
        stil.beschriftungMittig(x + w / 2, FUSS.y + 13, S.wort(c[1]), stil.WEISS, FONT_XS)
        z, f = zahl(c[2], c[3])
        S.zeile(x + w / 2, FUSS.y + 33, {{z, f, FONT_STD}, {c[4], stil.WEISS, FONT_XS}})
    end
end

local function ereignis()   -- auf der Seite links gibt es nichts zu tippen; jede Beruehrung gehoert trotzdem dem Theme
    return true
end

local function heliJetzt()   -- der verbundene Heli (mcu_id der Suite); nil ohne Verbindung
    local rf = H.rf()
    local se = rf and rf.session
    if type(se) ~= "table" or se.isConnected ~= true then return nil end
    return se.mcu_id
end

local function takt()   -- jeder Wakeup (cockpit.lua): ohne session.batteryConfig BATTERY_CONFIG je Heli einmal, eine Frage zur Zeit, nach einer gescheiterten AKKU_PAUSE
    local rf = H.rf()
    if S == nil or rf == nil or type(rf.session) ~= "table" or type(rf.session.batteryConfig) == "table" then return end
    local heli = heliJetzt()
    if akkuFuer ~= heli then akku, akkuFuer = nil, nil end   -- ein anderer Heli oder keiner: die Werte des vorigen gelten nicht
    if heli == nil or akku ~= nil or frage.heli ~= nil or os.clock() < frage.ab then return end
    frage.heli = heli
    local ab = S.busLesen("lib/msp_battery_config.lua", function(d)
        frage.heli = nil
        if d == nil then frage.ab = os.clock() + AKKU_PAUSE
        elseif heliJetzt() == heli then akku, akkuFuer = d, heli end   -- eine spaete Antwort fuer den vorigen Heli gilt nicht
    end)
    if not ab then frage.heli, frage.ab = nil, os.clock() + AKKU_PAUSE end
end

local function oeffnen()
    if t == nil then return false, "i18n_teile.lua fehlt" end
    if stil == nil then
        local chunk, g = H.laden(loadfile, "stil_teile.lua")
        if not chunk then return false, "stil_teile.lua laedt nicht: " .. tostring(g) end
        local ok, s = pcall(chunk, {nova = nova, laden = H.laden})
        if not ok or type(s) ~= "table" then return false, "stil_teile.lua bricht ab: " .. tostring(s) end
        stil = s
        chunk, g = H.laden(loadfile, "seite_teile.lua")
        if not chunk then stil = nil return false, "seite_teile.lua laedt nicht: " .. tostring(g) end
        ok, s = pcall(chunk, {H = H, stil = stil})
        if not ok or type(s) ~= "table" then stil = nil return false, "seite_teile.lua bricht ab: " .. tostring(s) end
        S = s
    end
    takt()   -- die erste Frage gleich beim Oeffnen
    return true
end

local function verlassen()
    stil, S = nil, nil
end

return {malen = malen, ereignis = ereignis, oeffnen = oeffnen, verlassen = verlassen, takt = takt, zurueck = KEINE_ZONE, seite = true}
