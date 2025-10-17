# Dashboard Objects

---

### API Version Widget

API Version Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if not present
    novalue             : string                    -- (Optional) Text shown if telemetry value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---

### Arc Gauge Widget

Arc Gauge Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
Title parameters
    title               : string    -- (Optional) Title text
    titlepos            : string    -- (Optional) If `title` is present but `titlepos` is not set, title is placed at the top by default.
    titlealign          : string    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font      -- (Optional) Title font (e.g., FONT_L, FONT_XL)
    titlespacing        : number    -- (Optional) Vertical gap between title and value
    titlecolor          : color     -- (Optional) Title text color (theme/text fallback)
    titlepadding        : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number    -- (Optional) Left padding for title
    titlepaddingright   : number    -- (Optional) Right padding for title
    titlepaddingtop     : number    -- (Optional) Top padding for title
    titlepaddingbottom  : number    -- (Optional) Bottom padding for title
Value/Source parameters
    value               : any       -- (Optional) Static value to display if telemetry is not present
    source              : string    -- Telemetry sensor source name (e.g., "voltage", "current")
    transform           : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number    -- (Optional) Number of decimal places for numeric display
    thresholds          : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue             : string    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string    -- (Optional) Unit label to append to value ("" hides, default resolves dynamically)
    font                : font      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color     -- (Optional) Value text color (theme/text fallback)
    valuepadding        : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number    -- (Optional) Left padding for value
    valuepaddingright   : number    -- (Optional) Right padding for value
    valuepaddingtop     : number    -- (Optional) Top padding for value
    valuepaddingbottom  : number    -- (Optional) Bottom padding for value
Maxval parameters
    arcmax              : bool      -- (Optional) Draw arcmac gauge within the outer arc (false by default)
    maxfont             : font      -- (Optional) Font for max value label (e.g., FONT_XS, FONT_S, FONT_M, default: FONT_S)
    maxtextcolor        : color     -- (Optional) Max text color (theme/text fallback)
    maxpadding          : number    -- (Optional) Padding (Y-offset) below arc center for max value label (default: 0)
    maxpaddingleft      : number    -- (Optional) Additional X-offset for max label (default: 0)
    maxpaddingtop       : number    -- (Optional) Additional Y-offset for max label (default: 0)
Appearance/Theming
    bgcolor             : color     -- (Optional) Widget background color (theme fallback)
    fillbgcolor         : color     -- (Optional) Arc background color (theme fallback)
    fillcolor           : color     -- (Optional) Arc foreground color (theme fallback)
    maxprefix           : string    -- (Optional) Prefix for max value label (default: "+")
Arc Geometry/Advanced
    min                 : number    -- (Optional) Minimum value of the arc (default: 0)
    max                 : number    -- (Optional) Maximum value of the arc (default: 100)
    thickness           : number    -- (Optional) Arc thickness in pixels
    gaugepadding        : number    -- (Optional) Horizontal-only padding applied to arc radius (shrinks arc from left/right only)
    gaugepaddingbottom  : number    -- (Optional) Extra space added below arc region, pushing arc upward (vertical only)


---

### Arm Flags Widget

Arm Flags Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if not present
    thresholds          : table                     -- (Optional) List of thresholds: {value=..., textcolor=...} for coloring ARMED/DISARMED states.
    novalue             : string                    -- (Optional) Text shown if telemetry value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value (not used here)
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
Example thresholds:
thresholds = {
    { value = "ARMED", textcolor = "green" },
    { value = "DISARMED", textcolor = "red" },
    { value = "Throttle high", textcolor = "orange" },
    { value = "Failsafe", textcolor = "orange" },
}


---

### Attitude Horizon Widget (AH)

