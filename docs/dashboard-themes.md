# Dashboard Themes Developer Guide — Comprehensive Reference

This document provides a complete technical reference for creating, customizing, and extending dashboard themes in Rotorflight. It covers theme structure, lifecycle hooks, box definitions, object types and subtypes (from the `objects` library), common properties, positioning/sizing, styling, interactivity, and examples.

---

## 1. Directory & File Structure

Rotorflight dashboard themes and objects are organized under:

```
<SCRIPTS>/rfsuite/widgets/dashboard/
├── objects/           # Reusable widget implementations (dial, gauge, image, etc.)
│   ├── dial/
│   │   ├── image.lua
│   │   └── rainbow.lua
│   ├── func/func.lua
│   ├── gauge/arc.lua
│   ├── gauge/bar.lua
│   ├── gauge/ring.lua
│   ├── image/image.lua
│   ├── image/model.lua
│   ├── text/apiversion.lua
│   ├── text/armflags.lua
│   ├── text/blackbox.lua
│   ├── text/craftname.lua
│   ├── text/governor.lua
│   ├── text/session.lua
│   ├── text/stats.lua
│   ├── text/telemetry.lua
│   │── text.lua
│   └── time/clock.lua
│       time.lua
└── themes/            # Installed themes
    ├── default/
    │   ├── icon.png
    │   ├── init.lua       # Returns theme table (layout, boxes)
    │   ├── preflight.lua  # Runs before flight initialization
    │   ├── inflight.lua   # Runs at flight start
    │   └── postflight.lua # Runs after flight termination
    ├── @aerc/             # Example user theme
    ├── developer-basic/   # Includes configure.lua for setup UI
    └── ...
```

**System vs User Themes**

* **System**: `SCRIPTS:rfsuite/widgets/dashboard/themes/<themename>/`
* **User**:   `SCRIPTS:rfsuite.user/dashboard/<themename>/`

User themes override system themes of the same name and are safe from package updates.

---

## 2. Theme Lifecycle Hooks

Each theme may implement the following Lua modules:

* **`init.lua`** (required): returns a table with at minimum:

  * `layout` (table): global settings (colors, fonts, selection style).
  * `boxes` (array): list of box definitions (see Section 4).
* **`preflight.lua`** (optional): called once before flight setup.
* **`inflight.lua`** (optional): called once at the start of flight.
* **`postflight.lua`** (optional): called once after flight ends.
* **`configure.lua`** (optional): for themes with configurable parameters.

Example **`init.lua`**:

```lua
return {
  layout = {
    selectcolor  = lcd.RGB(255,128,0),
    selectborder = 3,
    defaultbg    = "black",
  },
  boxes = {
    { col = 1, row = 1, type = "text", subtype = "telemetry", source = "alt", title = "ALT", unit = "m" },
    { x_pct = 0.5, y_pct = 0.1, w_pct = 0.4, h_pct = 0.2,
      type = "gauge", subtype = "bar", source = "smartfuel", gaugemin = 0, gaugemax = 100,
      title = "Fuel", unit = "%"
    },
    -- ...
  }
}
```

---

## 3. Box Definition: Common Fields

Each entry in the `boxes` array is a table with the following core fields:

| Field                             | Type                   | Description                                                               |
| --------------------------------- | ---------------------- | ------------------------------------------------------------------------- |
| `type`                            | string                 | Object type (see Section 4).                                              |
| `subtype`                         | string                 | Variant of the object (defaults vary per type).                           |
| **Positioning**                   |                        | *One of:*                                                                 |
| ├ `x_pct`,`y_pct`,`w_pct`,`h_pct` | number (0–1 or 0–100)  | Percentage of dashboard area (responsive).                                |
| ├ `x`,`y`,`w`,`h`                 | integer                | Pixels from top-left (absolute).                                          |
| └ `col`,`row`,`colspan`,`rowspan` | integer                | Grid cell coordinates (classic).                                          |
| **Styling**                       |                        |                                                                           |
| `color`,`bgcolor`,`titlecolor`    | color                  | Value, background, and title colors (fallback to theme defaults).         |
| `font`,`titlefont`                | font                   | Fonts for value and title.                                                |
| `padding`,`titlepadding`          | number                 | Padding around content.                                                   |
| **Labeling**                      |                        |                                                                           |
| `title`                           | string                 | Label text (if omitted, some subtypes auto-generate).                     |
| `unit`                            | string                 | Unit text appended to values.                                             |
| **Data**                          |                        |                                                                           |
| `source`                          | string                 | Telemetry field name or other data key.                                   |
| `value`                           | any                    | Static value (overrides `source`).                                        |
| `transform`                       | string/function/number | Built-in math transform or custom function for value adjustments.         |
| `novalue`                         | string                 | Text to display when data is missing (default "-").                       |
| **Interactivity**                 |                        |                                                                           |
| `onpress`                         | function               | Callback `(widget, box, x, y, cat, val)` when the box is pressed/focused. |

> **Priority:** Percent-based > Pixel-based > Grid-based. Whichever mode is detected first is used.

---

## 4. Object Types & Subtypes

The `type` field selects an object wrapper under `objects/`. Use `subtype` to choose specific implementations.

### 4.1 Text (`type = "text")`

Outputs static or telemetry-based text. Subtypes located in `objects/text/`:

