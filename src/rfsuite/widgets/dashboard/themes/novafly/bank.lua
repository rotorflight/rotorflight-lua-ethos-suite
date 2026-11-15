-- BANK im NovaFly-Theme: das Bild malt der Code aus novasetup/lib/screen_bank.lua (ab "local W_Y" wortgleich), mit den
-- Zeichenteilen aus stil_teile.lua. Der FC-Weg geht ueber rfsuites MSP-Schlange: gelesen wird die Bank, auf der der FC
-- steht; gestellt wird mit Minus und Plus (Rad und Wischen nimmt rfsuites Dashboard fuer sich), gespeichert wird der
-- GANZE Satz der Bank mit der einen Aenderung - rfsuite fuellt jedes nicht gesetzte Feld mit dem Werkswert
-- (core.lua buildFullPayload) -, danach zurueckgelesen und Feld fuer Feld verglichen. Geschrieben wird nur am Boden.
local H = ...
local floor = math.floor

local BILD = "canvas.png"
local ZEITABLAUF = 14.0
local DRIFT, QUITT_DAUER = 12, 0.22
local TOUCH_LANG = rawget(_G, "TOUCH_LONG")
local SP_X, SP_B, SP_Y, SP_H = 14, 144, 54, 186
local SP_LUECKE = 10
local API_DZ, FELD_DZ = "GOVERNOR_PROFILE", "governor_headspeed"
local NUR_LESBAR = {STATUS = {"flight_mode_flags", "current_pid_profile_index"}}   -- Kommandos ohne Feldliste in rfsuite und die Felder, die da sein muessen
local FELD_PROZENT = "governor_max_throttle"
local G_RX = 446
local STELL_B, STELL_H, STELL_Y, STELL_TIPP = 22, 44, 38, 48

local t = H.i18n   -- die Texte in der Sprache des Senders (i18n_teile.lua), dieselben wie in NovaFly

local stil = nil
local nova = {dirty = false, armLage = "unbekannt", flugbuch = {}, hohesDetail = true, kursiv = H.kursiv, i18n = t}
local bildNr = 0
local ui = {rad = {zone = nil, stellt = false}, quittung = {zone = nil, bis = 0}}
local seite = {}

function ui.flaeche() return 480, 320 end
function ui.hell(zone, farbe)
    if ui.quittung.zone ~= nil and ui.quittung.zone == zone then return stil.WEISS end
    return farbe
end
function ui.radZone() return ui.rad.zone end
function ui.radLoesen() ui.rad.stellt = false end
function ui.piep() H.ton(880, 120) end

function nova.flugbuch.schlepp(i)
    local sl = H.schlepp[i]
    if sl == nil then return nil end
    return {min = sl.min, max = sl.max}
end

local function modellJetzt() return (H.stand() or {}).modell or "" end
local function govModusGemerkt()                -- der Modus ist je Modell fest: beim naechsten Oeffnen steht die Einheit sofort, gelesen wird trotzdem neu
    local m = H.merk.govModus
    if type(m) == "table" and m.modell == modellJetzt() and type(m.wert) == "number" then return m.wert end
    return nil
end
local govModus = govModusGemerkt()
local govLesen, govGelesen, govVersuche = false, false, 0
local GOV_VERSUCHE_MAX = 3
local escModus = nil
local function prozent() return govModus == 1 or govModus == 2 end
local function feld() return prozent() and FELD_PROZENT or FELD_DZ end
local function wertVon(g)
    if g == nil or govModus == nil then return nil end
    if prozent() then return g.maxgas end
    return g.drehzahl
end

local ZONEN = {zurueck   = {x = 118, y = 256, w = 118, h = 44},
               speichern = {x = 244, y = 256, w = 118, h = 44}}
for i = 1, 3 do
    ZONEN["b" .. i] = {x = SP_X + (i - 1) * (SP_B + SP_LUECKE), y = SP_Y,
                       w = SP_B, h = SP_H}
end
local ZONEN_NAMEN = {"speichern", "b1", "b2", "b3"}
seite.ZONEN = ZONEN

local function gesehenHolen()   -- die gelesenen Baenke liegen je Heli beim Cockpit: der Schirm wird beim Schliessen entladen, der Merker nicht
    local m = H.merk.bank
    if type(m) ~= "table" or m.modell ~= modellJetzt() then
        m = {modell = modellJetzt(), baenke = {}}
        H.merk.bank = m
    end
    return m.baenke
end
local gesehen = gesehenHolen()
local frisch = {}
local bank = nil
local hsGezeigt = nil
local nachName = nil

local function bankJetzt()
    local s = H.stand() or {}
    return (s.bank and floor(s.bank)) or bank
end
local zustand, meldung = "laedt", ""
local laeuft, start = false, nil
local vorgang = 0
local bildDa = nil
local bildSperre = false
local letzteBank = nil
local wahl = nil
local durchlese, durchleseGrund = nil, nil
local erstlesungWiederholt = false
local nachlesenAb = nil
local neuVersuchAb = 0
local soll, sollBank = nil, nil
local hinweis = ""
local geprueftAusstehend = false
local speicherStufe, speicherBis = nil, 0
local arbeitSeit, arbeitGemalt = nil, nil