Attitude Horizon Widget (AH)
    Configurable Parameters (box table fields):
    wakeupinterval      : number   -- Optional wakeup interval in seconds (default: 0.2)
    pixelsperdeg        : number   -- Pixels per degree for pitch & compass (default: 2.0)
    dynamicscalemin     : number   -- Minimum scale factor (default: 1.05)
    dynamicscalemax     : number   -- Maximum scale factor (default: 1.95)
    showarc             : bool     -- Show arc markers (default: true)
    showladder          : bool     -- Show pitch ladder (default: true)
    showcompass         : bool     -- Show compass ribbon (default: true)
    showaltitude        : bool     -- Show altitude bar on right (default: false)
    showgroundspeed           : bool     -- Show groundspeed bar on left (default: false)
    arccolor            : color    -- Color for arc markings (default: white)
    laddercolor         : color    -- Color for pitch ladder (default: white)
    compasscolor        : color    -- Color for compass (default: white)
    crosshaircolor      : color    -- Color for central cross marker (default: white)
    altitudecolor       : color    -- Color for altitude bar (default: white)
    groundspeedcolor          : color    -- Color for groundspeed bar (default: white)
    altitudemin         : number   -- Minimum displayed altitude (default: 0)
    altitudemax         : number   -- Maximum displayed altitude (default: 200)
    groundspeedmin            : number   -- Minimum displayed groundspeed (default: 0)
    groundspeedmax            : number   -- Maximum displayed groundspeed (default: 100)


---

### Bar Gauge Widget

Bar Gauge Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
Title/label
    title                   : string    -- (Optional) Title text
    titlepos                : string    -- (Optional) "top" or "bottom"
    titlealign              : string    -- (Optional) "center", "left", "right"
    titlefont               : font      -- (Optional) Title font (e.g., FONT_L)
    titlespacing            : number    -- (Optional) Vertical gap below title
    titlecolor              : color     -- (Optional) Title text color (theme/text fallback)
    titlepadding            : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft        : number    -- (Optional)
    titlepaddingright       : number    -- (Optional)
    titlepaddingtop         : number    -- (Optional)
    titlepaddingbottom      : number    -- (Optional)
Value/source
    value                   : any       -- (Optional) Static value to display if no telemetry
    hidevalue               : bool      -- (Optional) If true, do not display the value text (default: false; value is shown)
    source                  : string    -- (Optional) Telemetry sensor source name
    transform               : string|function|number -- (Optional) Value transformation
    decimals                : number    -- (Optional) Number of decimal places for display
    thresholds              : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue                 : string    -- (Optional) Text shown if value missing (default: "-")
    unit                    : string    -- (Optional) Unit label, "" to hide, or nil to auto-resolve
    font                    : font      -- (Optional) Value font (e.g., FONT_L)
    valuealign              : string    -- (Optional) "center", "left", "right"
    textcolor               : color     -- (Optional) Value text color (theme/text fallback)
    valuepadding            : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft        : number    -- (Optional)
    valuepaddingright       : number    -- (Optional)
    valuepaddingtop         : number    -- (Optional)
    valuepaddingbottom      : number    -- (Optional)
Bar geometry/appearance
    min                     : number    -- (Optional) Min value (alias for gaugemin)
    max                     : number    -- (Optional) Max value (alias for gaugemax)
    gaugeorientation        : string    -- (Optional) "vertical" or "horizontal"
    gaugepaddingleft        : number    -- (Optional)
    gaugepaddingright       : number    -- (Optional)
    gaugepaddingtop         : number    -- (Optional)
    gaugepaddingbottom      : number    -- (Optional)
    roundradius             : number    -- (Optional) Corner radius to apply rounding on edges of the bar
Appearance/Theming
    bgcolor                 : color     -- (Optional) Widget background color (theme fallback)
    fillbgcolor             : color     -- (Optional) Bar background color (theme fallback)
    fillcolor               : color     -- (Optional) Bar fill color (theme fallback)
Battery-style bar options
    batteryframe            : bool      -- (Optional) Draw battery frame & cap around the bar (applies to both standard and segmented bars)
    battery                 : bool      -- (Optional) If true, draw a segmented battery bar instead of a standard fill bar
    batteryframethickness   : number    -- (Optional) Battery frame outline thickness (default: 2)
    batterysegments         : number    -- (Optional) Number of segments for segmented battery bar (default: 6)
    batteryspacing          : number    -- (Optional) Spacing (pixels) between battery segments (default: 2)
    batterysegmentpaddingtop    : number   -- (Optional) Padding (pixels) from the top of each horizontal segment (default: 0)
    batterysegmentpaddingbottom : number   -- (Optional) Padding (pixels) from the bottom of each horizontal segment (default: 0)
    accentcolor             : color     -- (Optional) Color for the battery frame and cap (theme fallback)
    cappaddingleft        : number   -- (Optional) Padding from the left edge of the cap (default: 0)
    cappaddingright       : number   -- (Optional) Padding from the right edge of the cap (default: 0)
    cappaddingtop         : number   -- (Optional) Padding from the top edge of the cap (default: 0)
    cappaddingbottom      : number   -- (Optional) Padding from the bottom edge of the cap (default: 0)