| `subtype`    | Description                            | Default source    |
| ------------ | -------------------------------------- | ----------------- |
| `text`       | Static text string defined in `value`. | –                 |
| `telemetry`  | Telemetry value (`source` required).   | –                 |
| `apiversion` | Shows Rotorflight API version (auto).  | –                 |
| `craftname`  | Shows current model name (auto).       | –                 |
| `blackbox`   | Used/total Blackbox storage (auto).    | –                 |
| `governor`   | Governor state (auto).                 | –                 |
| `armflags`   | Armed status flags (auto).             | –                 |
| `session`    | Any session key (`source` required).   | e.g., `"rx_rssi"` |
| `stats`      | Session summary stats (auto).          | –                 |

**Common Parameters:**

* `value` (for `text` subtype)
* `source`, `decimals`, `unit`, `font`, `textcolor`, `title`, `titlefont`, `titlecolor`, `align`, `padding`, `novalue`, `transform`.

**Example:**

```lua
{ type = "text", subtype = "telemetry", source = "volt", title = "VOLTAGE", unit = "V" }
```

### 4.2 Gauge (`type = "gauge")`

Bar, ring, and arc gauges under `objects/gauge/`:

| `subtype` | Widget     | Key Parameters                                                                         |
| --------- | ---------- | -------------------------------------------------------------------------------------- |
| `bar`     | Bar gauge  | `gaugemin`, `gaugemax`, `gaugeorientation`, `thresholds`, `battery`, `batterysegments` |
| `ring`    | Ring gauge | Circular ring with fill `%`                                                            |
| `arc`     | Arc gauge  | `startAngle`, `sweep`, `arcThickness`, `arcColor`, `arcBgColor`, `thresholds`          |

**Shared Gauge Parameters:**

* `source` / `value`, `unit`, `transform`, `decimals`, `font`.
* `bgcolor`, `fillcolor`, `gaugecolor`, `gaugebgcolor`.
* `title`, `titlepos`, `titlealign`, `titlecolor`, `padding`.
* `thresholds`: array of `{ value, fillcolor, textcolor }`.

**Simple Shortcuts:**

* `type = "fuelgauge"` ⇒ preconfigured fuel bar.
* `type = "voltagegauge"` ⇒ preconfigured voltage bar.
* `type = "arcgauge"` ⇒ alias for `{ type = "gauge", subtype = "arc" }`.

**Example:**

```lua
{ type = "gauge", subtype = "arc", source = "volt",
  gaugemin = 9, gaugemax = 12.6,
  arcThickness = 14, startAngle = 225, sweep = 270,
  title = "VOLTAGE", unit = "V", titlepos = "bottom" }
```

### 4.3 Image (`type = "image")`

Displays images or model icons (`objects/image/`):

| `subtype` | Description                       | Key Params                                                     |
| --------- | --------------------------------- | -------------------------------------------------------------- |
| `image`   | Custom image from `value`/`path`. | `value` (path), `aspect`, `align`, `imagewidth`, `imageheight` |
| `model`   | Shows current model’s icon.       | `imagewidth`, `imageheight`                                    |

**Example:**

```lua
{ type = "image", subtype = "image", value = "icons/altitude.png", x=10, y=10, w=32, h=32 }
```

### 4.4 Dial (`type = "dial")`

Analog dial widgets (`objects/dial/`):

| `subtype` | Description                    | Key Params                                                                  |
| --------- | ------------------------------ | --------------------------------------------------------------------------- |
| `image`   | Dial with custom image assets. | `dial`, `min`, `max`, `needlecolor`, `needlestartangle`, `needlesweepangle` |
| `rainbow` | Color-gradient dial.           | `min`, `max`, `rainbow` color stops, etc.                                   |

**Example:**

```lua
{ type = "dial", subtype = "image", source = "rpm", dial = "assets/dial1",
  min = 0, max = 8000, needlecolor = "red" }
```

### 4.5 Time (`type = "time")`

Displays flight timer or clock (`objects/time/`):

| `subtype` | Description                       | Key Params                          |
| --------- | --------------------------------- | ----------------------------------- |
| `flight`  | Elapsed flight time (hh\:mm\:ss). | `format`, `font`, `title`           |
| `clock`   | Real-time clock display.          | `format` (Lua date fmt), `timezone` |

**Example:**

```lua
{ type = "time", subtype = "flight", x_pct=0.8, y_pct=0.05,
  format = "%H:%M:%S", title = "TIMER" }
```

### 4.6 Function (`type = "func")`

Custom drawing logic (`objects/func/func.lua`):

* **`box.wakeup(box, telemetry)`**: return a cache table.
* **`box.paint(x, y, w, h, box, cache, telemetry)`**: full custom rendering.

**Example:**

```lua
{ type = "func", paint = function(x,y,w,h,box,cache,t)
    lcd.drawText(x,y, string.format("%.1fV", t["volt"]))
end }
```

---

## 5. Interactivity & Navigation

* **Selectable Boxes:** any box with `onpress` becomes focusable.
* **Navigation Controls:**

  * Rotary/keyboard: left/right to move focus; Enter to activate.
  * Touch: tap to focus and activate.
* **Custom Highlight:** in `layout`:

  ```lua
  layout.selectcolor  = lcd.RGB(0,200,255)
  layout.selectborder = 2
  ```

---

## 6. Tips & Best Practices

* **Responsive Layout:** prefer percent-based (`*_pct`) for cross-resolution.
* **Performance:** minimize heavy custom `func` paint logic.
* **Modularity:** reuse objects in `objects/`; contribute new subtypes by adding `.lua` in the appropriate folder.
* **Defaults:** omit fields to pick theme or object defaults.

---

*This guide reflects the latest objects library (2024–2025) and should serve as the definitive reference for dashboard theme development.*
