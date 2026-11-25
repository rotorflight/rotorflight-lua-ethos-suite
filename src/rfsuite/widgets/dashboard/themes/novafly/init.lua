-- NovaFly cockpit as a dashboard theme: its name, one state file for before, during and after the flight, the menu with the colour.
-- Drawn for 480 x 320 (X18, X18S), 640 x 360 (X14, X14S, X14RS) and 800 x 480 (X20, X18R, X18RS): the layout follows the window, lines, corners
-- and the notch have their own size per screen (frame.lua). rfsuite 2.3.0 compares minResolution with the window of its
-- settings page (lcd.getWindowSize, 472 x 287 on the X18), not with the screen; a larger minimum takes the theme off the list.
return {name = "NovaFly", preflight = "state.lua", inflight = "state.lua", postflight = "state.lua", configure = "configure.lua", standalone = false,
        minResolution = {x = 472, y = 287}, maxResolution = {x = 800, y = 480}}