Battery Advanced Info (Optional overlay for battery/fuel bar)
    battadv         : bool      -- (Optional) If true, shows advanced battery/fuel telemetry info lines (voltage, per-cell voltage, consumption, cell count)
    battadvfont             : font      -- Font for advanced info lines (e.g., "FONT_XS", "FONT_M"). Defaults to FONT_XS if unset
    battadvblockalign       : string    -- Horizontal alignment of the entire info block: "left", "center", or "right" (default: "right")
    battadvvaluealign       : string    -- Text alignment within each info line: "left", "center", or "right" (default: "left")
    battadvpadding          : number    -- Padding (pixels) applied to all sides unless overridden by individual paddings (default: 4)
    battadvpaddingleft      : number    -- Padding (pixels) on the left side of the info block (overrides battadvpadding)
    battadvpaddingright     : number    -- Padding (pixels) on the right side of the info block (overrides battadvpadding)
    battadvpaddingtop       : number    -- Padding (pixels) above the first info line (overrides battadvpadding)
    battadvpaddingbottom    : number    -- Padding (pixels) below the last info line (overrides battadvpadding)
    battadvgap              : number    -- Vertical gap (pixels) between info lines (default: 5)
Subtext
    subtext              : string   -- (Optional) A line of subtext to draw inside the bar (usually below value)
    subtextfont          : font     -- (Optional) Font for subtext (default: FONT_XS)
    subtextalign         : string   -- (Optional) "center", "left", or "right" (default: "left")
    subtextpaddingleft   : number   -- (Optional) Padding from left edge of bar (default: 0)
    subtextpaddingright  : number   -- (Optional) Padding from right edge of bar (default: 0)
    subtextpaddingtop    : number   -- (Optional) Extra offset from top of bar (default: 0)
    subtextpaddingbottom : number   -- (Optional) Padding above bottom of bar (default: 0)


---

### Blackbox Widget

Blackbox Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if not present
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function) on used MB
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---

### Clock Widget

Clock Widget
    Configurable Parameters (box table fields):
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value or configure as "" to omit the unit from being displayed.
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---

### Craft Name Widget

Craft Name Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if not present
    novalue             : string                    -- (Optional) Text shown if craft name is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---

### Custom Function Widget

Custom Function Widget
    Configurable Arguments (box table keys):
    wakeupinterval    : number   -- Optional wakeup interval in seconds (set in wrapper)
    wakeup            : function   -- Custom wakeup function, called with (box, telemetry), should return a table to cache
    paint             : function   -- Custom paint function, called with (x, y, w, h, box, cache, telemetry)
Note: This widget does not process colors, layout, or padding. All rendering and caching logic must be handled in the user's custom functions.


---

### Dial Image Widget

Dial Image Widget
    Configurable Parameters (box table fields):
    wakeupinterval          : number   -- Optional wakeup interval in seconds (set in wrapper)
title parameters
    title                   : string    -- (Optional) Title text
    titlealign              : string    -- (Optional) "center", "left", "right"
    titlefont               : font      -- (Optional) Title font (e.g., font_l, font_xl)
    titlespacing            : number    -- (Optional) Gap below title
    titlecolor              : color     -- (Optional) Title text color
    titlepadding            : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft        : number    -- (Optional)
    titlepaddingright       : number    -- (Optional)
    titlepaddingtop         : number    -- (Optional)
    titlepaddingbottom      : number    -- (Optional)
value / source parameters
    value                   : any       -- (Optional) Static value to display if telemetry is not present
    source                  : string    -- Telemetry sensor name
    transform               : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", etc.)
    decimals                : number    -- (Optional) Decimal precision
    novalue                 : string    -- (Optional) Text if telemetry is missing (default: "-")
    unit                    : string    -- (Optional) Unit label ("" hides unit)
    font                    : font      -- (Optional) Value font (e.g. font_l)
    valuealign              : string    -- (Optional) "center", "left", "right"
    textcolor               : color     -- (Optional) Text color
    valuepadding            : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft        : number    -- (Optional)
    valuepaddingright       : number    -- (Optional)
    valuepaddingtop         : number    -- (Optional)
    valuepaddingbottom      : number    -- (Optional)