local function rf() return H.rf() end

local function verbunden()
    local r = rf()
    if not r or not r.session then return false end
    if r.session.isConnected ~= nil then return r.session.isConnected == true end
    return r.session.telemetryState == true and r.session.apiVersion ~= nil
end

local function mspBereit()
    local r = rf()
    if r == nil or r.tasks == nil then return false end
    if type(r.tasks.active) == "function" then
        local ok, lebt = pcall(r.tasks.active)
        if ok and lebt ~= true then return false end
    end
    return r.tasks.msp ~= nil and r.tasks.msp.api ~= nil and type(r.tasks.msp.api.load) == "function"
end

local function queueFrei()
    local r = rf()
    if not r or not r.tasks or not r.tasks.msp then return false end
    local q = r.tasks.msp.mspQueue
    if q and type(q.isProcessed) == "function" then
        local ok, res = pcall(q.isProcessed, q)
        if ok then return res == true end
    end
    return true
end

local function schreibsperre()                 -- unbekannte Arm-Lage zaehlt als scharf
    if not verbunden() then return "arm_unbekannt" end
    local s = H.stand() or {}
    if s.scharf == false then return nil end
    if s.scharf == true then return "armiert" end
    return "arm_unbekannt"
end

function ui.ohneHeli()
    if rf() == nil then return t.f_kein_rfsuite end
    if not verbunden() then return t.f_kein_heli end
    return nil
end

local function apiLaden(name)
    if not mspBereit() then return nil, "msp_nicht_bereit" end
    local ok, api = pcall(rf().tasks.msp.api.load, name)
    if not ok or type(api) ~= "table" then return nil, "load_fehler" end
    return api
end

local function einreihen(fn)
    local pok, ok, grund = pcall(fn)
    if not pok then return false, "load_fehler" end
    if ok == false then
        if grund == "duplicate" or grund == "busy" then return false, "spaeter" end
        return false, tostring(grund or "nicht_eingereiht")
    end
    return true
end

local function lesenApi(name, fertig, fehler, nurWennFrei)   -- jedes Feld der Feldliste von rfsuite; fehlt ein Pflichtfeld, gilt die Antwort nicht
    if not verbunden() then fehler("keine_verbindung") return false end
    if nurWennFrei and not queueFrei() then fehler("spaeter") return false end
    local api, grund = apiLaden(name)
    if not api then fehler(grund) return false end
    local felder = api.__rfReadStructure
    if type(felder) ~= "table" or #felder == 0 then felder = api.__rfWriteStructure end
    local einmal = false
    api.setCompleteHandler(function()
        if einmal then return end
        einmal = true
        local okD, d = nil, nil
        if type(felder) ~= "table" or #felder == 0 then
            okD, d = pcall(api.data)
            felder = (okD and type(d) == "table") and d.structure or nil
        end
        if type(felder) ~= "table" or #felder == 0 then
            local pflicht = NUR_LESBAR[name]   -- einem nur lesbaren Kommando gibt rfsuite keine Feldliste: die Werte stehen mit Namen in parsed
            local gelesen = (okD and type(d) == "table") and d.parsed or nil
            if pflicht == nil or type(gelesen) ~= "table" then fehler("keine_struktur") return end
            local werte = {}
            for k, v in pairs(gelesen) do werte[k] = v end
            for i = 1, #pflicht do
                if werte[pflicht[i]] == nil then fehler("unvollstaendig") return end   -- fehlt ein Pflichtfeld, gilt die Antwort nicht
            end
            fertig(werte, nil)
            nova.dirty = true
            return
        end
        local werte = {}
        for i = 1, #felder do
            local e = felder[i]
            if type(e) == "table" and e.field then
                local ok, v = pcall(api.readValue, e.field)
                if ok and v ~= nil then
                    werte[e.field] = v
                elseif e.mandatory ~= false then
                    fehler("unvollstaendig")
                    return
                end
            end
        end
        fertig(werte, felder)
        nova.dirty = true
    end)
    api.setErrorHandler(function()
        if einmal then return end
        einmal = true
        fehler("lesefehler")
    end)
    local ok, g2 = einreihen(api.read)
    if not ok then einmal = true fehler(g2) return false end
    return true
end

local function ganzSchreiben(name, satz, felder, fertig, fehler)   -- jedes Feld gesetzt: was fehlt, fuellt rfsuite mit dem Werkswert
    local api, grund = apiLaden(name)
    if not api then fehler(grund) return false end
    if type(api.setRebuildOnWrite) == "function" then pcall(api.setRebuildOnWrite, true) end
    for i = 1, #felder do
        local e = felder[i]
        if type(e) == "table" and e.field then
            if satz[e.field] == nil then fehler("unvollstaendig") return false end
            api.setValue(e.field, satz[e.field])
        end
    end
    local einmal = false
    api.setCompleteHandler(function()
        if einmal then return end
        einmal = true
        fertig()
    end)
    api.setErrorHandler(function()
        if einmal then return end
        einmal = true
        fehler("schreibfehler")
    end)
    local ok, g2 = einreihen(api.write)
    if not ok then einmal = true fehler(g2) return false end
    return true
