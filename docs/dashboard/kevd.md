# KevD

Select KevD under **System → Settings → Dashboard → Themes**. It provides
preflight, inflight and postflight screens. Theme selection and configuration
are available offline while the Suite background task runs; model overrides
require a connected controller with a known MCU ID.

The full-screen header is 50 pixels high on 800-pixel displays and uses the
Ethos theme colors. The preflight model display retains its previous width
and height; the fuel panel below it adjusts to accommodate the taller header.
The advanced battery frame extends down to the visible bottom of the Blackbox
tile, with its percentage and battery details centered in the taller panel.
Preflight uses larger battery-detail text and larger Rates, Profile, Flights,
Blackbox and Governor card titles. The percentage font remains unchanged;
windowed layouts use smaller fonts to retain spacing.
Compact windows retain the native Ethos toolbar and omit the dashboard header.
The page background covers the entire window, including grid rounding gaps;
the header artwork also has a theme-colored backing across its full width.
Artwork scales to cover the header and is clipped to its height, so its own
edge colors fill the width even when they differ from the page background.
The transmitter battery sits near the right edge, with RSSI grouped beside it.
RSSI bars leave a clear gap above the header's lower edge. The theme artwork
fills the full header height, without an added accent line over it.
The transmitter battery gauge shares RSSI's top and bottom padding so neither
indicator reaches the header's lower edge.
Inflight ESC temperature and throttle arcs reserve space for their titles and
maximum readings. Throttle sits farther right to separate it from ESC details.
The ESC temperature rings leave a visible gap. The throttle gauge and its value,
maximum reading, and title sit five pixels higher.
Inflight panel backgrounds draw no sensor readout or missing-telemetry dots.
Throttle arcs are green through 70% and red above 70% through full throttle,
including the recorded maximum arc.
ESC temperature and throttle values use the shared adaptive font fitter within
their arc interiors, centered on the arcs in full-screen and windowed layouts.
The inflight advanced battery stack extends left into the space beside the
gauges. Timer, fuel frame, and governor panel share aligned edges. Battery
readings align right, and the shorter governor panel leaves a taller fuel
gauge. The FLIGHT TIME title uses a larger built-in font while the timer digits
retain their original size; no additional timer font is loaded.
The title sits close beneath the timer, with a cap above the battery frame.
The battery extends fourteen pixels upward toward the title; its five-pixel cap
has rounded ends and leaves the timer/title positions unchanged.
The stack's left inset trims its width by 15 pixels while its right edge stays fixed.
Compact windows use smaller fonts to preserve spacing.
Postflight keeps the inflight battery-stack width and governor-tile height.
The six postflight gauge values sit five pixels higher to clear their bottom borders.
The governor bottom aligns with the six gauges, and the battery extends down
to it. The six gauges move as one group, with balanced page-side margins and
the same gap beside the battery stack. Postflight also has a larger FLIGHT TIME
title and a small rounded battery cap; timer digits retain their original size.
Its voltage, cell voltage/count, and consumed-mAh readings share the largest
adaptive font that fits all three rows, with panel-relative row spacing for
full-screen and windowed views. With auto-detected cells and a pack voltage
below 2 V, the cell readout shows `-` instead of a guessed cell count.
Battery readings sit six pixels lower; the timer value is raised six pixels
and the FLIGHT TIME title eight pixels, without moving their frames.
Flights and Total Flight Time headings use larger resolution-specific fonts;
their numeric values retain the original theme font sizes. The FLIGHT TIME
caption keeps its separate font setting.
Only in full-screen view, the fuel percentage sits another 15 pixels lower
and the three battery-detail rows use the full inner width for larger text.
Windowed positions and adaptive text bounds are unchanged.

## Ethos theme artwork

KevD can reuse the bitmap supplied by an installed theme's `toolbarBackground`.
It shares the existing bitmap handle and does not load a second image. Install
the complete KevD folder, including `header_bridge.lua`, and add this optional
integration before the theme script's `init()` function:

```lua
local system = system
local headerBridge = loadfile("SCRIPTS:/rfsuite/widgets/dashboard/themes/kevd/header_bridge.lua")
if headerBridge then
    system = setmetatable({registerTheme = headerBridge().registerTheme}, {__index = system})
end
```

Keep the theme's existing `system.registerTheme(...)` calls. Restart scripts
after installing the integration. Without KevD installed, the theme continues
to register normally.

Ethos exposes neither the active theme key nor a toolbar bitmap getter, so
the bridge matches the active palette to the registered artwork, excluding
the user-adjustable highlight color. Themes with
identical exposed palettes but different artwork cannot be distinguished and
use a plain header. Built-in toolbar names (`light`/`dark`) and themes without
the integration also use the theme-colored plain header.

The bridge stores one numeric palette signature and an existing bitmap
reference per registered palette. It does not retain theme configuration or
color tables. Palette lookup happens when the page header is created; wakeup
and paint do not rebuild signatures, load images, or create cache tables.

Source: `src/rfsuite/widgets/dashboard/themes/kevd/`.
Checked with the Ethos 26.2.0-RC1 X20PRO simulator and desktop Lua 5.4;
physical-radio RAM and instruction limits remain hardware-specific.

Inflight fullscreen battery voltage, cell and mAh details share the largest font
that fits all three rows, using the full inner battery width. Windowed details use
the theme's original adaptive detail font; the fuel percentage is unchanged.

Preflight status-card titles and values sit 2 pixels lower in fullscreen and
4 pixels lower in windowed layouts to clear the upper borders without moving the frames.