dial image & needle styling
    dial                    : string|number|function -- Dial image selector (used for asset path)
    scalefactor             : number   -- (Optional) Image scale multiplier (default: 0.4)
    needlecolor             : color    -- (Optional) Needle color (default: theme)
    needlehubcolor          : color    -- (Optional) Hub color (default: theme)
    needlethickness         : number   -- (Optional) Needle width in pixels (default: 3)
    needlehubsize           : number   -- (Optional) Hub circle radius in pixels (default: needle thickness + 2)
    needlestartangle        : number   -- (Optional) Needle starting angle in degrees (default: 135)
    needlesweepangle        : number   -- (Optional) Needle sweep angle in degrees (default: 270)

    bgcolor                 : color    -- Widget background color (default: theme fallback)


---

### Dynamic Power (Watts) Display Widget

Dynamic Power (Watts) Display Widget

    Computes and displays instantaneous, min, max, or average power by reading voltage and current sensors.

    Configurable Parameters (box table fields):
    title               : string          -- (Optional) Title text displayed above or below the value
    titlepos            : string          -- "top" or "bottom" (default)
    titlealign          : string          -- "center", "left", or "right"
    titlefont           : font            -- Font for title (e.g., FONT_L)
    titlespacing        : number          -- Vertical gap between title and value (pixels)
    titlecolor          : color           -- Title text color
    titlepadding        : number          -- Padding for title (all sides)
    font                : font            -- Font for value (e.g., FONT_XL)
    valuealign          : string          -- "center", "left", or "right"
    textcolor           : color           -- Value text color
    valuepadding        : number          -- Padding for value (all sides)
    bgcolor             : color           -- Widget background color
    novalue             : string          -- Text to show if sensors unavailable (default: "-")
    source              : string          -- "current", "min", "max", or "avg" (default: "current")


---

### Flight Count Widget

Flight Count Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if not present
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---

### Flight Time Widget

Flight Time Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---

### Governor State Widget

Governor State Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Vertical gap between title and value text
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    displayValue        : any                       -- (Optional) Value to display (processed governor state)
    unit                : string                    -- (Not used)
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
Example thresholds:
thresholds = {
    { value = "DISARMED", textcolor = "red" },
    { value = "ACTIVE",   textcolor = "green" },
    ...
}


---

### Image Box Widget

Image Box Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
    image               : string   -- (Optional) Path to image file (no extension needed; .png is tried first, then .bmp)
    title               : string   -- (Optional) Title text
    titlepos            : string   -- (Optional) Title position ("top" or "bottom")
    titlealign          : string   -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font     -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number   -- (Optional) Gap between title and image
    titlecolor          : color    -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number   -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number   -- (Optional) Left padding for title
    titlepaddingright   : number   -- (Optional) Right padding for title
    titlepaddingtop     : number   -- (Optional) Top padding for title
    titlepaddingbottom  : number   -- (Optional) Bottom padding for title
    valuepadding        : number   -- (Optional) Padding for image (all sides unless overridden)
    valuepaddingleft    : number   -- (Optional) Left padding for image
    valuepaddingright   : number   -- (Optional) Right padding for image
    valuepaddingtop     : number   -- (Optional) Top padding for image
    valuepaddingbottom  : number   -- (Optional) Bottom padding for image
    bgcolor             : color    -- (Optional) Widget background color (theme fallback if nil)
    imagewidth          : number   -- (Optional) Image width (px)
    imageheight         : number   -- (Optional) Image height (px)
    imagealign          : string   -- (Optional) Image alignment ("center", "left", "right", "top", "bottom")


---

### Model Image Widget