end

local function eepromSchreiben(fertig, fehler)
    local api, grund = apiLaden("EEPROM_WRITE")
    if not api then fehler(grund) return false end
    local einmal = false
    api.setCompleteHandler(function()
        if einmal then return end
        einmal = true
        fertig()
    end)
    api.setErrorHandler(function()
        if einmal then return end
        einmal = true
        fehler("eeprom_fehler")
    end)
    local ok, g2 = einreihen(api.write)
    if not ok then einmal = true fehler(g2) return false end
    return true
end

local function bankNr(name)
    for i = 1, 3 do if name == "b" .. i then return i end end
    return nil
end

local function grenzen()            -- min / max / Schritt kommen aus rfsuite, nie von hier
    local f = nachName and nachName[feld()]
    if f == nil or type(f.min) ~= "number" or type(f.max) ~= "number" then return nil end
    local schritt = (type(f.step) == "number" and f.step > 0) and f.step or 1
    return f.min, f.max, schritt
end

local function geaendert()
    if soll == nil or sollBank == nil then return false end
    local g = gesehen[sollBank]
    return g ~= nil and wertVon(g) ~= nil and soll ~= wertVon(g)
end

local function fehlerMelden(g)
    if g == "spaeter" then
        laeuft, nachlesenAb = false, os.clock() + 1
        if zustand ~= "bereit" then zustand = "wartet" end
        nova.dirty = true
        return
    end
    zustand, meldung, laeuft = "fehler", t.klartext(g), false
    nova.dirty = true
end

local function stehtAuf(st) return (st.current_pid_profile_index or -1) + 1 end
local function scharfLautFc(st)                -- STATUS flight_mode_flags Bit 0 = ARMED: der FC selbst, nicht der Sensor
    local f = type(st) == "table" and st.flight_mode_flags or nil
    return type(f) == "number" and floor(f) % 2 == 1
end

local function lesen()
    if zustand ~= "bereit" then zustand = "laedt" end
    laeuft, start = true, os.clock()
    vorgang = vorgang + 1
    local dieser = vorgang

    local ok = lesenApi("STATUS", function(st)
        if dieser ~= vorgang then return end
        start = os.clock()
        local b = st.current_pid_profile_index
        bank = (b ~= nil) and (b + 1) or nil
        zustand, meldung = "bereit", ""
        nova.dirty = true
        lesenApi(API_DZ, function(gp, felder)
            if dieser ~= vorgang then return end
            start = os.clock()
            local neu = {drehzahl = gp[FELD_DZ], maxgas = gp[FELD_PROZENT]}   -- erst gesammelt, in die Bank erst, wenn STATUS danach dieselbe Bank nennt
            nachName = {}
            for i = 1, #felder do
                if type(felder[i]) == "table" and felder[i].field then nachName[felder[i].field] = felder[i] end
            end
            lesenApi("STATUS", function(st2)
                if dieser ~= vorgang then return end
                start = os.clock()
                local steht2 = stehtAuf(st2)
                if bank ~= nil and steht2 ~= bank then
                    if not erstlesungWiederholt then erstlesungWiederholt = true; lesen(); return end
                    bank = (steht2 >= 1 and steht2 <= 3) and steht2 or nil
                    laeuft = false
                    nova.dirty = true
                    return
                end
                if bank ~= nil and neu.drehzahl ~= nil then
                    gesehen[bank] = gesehen[bank] or {}
                    gesehen[bank].drehzahl, gesehen[bank].maxgas = neu.drehzahl, neu.maxgas
                    frisch[bank] = true
                end
                laeuft = false
                nova.dirty = true
            end, function(g) if dieser == vorgang then fehlerMelden(g) end end)
        end, function(g) if dieser == vorgang then fehlerMelden(g) end end)
    end, fehlerMelden, true)
    if ok == false then laeuft = false end
end

