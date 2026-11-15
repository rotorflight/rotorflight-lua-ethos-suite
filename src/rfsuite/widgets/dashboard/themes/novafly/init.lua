-- NovaFly-Cockpit als rfsuite-Theme: Name, eine Zustandsdatei fuer vor, im und nach dem Flug, das Menue mit der Farbe.
-- Gebaut fuer 480 x 320 und nur dort: kleinste und groesste Groesse sind dieselbe, die Listen von rfsuite zeigen es sonst nicht.
return {name = "NovaFly RC", preflight = "zustand.lua", inflight = "zustand.lua", postflight = "zustand.lua", configure = "configure.lua", standalone = false,
        minResolution = {x = 480, y = 320}, maxResolution = {x = 480, y = 320}}