Model Image Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Gap between title and image
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    font                : font                      -- (Unused, for consistency)
    valuealign          : string                    -- (Unused, for consistency)
    textcolor           : color                     -- (Unused, for consistency)
    valuepadding        : number                    -- (Optional) Padding for image (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for image
    valuepaddingright   : number                    -- (Optional) Right padding for image
    valuepaddingtop     : number                    -- (Optional) Top padding for image
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for image
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    image               : string                    -- (Auto) Image path, auto-resolved from model name or ID
    imagewidth          : number                    -- (Optional) Image width (px)
    imageheight         : number                    -- (Optional) Image height (px)
    imagealign          : string                    -- (Optional) Image alignment ("center", "left", "right", "top", "bottom")


---

### PID/Rates Profile Display Object

PID/Rates Profile Display Object

    Configurable Parameters (box table fields):
Profile Source Selection
    object                  : string                    -- Required: must be "pid" or "rates"; maps to telemetry source "pid_profile" or "rate_profile"
    profilecount            : number                    -- (Optional) How many profile numbers to draw (1 to 6, default 6)
Telemetry and Value Handling
    value                   : number                    -- (Optional) Static fallback value if telemetry is unavailable
    transform               : string|function|number    -- (Optional) Value transform logic (e.g., "floor", multiplier, or custom function)
    decimals                : number                    -- (Optional) Decimal precision for transformed value
    thresholds              : table                     -- (Optional) Value threshold list: { value=..., textcolor=... }
    novalue                 : string                    -- (Optional) Fallback text if no telemetry or static value is available
    unit                    : string                    -- (Optional) Placeholder only; not used in this object
Value Styling and Alignment
    font                    : font                      -- (Optional) Font for profile number text
    textcolor               : color                     -- (Optional) Text color for inactive profile / rates
    fillcolor               : color                     -- (Optional) Text color for active profile / rates
    valuealign              : string                    -- (Optional) Ignored; profile numbers are always centered
    valuepadding            : number                    -- (Optional) General padding around value area (overridden by sides)
    valuepaddingleft        : number
    valuepaddingright       : number
    valuepaddingtop         : number
    valuepaddingbottom      : number
Title Styling
    title                   : string                    -- (Optional) Title label (e.g., "Active Profile")
    titlepos                : string                    -- (Optional) "top" or "bottom"
    titlealign              : string                    -- (Optional) Title alignment: "center", "left", or "right"
    titlefont               : font                      -- (Optional) Title font (e.g., FONT_L)
    titlespacing            : number                    -- (Optional) Gap between title and profile number row
    titlecolor              : color                     -- (Optional) Title text color
    titlepadding            : number                    -- (Optional) General padding around title (overridden by sides)
    titlepaddingleft        : number
    titlepaddingright       : number
    titlepaddingtop         : number
    titlepaddingbottom      : number
Row Layout and Font Options
    rowalign                : string                    -- (Optional) Alignment for number row: "left", "center", or "right"
    rowspacing              : number                    -- (Optional) Spacing between profile numbers (default: width / profilecount)
    rowfont                 : font                      -- (Optional) Font for profile numbers (fallbacks to `font`)
    rowpadding              : number                    -- (Optional) General padding for number row (overridden by sides)
    rowpaddingleft          : number
    rowpaddingright         : number
    rowpaddingtop           : number
    rowpaddingbottom        : number
    highlightlarger         : boolean                   -- (Optional) If true, enlarges the active index using the next font in the list
Background
    bgcolor                 : color                     -- (Optional) Widget background color


---

### Rainbow Gauge Widget

Rainbow Gauge Widget

    Configurable Parameters (box table fields):

    wakeupinterval          : number   -- Optional wakeup interval in seconds (set in wrapper)
title parameters
    title                   : string    -- (Optional) Title text
    titlealign              : string    -- (Optional) "center", "left", "right"
    titlefont               : font      -- (Optional) Title font (e.g., font_l, font_xl)
    titlespacing            : number    -- (Optional) Gap below title
    titlecolor              : color     -- (Optional) Title text color
    titlepadding            : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft        : number    -- (Optional)
    titlepaddingright       : number    -- (Optional)
    titlepaddingtop         : number    -- (Optional)
    titlepaddingbottom      : number    -- (Optional)
value / source parameters
    value                   : any       -- (Optional) Static value to display if telemetry is not present
    showvalue               : bool      -- (Optional) If false, hides the main value text (default true)
    source                  : string    -- Telemetry sensor name
    transform               : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", etc.)
    decimals                : number    -- (Optional) Decimal precision
    novalue                 : string    -- (Optional) Text if telemetry is missing (default: "-")
    unit                    : string    -- (Optional) Unit label ("" hides unit)
    font                    : font      -- (Optional) Value font (e.g., font_l)
    valuealign              : string    -- (Optional) "center", "left", "right"
    textcolor               : color     -- (Optional) Text color
    valuepadding            : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft        : number    -- (Optional)
    valuepaddingright       : number    -- (Optional)
    valuepaddingtop         : number    -- (Optional)
    valuepaddingbottom      : number    -- (Optional)
arc band parameters
    bandlabels              : table     -- List of labels for each band (e.g. {"Low", "Med", "High"})
    bandcolors              : table     -- List of band colors (e.g. {lcd.RGB(180,50,50), lcd.RGB(...)})
    bandlabeloffset         : number    -- (Optional) Outward for left/right labels (default 18)
    bandlabeloffsettop      : number    -- (Optional) Down from the arc edge for the top label (default 8)
    bandlabelfont           : font      -- (Optional) Font for band labels (e.g. FONT_XS, FONT_S). Defaults to FONT_XS
appearance / theming
    bgcolor                 : color     -- (Optional) Widget background color
    fillbgcolor             : color     -- (Optional) Arc background color (optional)
    titlecolor              : color     -- (Optional) Title text color fallback
needle styling
    accentcolor             : color     -- (Optional) Needle and hub color
    needlethickness         : number    -- (Optional) Needle width (default: 5)
    needlehubsize           : number    -- (Optional) Needle hub circle radius (default: 7)


---

### Rainbow Gauge Widget

Rainbow Gauge Widget
    Configurable Parameters (box table fields):
Timing
    wakeupinterval      : number   -- Optional wakeup interval in seconds (set in wrapper)
Title parameters
    title               : string    -- (Optional) Title text
    titlepos            : string    -- (Optional) If `title` is present but `titlepos` is not set, title is placed at the top by default
    titlealign          : string    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font      -- (Optional) Title font (e.g., FONT_L, FONT_XL)
    titlespacing        : number    -- (Optional) Vertical gap between title and value
    titlecolor          : color     -- (Optional) Title text color (theme/text fallback)
    titlepadding        : number    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number    -- (Optional) Left padding for title
    titlepaddingright   : number    -- (Optional) Right padding for title
    titlepaddingtop     : number    -- (Optional) Top padding for title
    titlepaddingbottom  : number    -- (Optional) Bottom padding for title
Value/Source parameters
    value               : any       -- (Optional) Static value to display if telemetry is not present
    source              : string    -- Telemetry sensor source name (e.g., "temp_esc")
    transform           : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number    -- (Optional) Number of decimal places for numeric display
    thresholds          : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue             : string    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string    -- (Optional) Unit label to append to value ("" hides, default resolves dynamically)
    font                : font      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color     -- (Optional) Value text color (theme/text fallback)
    valuepadding        : number    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number    -- (Optional) Left padding for value
    valuepaddingright   : number    -- (Optional) Right padding for value
    valuepaddingtop     : number    -- (Optional) Top padding for value
    valuepaddingbottom  : number    -- (Optional) Bottom padding for value
Appearance/Theming
    bgcolor             : color     -- (Optional) Widget background color (theme fallback)
    fillbgcolor         : color     -- (Optional) Ring background color (theme fallback)
    fillcolor           : color     -- (Optional) Ring foreground color (theme fallback)
Geometry
    thickness           : number    -- (Optional) Ring thickness in pixels (default is proportional to radius)
Battery Ring Mode (Optional fuel-based battery style)
    ringbatt                 : bool      -- If true, draws 360° fill ring based on fuel (%) and shows mAh consumption
    ringbattsubfont          : font      -- (Optional) Font for subtext in ringbatt mode (e.g., FONT_XS, FONT_S, FONT_M; default: FONT_XS)
    innerringcolor           : color     -- Color of the inner decorative ring in ringbatt mode (default: white)
    ringbattsubtext          : string|bool -- (Optional) Overrides subtext below value in ringbatt mode (set "" or false to hide)
    innerringthickness       : number    -- (Optional) Thickness of inner decorative ring in ringbatt mode (default: 8)
    ringbattsubalign         : string    -- (Optional) "left", "center", or "right" alignment of subtext (default: center under value)
    ringbattsubpadding       : number    -- (Optional) General padding (px) for subtext (applies if per-side not set)
    ringbattsubpaddingleft   : number    -- (Optional) Left padding override for subtext
    ringbattsubpaddingright  : number    -- (Optional) Right padding override for subtext
    ringbattsubpaddingtop    : number    -- (Optional) Top padding override for subtext
    ringbattsubpaddingbottom : number    -- (Optional) Bottom padding override for subtext


---

### Session Value Widget

Session Value Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    source              : string                    -- Session variable to display
    unit                : string                    -- (Optional) Unit label to append to value
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---

### Stats Display Widget

Stats Display Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
Title & Layout
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL)
    titlespacing        : number                    -- (Optional) Vertical gap between title and value
    titlecolor          : color                     -- (Optional) Title text color (theme fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
Stat Source & Value
    source              : string                    -- (Required for stat mode) Telemetry sensor name used to fetch stats (e.g., "rpm", "current")
    stattype            : string                    -- (Optional) Which stat to show ("max", "min", "avg", etc; default: "max")
    value               : any                       -- (Optional, advanced) Static value. If omitted, widget shows the selected stat for 'source'
Value Display
    unit                : string                    -- (Optional) Dynamic localized unit displayed by default, you can use override this or "" to hide unit
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
General
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")

    Notes:
The widget only displays stat values (not live telemetry). "source" and "stattype" select which telemetry stat to show.
"unit" always overrides; if not set, unit is resolved from telemetry.sensorTable[source] if available.
To display min stats, set stattype = "min"; for max, omit or set stattype = "max".


---

### Step Bar Widget

Step Bar Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number    -- (Optional) Wakeup interval in seconds for the widget (set in wrapper)
Title parameters
    title               : string    -- (Optional) Title text (e.g., "2.4G", "Lora")
    titlepos            : string    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number    -- (Optional) Vertical gap between title and bar/value
    titlecolor          : color     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number    -- (Optional) Title padding (all sides unless overridden)
    titlepaddingleft    : number    -- (Optional) Left padding for title
    titlepaddingright   : number    -- (Optional) Right padding for title
    titlepaddingtop     : number    -- (Optional) Top padding for title
    titlepaddingbottom  : number    -- (Optional) Bottom padding for title
Value/telemetry parameters
    value               : number    -- (Optional) Static value to display if no telemetry
    hidevalue           : bool      -- (Optional) If true, value/unit will NOT be displayed (default: false)
    source              : string    -- (Optional) Telemetry sensor source name (e.g., "rssi", "voltage", "current")
    transform           : string|function|number -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number    -- (Optional) Number of decimal places for numeric display
    thresholds          : table     -- (Optional) List of threshold tables: {value=..., fillcolor=..., textcolor=...}
    novalue             : string    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string    -- (Optional) Unit label to append to value ("" hides, default resolves dynamically)
    font                : font      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number    -- (Optional) Value padding (all sides unless overridden)
    valuepaddingleft    : number    -- (Optional) Left padding for value
    valuepaddingright   : number    -- (Optional) Right padding for value
    valuepaddingtop     : number    -- (Optional) Top padding for value
    valuepaddingbottom  : number    -- (Optional) Bottom padding for value
Step bar parameters
    stepcount           : number    -- (Optional) Number of steps/bars to draw (default: 4)
    stepgap             : number    -- (Optional) Pixel gap between each step/bar (default: 1)
    fillcolor           : color     -- (Optional) Color for active steps (theme fallback, or resolved by thresholds)
    fillbgcolor         : color     -- (Optional) Color for inactive steps (theme fallback)
    bgcolor             : color     -- (Optional) Widget background color (theme fallback if nil)
Bar padding parameters
    barpadding          : number    -- (Optional) Bar padding (all sides unless overridden)
    barpaddingleft      : number    -- (Optional) Left padding for bar
    barpaddingright     : number    -- (Optional) Right padding for bar
    barpaddingtop       : number    -- (Optional) Top padding for bar
    barpaddingbottom    : number    -- (Optional) Bottom padding for bar


---

### Telemetry Value Widget

Telemetry Value Widget
    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL), dynamic by default
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and the value text, regardless of their paddings.
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if telemetry is not present
    source              : string                    -- Telemetry sensor source name (e.g., "voltage", "current")
    transform           : string|function|number    -- (Optional) Value transformation ("floor", "ceil", "round", multiplier, or custom function)
    decimals            : number                    -- (Optional) Number of decimal places for numeric display
    thresholds          : table                     -- (Optional) List of threshold tables: {value=..., textcolor=...}
    novalue             : string                    -- (Optional) Text shown if value is missing (default: "-")
    unit                : string                    -- (Optional) Unit label to append to value or configure as "" to omit the unit from being displayed. If not specified, the widget attempts to resolve a dynamic unit
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL), dynamic by default
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---