local function speichern()
    if laeuft then hinweis = t.k_warten; return end
    if zustand ~= "bereit" then return end
    if not geaendert() then hinweis = t.f_nichts_geaendert; return end
    local sperre = schreibsperre()
    if sperre then hinweis = t.klartext(sperre); return end

    local b, wert, f = sollBank, soll, feld()   -- das Feld JETZT festhalten: wechselt der Governor-Modus, bis STATUS antwortet, gehoert die Zahl der alten Einheit
    laeuft, start = true, os.clock()
    vorgang = vorgang + 1
    local dieser = vorgang
    hinweis = t.k_warten
    speicherStufe, speicherBis = 0, 0
    local function rot(g)
        if dieser ~= vorgang then return end
        laeuft, hinweis, speicherStufe = false, t.klartext(g), nil
        nova.dirty = true
    end
    local function daneben()
        gesehen[b] = nil
        soll, sollBank, speicherStufe = nil, nil, nil
        lesen()
        hinweis = t.klartext("abweichung")
        nova.dirty = true
    end
    local ok = lesenApi("STATUS", function(st)
        if dieser ~= vorgang then return end
        start = os.clock()
        if stehtAuf(st) ~= b or feld() ~= f then daneben(); return end   -- anderes Feld als beim Tipp: Max-Gas ginge als Drehzahl hinaus
        if scharfLautFc(st) then rot("armiert"); return end
        lesenApi(API_DZ, function(alt, felder)       -- der ganze Satz, wie er jetzt im FC steht
            if dieser ~= vorgang then return end
            start = os.clock()
            local sperre2 = schreibsperre()
            if sperre2 then rot(sperre2); return end
            local neu = {}
            for k, v in pairs(alt) do neu[k] = v end
            neu[f] = wert
            lesenApi("STATUS", function(st1)   -- unmittelbar vor dem Schreiben: der Satz geht in die Bank, auf der der FC JETZT steht
                if dieser ~= vorgang then return end
                start = os.clock()
                if stehtAuf(st1) ~= b then daneben(); return end
                if scharfLautFc(st1) then rot("armiert"); return end
                speicherStufe = 1
                ganzSchreiben(API_DZ, neu, felder, function()
                    if dieser ~= vorgang then return end
                    start = os.clock()
                    speicherStufe = 2
                    nova.dirty = true
                    lesenApi(API_DZ, function(nachher)   -- ruecklesen und vergleichen, DANN sichern: was der FC anders uebernahm, wird nie dauerhaft
                        if dieser ~= vorgang then return end
                        start = os.clock()
                        local gleich = true
                        for k, v in pairs(neu) do
                            if nachher[k] ~= v then gleich = false end
                        end
                        if not gleich then               -- der alte Satz geht zurueck in den FC, sonst sichert er den falschen selbst beim Entschaerfen
                            lesenApi("STATUS", function(st3)   -- nur in dieselbe Bank und nur am Boden: steht der FC schon auf einer anderen, kam das Ruecklesen von dort
                                if dieser ~= vorgang then return end
                                start = os.clock()
                                if stehtAuf(st3) ~= b then rot("schreiben_abgelehnt"); return end
                                if scharfLautFc(st3) then rot("armiert"); return end
                                local sperre3 = schreibsperre()
                                if sperre3 then rot(sperre3); return end
                                ganzSchreiben(API_DZ, alt, felder, function() if dieser == vorgang then daneben() end end,
                                              function() rot("abweichung") end)
                            end, rot)
                            return
                        end
                        lesenApi("STATUS", function(st2)  -- vor dem Sichern fragt der FC selbst: scharf oder andere Bank sichert nichts
                            if dieser ~= vorgang then return end
                            start = os.clock()
                            if scharfLautFc(st2) then rot("armiert"); return end
                            if stehtAuf(st2) ~= b then rot("schreiben_abgelehnt"); return end
                            eepromSchreiben(function()
                                if dieser ~= vorgang then return end
                                start = os.clock()
                                speicherStufe = 3
                                nova.dirty = true
                                lesenApi(API_DZ, function(gp)
                                    if dieser ~= vorgang then return end
                                    if gp[f] ~= wert then daneben(); return end
                                    laeuft = false
                                    gesehen[b] = gesehen[b] or {}
                                    if f == FELD_PROZENT then gesehen[b].maxgas = wert else gesehen[b].drehzahl = wert end
                                    soll, sollBank = nil, nil
                                    hinweis, geprueftAusstehend = "", true
                                    speicherStufe, speicherBis = 4, os.clock() + 2.0
                                    nova.dirty = true
                                end, rot)
                            end, rot)
                        end, rot)
                    end, function() rot("ruecklesen_offen") end)
                end, rot)
            end, rot)
        end, rot)
    end, rot)
    if ok == false then laeuft = false end
end

function seite.build()
    gesehen, frisch = gesehenHolen(), {}
    bank = nil
    nachlesenAb, neuVersuchAb = nil, 0
    zustand, meldung, laeuft = "laedt", "", false
    bildDa, wahl = nil, nil
    local s = H.stand() or {}
    letzteBank = s.bank and floor(s.bank) or nil   -- die Bank beim Oeffnen liest lesen() gleich selbst
    bildSperre = false
    erstlesungWiederholt = false
    soll, sollBank, hinweis, geprueftAusstehend = nil, nil, "", false
    govModus, govGelesen, govVersuche = govModusGemerkt(), false, 0
    speicherStufe, arbeitSeit, arbeitGemalt = nil, nil, nil
    ui.rad.zone, ui.rad.stellt, ui.quittung.zone = nil, false, nil
    lesen()
end

function seite.leave()
    vorgang = vorgang + 1                  -- offene Rueckrufe laufen ins Leere
    laeuft = false
    erstlesungWiederholt = false
