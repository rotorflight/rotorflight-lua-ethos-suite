-- VORFLUG: die Seite links vom Cockpit auf dessen Grund (seite_teile.lua S.grund); die Linien des Cockpits laufen von rechts
-- herein und klingen aus. Im Kopfband der Empfang als fuenf Balken links und rechts mit RSSI und VFR, dazwischen der Modellname;
-- links das Modellbild des Piloten mit weichem Rand, rechts eine Umrandung mit Akku (Stand, Spannung, Zellen, Kapazitaet), Zelle
-- und Verbrauch, offen zum rechten Rand; im Fussband vier Chips mit dem letzten Flug: Hoehe, Steigen, Sinken, Flugzeit.
-- Geoeffnet und geschlossen wird die Seite durch Wischen quer (cockpit.lua).
local H = ...
local floor = math.floor

local FOTO = {x = 10, y = 66, h = 168}           -- das Fotofeld, 4:3 aus der Hoehe; dieselben Masse hat der Fotorand (gfx/fotorand*.png)
local BALKEN = {links = 12, rechts = 438, unten = 36, breite = 4, schritt = 6}   -- fuenf Empfangsbalken wie am Sender, steigend 6 bis 18
local RSSI_STUFEN = {42, 50, 60, 70, 85}         -- dB je Balken; 42 ist die Warnschwelle des Senders
local VFR_STUFEN = {20, 40, 60, 80, 95}          -- Prozent je Balken
local KOPF_Y = 28                                 -- die Mitte des Kopfbands (y 8-47)
local AKKU = {x = 246, y = 66, w = 234, h = 174}  -- die Umrandung rechts, offen zum Rand; unten bei 240 wie der Chip der Bankseite gegenueber, alles parallel
local FUSS = {y = 262, h = 48, w = 112, luecke = 6, x = 10}
local KEINE_ZONE = {x = 0, y = 0, w = 0, h = 0}   -- ZURUECK gibt es auf einer Seite nicht: zurueck geht das Wischen

local t = H.i18n
local stil, S = nil, nil
local nova = {dirty = false, armLage = "unbekannt", flugbuch = {}, hohesDetail = true, kursiv = nil, i18n = t}   -- Senderschrift, keine Masken
local BILDER = H.merk.bilder or {}   -- Foto und Fotorand bleiben ueber das Schliessen der Seite hinaus geladen: jedes Oeffnen lud sie
H.merk.bilder = BILDER               -- sonst neu, und der X18 blieb stehen
local foto = nil
local akku = nil   -- ohne rfsuite.session (Robs master): BATTERY_CONFIG, beim Oeffnen einmal ueber den Bus gelesen

local function fotoLaden()   -- das Modellbild, das der Pilot in Ethos dem Modell gegeben hat; den Ort auf der Karte kennt das Cockpit (H.bildPfad)
    if foto ~= nil or BILDER.foto == false then return end
    if BILDER.foto ~= nil then foto = BILDER.foto return end
    local pfad = nil
    if type(model) == "table" and type(model.bitmap) == "function" then
        local ok, b = pcall(model.bitmap)
        if ok and type(b) == "string" and b ~= "" and not b:find("default_", 1, true) then pfad = H.bildPfad(b) end
    end
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

local function zahl(v, muster)
    if v == nil then return "--", stil.FELD_LEISE end
    if muster == nil then v = floor(v + 0.5) end   -- ganze Zahl: %d nimmt keinen Bruch
    return string.format(muster or "%d", v), H.farben.gruen
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
    empfang(BALKEN.links, stufen(s.rssi, RSSI_STUFEN), link)
    empfang(BALKEN.rechts, stufen(s.vfr, VFR_STUFEN), link)
    local z, f
    if s.rssi ~= nil then z = zahl(s.rssi) S.zeileLinks(46, KOPF_Y + 1, {{z, link, FONT_S}, {"dB", stil.WEISS, FONT_XS}}) end   -- ohne Wert nur die leeren Balken, keine Striche
    if s.vfr ~= nil then z = zahl(s.vfr) S.zeileRechts(432, KOPF_Y + 1, {{"VFR", stil.WEISS, FONT_XS}, {z, link, FONT_S}}) end
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
    if type(bc) ~= "table" then bc = akku end
    local kap = type(bc) == "table" and tonumber(bc.batteryCapacity) or nil
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
    local rf = H.rf()
    if akku == nil and not (rf and rf.session and type(rf.session.batteryConfig) == "table") then
        S.busLesen("lib/msp_battery_config.lua", function(d) akku = d end)
    end
    return true
end

local function verlassen()
    stil, S = nil, nil
end

return {malen = malen, ereignis = ereignis, oeffnen = oeffnen, verlassen = verlassen, zurueck = KEINE_ZONE, seite = true}