### Text Display Widget (Static/Label)

Text Display Widget (Static/Label)

    Configurable Parameters (box table fields):
    wakeupinterval      : number          -- Optional wakeup interval in seconds (set in wrapper)
    title               : string          -- (Optional) Title text displayed above or below the value
    titlepos            : string          -- (Optional) Title position: "top" or "bottom"
    titlealign          : string          -- (Optional) Title alignment: "center", "left", or "right"
    titlefont           : font            -- (Optional) Font for title (e.g., FONT_L, FONT_XL). Uses theme or default if unset.
    titlespacing        : number          -- (Optional) Vertical gap between title and value (pixels)
    titlecolor          : color           -- (Optional) Title text color (theme fallback if nil)
    titlepadding        : number          -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number          -- (Optional) Left padding for title
    titlepaddingright   : number          -- (Optional) Right padding for title
    titlepaddingtop     : number          -- (Optional) Top padding for title
    titlepaddingbottom  : number          -- (Optional) Bottom padding for title
    value               : string|number   -- (Optional) **Static** value to display (required for this widget)
    font                : font            -- (Optional) Font for value (e.g., FONT_L, FONT_XL). Uses theme or default if unset.
    valuealign          : string          -- (Optional) Value alignment: "center", "left", or "right"
    textcolor           : color           -- (Optional) Value text color (theme fallback if nil)
    valuepadding        : number          -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number          -- (Optional) Left padding for value
    valuepaddingright   : number          -- (Optional) Right padding for value
    valuepaddingtop     : number          -- (Optional) Top padding for value
    valuepaddingbottom  : number          -- (Optional) Bottom padding for value
    bgcolor             : color           -- (Optional) Widget background color (theme fallback if nil)
    novalue             : string          -- (Optional) Text to show if value is nil (default: "-")