end

function seite.stellbar(name)                  -- nur die Bank, auf der der FC steht, und nur wenn geschrieben werden darf
    local i = bankNr(name)
    if i == nil or bank ~= i or bankJetzt() ~= i then return false end
    if zustand ~= "bereit" or laeuft or durchlese == "laeuft" or bildSperre then return false end
    if govModus == nil or gesehen[i] == nil or wertVon(gesehen[i]) == nil or grenzen() == nil then return false end
    return schreibsperre() == nil
end

function seite.stellen(name, richtung)
    local i = bankNr(name)
    if not seite.stellbar(name) then return end
    local lo, hi, schritt = grenzen()
    if soll == nil or sollBank ~= i then soll, sollBank = wertVon(gesehen[i]), i end
    soll = math.max(lo, math.min(hi, soll + richtung * schritt))
    hinweis = ""
    nova.dirty = true
end

local function stellZonen()                    -- Minus und Plus an der Zahl der Bank, die gerade gestellt wird
    local i = bankJetzt()
    if i == nil or not ui.rad.stellt or ui.rad.zone ~= "b" .. i then return nil end
    local z = ZONEN["b" .. i]
    return {x = z.x, y = z.y + STELL_Y - 8, w = STELL_TIPP, h = STELL_H + 16},
           {x = z.x + z.w - STELL_TIPP, y = z.y + STELL_Y - 8, w = STELL_TIPP, h = STELL_H + 16}, z
end

local function ausloesen(name)
    nova.dirty = true
    if name == "speichern" then speichern(); return end
    local i = bankJetzt()
    if name == "minus" or name == "plus" then
        if i == nil then return end
        if not seite.stellbar("b" .. i) then
            ui.radLoesen()
            local sperre = schreibsperre()
            if sperre then hinweis = t.klartext(sperre) end
            return
        end
        seite.stellen("b" .. i, (name == "plus") and 1 or -1)
        return
    end
    local n = bankNr(name)
    if n == nil then return end
    hinweis = ""
    if n == i then
        wahl = nil
        ui.rad.zone, ui.rad.stellt = name, seite.stellbar(name)
        if not ui.rad.stellt then
            local sperre = schreibsperre()
            if sperre then hinweis = t.klartext(sperre) end
        end
        return
    end
    ui.rad.zone, ui.rad.stellt = nil, false
    wahl = (wahl ~= n) and n or nil
end

local W_Y, W_H = 118, 60
local UNBEKANNT = "?"

local function abweichung(zeichen, wert, ref)  -- "-13 %" / "+4 %": wie weit die Drehzahl unter oder ueber der lag, bei der die Bank ruhig stand
    if ref == nil or ref <= 0 then return zeichen end
    return zeichen .. tostring(math.floor(math.abs(wert - ref) / ref * 100 + 0.5)) .. " %"
end

local function wertZeile(fx, fw, y, wort, zahl, farbe)
    stil.beschriftung(fx + 20, y, wort, stil.FELD_LEISE, FONT_STD)
    stil.beschriftungRechts(fx + fw - 20, y,
                            zahl and tostring(zahl) or UNBEKANNT,
                            zahl and farbe or stil.FELD_LEISE, FONT_L)
end

local function klammer(i, dz, laufend)         -- die andere Einheit, rechts unter der grossen Zahl: zum Max-Gas die Drehzahl, zur Drehzahl das Gas in % - verhaeltnisgleich
    local inProzent = laufend or not prozent()  -- aus dem Paar Drehzahl/Gas des letzten ruhigen Flugs dieser Bank (Flugbuch), ohne Paar "?"; dreht der Rotor, das Gas des FC jetzt
    local fb = nova.flugbuch
    local zahl = nil
    if laufend then
        zahl = fb and fb.gasJetzt and fb.gasJetzt()
    else
        local sl = fb and fb.schlepp and fb.schlepp(i)
        if sl ~= nil and sl.gas ~= nil and sl.gas > 0 and sl.ref ~= nil and sl.ref > 0 and dz ~= nil then
            zahl = inProzent and (dz / sl.ref * sl.gas) or (dz / sl.gas * sl.ref)
        end
    end
    local wort = inProzent and "%" or t.wort("U/MIN")
    if zahl == nil or zahl < 0 then return nil end   -- ohne Paar aus dem Flugbuch steht nichts da, kein "(? %)"
    return "(" .. tostring(math.floor(zahl + 0.5)) .. " " .. wort .. ")"
end

local function governorUrteil()                -- wer regelt die Drehzahl: der FC bei ELECTRIC/NITRO (gov_mode 3/4), der Hobbywing bei flight_mode 2/3
    if type(govModus) ~= "number" or escModus == nil then return nil end
    if escModus == false then return "?", stil.FELD_LEISE, "ESC" end   -- kein Datensatz: der ESC nennt seinen Modus nicht
    local fc, esc = (govModus == 3 or govModus == 4), (escModus == 2 or escModus == 3)
    if fc and esc then return "ZWEI", stil.ROT, nil end
    if fc then return "EINER", stil.GRUEN, "FC" end
    if esc then return "EINER", stil.GRUEN, "ESC" end
    return "NIEMAND", stil.GELB, nil
end

function seite.paint()
    local bw, bh = ui.flaeche()
    bildDa = stil.bildGrund(0, 0, bw, bh, BILD)
    if bildDa == false then stil.hintergrund(0, 0, bw, bh) end

    stil.titel("BANK")

    for i = 1, 3 do
        local z = ZONEN["b" .. i]
        local fx, fy, fw, fh = z.x, z.y, z.w, z.h
        local aktiv = (bankJetzt() == i)
        local gewaehlt = (wahl == i)
        local stellt = aktiv and ui.rad.stellt and ui.rad.zone == "b" .. i   -- das Rad stellt die Drehzahl: weisser Rand wie beim Anwaehlen
        local g = gesehen[i]
        local dz = g and wertVon(g)
        local gestellt = (dz ~= nil and sollBank == i and soll ~= nil and soll ~= dz)
        if gestellt then dz = soll end
        local dreht = aktiv and hsGezeigt ~= nil and hsGezeigt > 0
        local laufend = dreht and (nova.armLage == "scharf" or not gestellt)   -- wie der Tacho - steht der Rotor, steht der gespeicherte Wert da - Auch wenn das Rad auf der Bank steht - nur wer entschaerft gerade stellt, sieht seine Zahl
        if laufend then dz, gestellt = hsGezeigt, false end
        local akzent =(stellt and stil.WEISS) or (aktiv and stil.CYAN) or (gewaehlt and stil.WEISS) or nil
        stil.feld(fx, fy, fw, fh, akzent,
                  (aktiv or gewaehlt) and "gewaehlt" or nil)
        local kopfFarbe = (aktiv and stil.CYAN) or (gewaehlt and stil.WEISS)
                          or (dz and stil.LINIE) or stil.FELD_LEISE
        local amRad = (ui.radZone(seite) == "b" .. i)     -- die aktive Bank ist schon blau: unter dem Rad wird ihr Wort weiss
        stil.beschriftungPasst(fx + 14, fy + 8, "BANK " .. i,
                               (amRad and kopfFarbe == stil.CYAN) and stil.WEISS or ui.hell("b" .. i, kopfFarbe),
                               FONT_STD, 66)
        if aktiv then
            stil.chip(fx + fw - 12, fy + 16, "AKTIV", stil.CYAN, FONT_S)
        end
        local wertFarbe = (aktiv and stil.CYAN) or stil.WEISS
        if dz then
            stil.beschriftungMittig(fx + fw / 2, fy + 60,
                                    tostring(math.floor(dz)),
                                    gestellt and stil.GELB or wertFarbe, FONT_XXL)
            stil.beschriftungMittig(fx + fw / 2, fy + 92, (laufend or not prozent()) and "U/MIN" or "%",
                                    stil.FELD_LEISE, FONT_S)
            local kl = klammer(i, dz, laufend)
            if kl ~= nil then stil.beschriftungRechts(fx + fw - 14, fy + 102, kl, stil.FELD_LEISE, FONT_S) end
        else
            stil.leerstrich(fx + fw / 2, fy + 62, stil.FELD_LEISE)
            if gesehen[i] == nil then           -- gelesen, aber der Governor-Modus fehlt noch: nur der Strich, kein Wort
                stil.beschriftungMittigPasst(fx + fw / 2, fy + 90, "NICHT GELESEN",
                                             stil.FELD_LEISE, FONT_STD, 120)
            end
        end
        stil.rahmen({x = fx + 10, y = fy + W_Y, w = fw - 20, h = W_H},
                    akzent or stil.FELD_LEISE)
        local sl = nova.flugbuch and nova.flugbuch.schlepp and nova.flugbuch.schlepp(i)   -- P und I stehen auf PRO
        wertZeile(fx, fw, fy + W_Y + 6, sl and abweichung("-", sl.min, sl.ref) or "-", sl and math.floor(sl.min + 0.5), wertFarbe)
        wertZeile(fx, fw, fy + W_Y + 32, sl and abweichung("+", sl.max, sl.ref) or "+", sl and math.floor(sl.max + 0.5), wertFarbe)
    end

    local urteil, uFarbe, wer = governorUrteil()
    if urteil ~= nil then                      -- WER REGELT, oben rechts neben dem Titel: EINER (FC oder ESC), ZWEI rot, NIEMAND gelb, ? ohne ESC-Datensatz
        stil.beschriftungRechts(G_RX, 6, "GOVERNOR", ui.hell("governor", stil.FELD_LEISE), FONT_S)
        stil.beschriftungRechts(G_RX, 20, urteil, uFarbe, FONT_STD)
        if wer ~= nil then
            local ub = stil.mass(urteil, FONT_STD)
            stil.beschriftungRechts(G_RX - (ub or 0) - 8, 23, wer, stil.FELD_LEISE, FONT_S)
        end
    end

    local spFarbe = (zustand == "bereit" and geaendert()) and stil.GRUEN or stil.LEISE
    stil.fusszeile(stil.FUSS_Y, "ZURUECK", ui.hell("zurueck", stil.WEISS),
                   "SPEICHERN", ui.hell("speichern", spFarbe), FONT_L, FONT_L)

    local ohne = ui.ohneHeli()
    local deckel = nil                                   -- regelt der FC die Drehzahl, deckelt das Max-Gas seinen Ausgang: 99 gilt als voll, darunter rot
    if not prozent() then
        local teile = {}
        for i = 1, 3 do
            local g = gesehen[i]
            if g ~= nil and g.maxgas ~= nil and g.maxgas < 99 then
                teile[#teile + 1] = "BANK " .. i .. " " .. tostring(math.floor(g.maxgas)) .. " %"
            end
        end
        if #teile > 0 then deckel = t.wort("MAX-GAS") .. " " .. table.concat(teile, ", ") end
    end
    if zustand == "fehler" then
        stil.meldezeile(meldung, stil.ROT)
    elseif durchlese == "rueckfehler" and durchleseGrund ~= nil then
        stil.meldezeile(t.grundtext(durchleseGrund), stil.ROT)
    elseif bildSperre then
        stil.meldezeile("Bild fehlt - Tippen gesperrt", stil.ROT)
    elseif ohne ~= nil then
        stil.meldezeile(ohne, stil.ROT)
    elseif hinweis ~= "" then
        stil.meldezeile(hinweis, stil.GELB)
    elseif zustand ~= "bereit" or durchlese == "laeuft" then
        stil.meldezeile(t.laeuft, stil.LEISE)
    elseif durchlese == "gehalten" and durchleseGrund ~= nil then
        stil.meldezeile(t.grundtext(durchleseGrund), stil.GELB)
    elseif deckel ~= nil then
        stil.meldezeile(deckel, stil.ROT)
    end
end

local function arbeitFelder()
    if arbeitSeit == nil then return 0 end
    return math.max(0, math.min(stil.BALKEN_FELDER - 1, floor(os.clock() - arbeitSeit)))
end

local function malen()
    if stil == nil then return end
    bildNr = bildNr + 1
    nova.hohesDetail = (bildNr > 1)            -- das erste Bild nach dem Oeffnen malt die Felder flach (der Sparmodus aus NovaFly): es misst schon alle Woerter
    if bildNr == 1 then nova.dirty = true end
    if bildNr == 2 then H.kursiv.sparen() end  -- das zweite rechnet den Glanz der Felder: die Woerter kommen ab dem dritten
    stil.fensterFrisch()
    stil.bandGemalt, stil.fussGemalt = false, false
    stil.balkenGemalt, stil.arbeitGewuenscht = nil, false
    stil.bandEnde = nil
    seite.paint()
    local minus, plus, z = stellZonen()
    if minus ~= nil then
        stil.flaecheRund(z.x + 4, z.y + STELL_Y, STELL_B, STELL_H, stil.BALKEN_BETT)
        stil.beschriftungMittig(z.x + 4 + STELL_B / 2, z.y + STELL_Y + STELL_H / 2, "-", stil.WEISS, FONT_L)
        stil.flaecheRund(z.x + z.w - 4 - STELL_B, z.y + STELL_Y, STELL_B, STELL_H, stil.BALKEN_BETT)
        stil.beschriftungMittig(z.x + z.w - 4 - STELL_B / 2, z.y + STELL_Y + STELL_H / 2, "+", stil.WEISS, FONT_L)
    end
    if speicherStufe ~= nil then
        stil.speicherbalken(speicherStufe)
        arbeitSeit, arbeitGemalt = nil, nil
    elseif stil.arbeitGewuenscht then
        if arbeitSeit == nil then arbeitSeit = os.clock() end
        arbeitGemalt = arbeitFelder()
        stil.arbeitsbalken(arbeitGemalt)
    else
        arbeitSeit, arbeitGemalt = nil, nil
    end
end

local function takt()
    if stil == nil then return end
    local s = H.stand() or {}
    nova.armLage = (s.scharf == true) and "scharf" or ((s.scharf == false) and "sicher" or "unbekannt")
    if not govGelesen and not govLesen and not laeuft and zustand == "bereit" and mspBereit() and queueFrei() then   -- nach der Kette: welcher Governor-Modus (Drehzahl oder Max-Gas)
        govLesen = true
        local ok0 = lesenApi("GOVERNOR_CONFIG", function(gc)
            govLesen = false
            local vorher = govModus
            govModus = (type(gc.gov_mode) == "number") and gc.gov_mode or false
            if type(govModus) == "number" and vorher ~= nil and vorher ~= govModus then soll, sollBank = nil, nil end   -- anderer Modus als gemerkt: ein schon gestellter Wert traegt die falsche Einheit
            govGelesen = true
            if type(govModus) == "number" then H.merk.govModus = {modell = modellJetzt(), wert = govModus} end
            nova.dirty = true
        end, function()
            govLesen, govVersuche = false, govVersuche + 1
            if govVersuche >= GOV_VERSUCHE_MAX then govGelesen = true end
        end)
        if ok0 == false then govLesen = false end
    end
    if laeuft and start and os.clock() - start > ZEITABLAUF then
        vorgang = vorgang + 1
        laeuft, speicherStufe = false, nil
        if zustand == "laedt" then fehlerMelden("zeitablauf")
        elseif hinweis == t.k_warten then hinweis = t.klartext("zeitablauf"); nova.dirty = true end
    end
    if geprueftAusstehend and not laeuft then
        geprueftAusstehend = false
        ui.piep()
        nova.dirty = true
    end
    if nachlesenAb ~= nil and not laeuft and os.clock() >= nachlesenAb then
        nachlesenAb = nil                       -- die Leitung war belegt: jetzt nochmal
        lesen()
    end
    if zustand == "fehler" and not laeuft and mspBereit() and queueFrei() and os.clock() > neuVersuchAb then   -- Selbstheilung alle 3 s, nur nach einem Fehler
        neuVersuchAb = os.clock() + 3
        lesen()
    end
    local b = s.bank and floor(s.bank) or nil
    if soll ~= nil and b ~= nil and b ~= sollBank then   -- der Schalter liegt um: die gestellte Zahl gehoerte der alten Bank
        soll, sollBank, hinweis = nil, nil, ""
        ui.rad.zone, ui.rad.stellt = nil, false
        nova.dirty = true
    end
    if b ~= letzteBank and (b == nil or (queueFrei() and not laeuft)) then   -- waehrend eines Vorgangs bleibt der Wechsel offen, bis das Lesen starten kann
        letzteBank = b
        if b ~= nil then lesen() end
        nova.dirty = true
    end
    local hs = (s.rpm ~= nil and s.rpm > 0) and floor(s.rpm + 0.5) or nil
    if hs ~= hsGezeigt then hsGezeigt = hs; nova.dirty = true end
    if ui.quittung.zone ~= nil and os.clock() >= ui.quittung.bis then ui.quittung.zone = nil; nova.dirty = true end
    if speicherStufe == 4 and os.clock() >= speicherBis then speicherStufe = nil; nova.dirty = true end
    if arbeitSeit ~= nil and arbeitFelder() ~= arbeitGemalt then nova.dirty = true end
    if H.kursiv.unfertig then H.kursiv.unfertig = false; nova.dirty = true end
    if nova.dirty then
        nova.dirty = false
        lcd.invalidate()
    end
end

local druck = nil

local function zoneUnter(px, py)
    local minus, plus = stellZonen()
    if minus ~= nil and H.trifft(minus, px, py) then return "minus" end
    if plus ~= nil and H.trifft(plus, px, py) then return "plus" end
    for _, name in ipairs(ZONEN_NAMEN) do
        if H.trifft(ZONEN[name], px, py) then return name end
    end
    return nil
end

local function ereignis(widget, category, value, px, py)
    if category ~= EVT_TOUCH or stil == nil then return false end
    if value == TOUCH_START then
        local name = zoneUnter(px, py)
        druck = name and {zone = name, seit = os.clock(), x = px, y = py} or nil
        if name ~= nil then
            ui.quittung.zone, ui.quittung.bis = (name == "minus" or name == "plus") and nil or name, os.clock() + QUITT_DAUER
            lcd.invalidate()
        end
        return false
    end
    if value == TOUCH_MOVE then
        if druck and px and py and (math.abs(px - druck.x) > DRIFT or math.abs(py - druck.y) > DRIFT) then druck = nil end
        return false
    end
    if (value ~= TOUCH_END and value ~= TOUCH_LANG) or druck == nil then return false end   -- nach einem langen Druck schickt Ethos kein TOUCH_END
    local d = druck
    druck = nil
    ausloesen(d.zone)
    nova.dirty = false
    lcd.invalidate()
    return true
end

local function oeffnen()
    local grund = nil
    if t == nil then return false, "i18n_teile.lua fehlt" end
    if stil == nil then
        local chunk, g = H.laden(loadfile, "stil_teile.lua")
        if chunk then
            local ok, s = pcall(chunk, {nova = nova, laden = H.laden})
            if ok and type(s) == "table" then stil = s else grund = "stil_teile.lua bricht ab: " .. tostring(s) end
        else
            grund = "stil_teile.lua laedt nicht: " .. tostring(g)
        end
    end
    if stil == nil then return false, grund end
    bildNr = 0
    seite.build()
    return true
end

local function verlassen()
    seite.leave()
    stil = nil
end

return {malen = malen, ereignis = ereignis, oeffnen = oeffnen, verlassen = verlassen, takt = takt, zurueck = ZONEN.zurueck,
        blick = function() return gesehen, soll, zustand, hinweis, govModus, speicherStufe, bank end}