Note:
This widget is for **static or label text only**. It does not support live telemetry or stats.
If you need dynamic stats or telemetry (min/max/live), use `stats.lua` or other appropriate widgets.


---

### Total Flight Time Widget

Total Flight Time Widget

    Configurable Parameters (box table fields):
    wakeupinterval      : number                    -- Optional wakeup interval in seconds (set in wrapper)
    title               : string                    -- (Optional) Title text
    titlepos            : string                    -- (Optional) Title position ("top" or "bottom")
    titlealign          : string                    -- (Optional) Title alignment ("center", "left", "right")
    titlefont           : font                      -- (Optional) Title font (e.g., FONT_L, FONT_XL)
    titlespacing        : number                    -- (Optional) Controls the vertical gap between title text and value text
    titlecolor          : color                     -- (Optional) Title text color (theme/text fallback if nil)
    titlepadding        : number                    -- (Optional) Padding for title (all sides unless overridden)
    titlepaddingleft    : number                    -- (Optional) Left padding for title
    titlepaddingright   : number                    -- (Optional) Right padding for title
    titlepaddingtop     : number                    -- (Optional) Top padding for title
    titlepaddingbottom  : number                    -- (Optional) Bottom padding for title
    value               : any                       -- (Optional) Static value to display if telemetry is not present
    unit                : string                    -- (Optional) Unit label to append to value ("" to omit)
    font                : font                      -- (Optional) Value font (e.g., FONT_L, FONT_XL)
    valuealign          : string                    -- (Optional) Value alignment ("center", "left", "right")
    textcolor           : color                     -- (Optional) Value text color (theme/text fallback if nil)
    valuepadding        : number                    -- (Optional) Padding for value (all sides unless overridden)
    valuepaddingleft    : number                    -- (Optional) Left padding for value
    valuepaddingright   : number                    -- (Optional) Right padding for value
    valuepaddingtop     : number                    -- (Optional) Top padding for value
    valuepaddingbottom  : number                    -- (Optional) Bottom padding for value
    bgcolor             : color                     -- (Optional) Widget background color (theme fallback if nil)


---
