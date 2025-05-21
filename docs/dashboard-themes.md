# Rotorflight Dashboard Theme System

This document explains how to create and use themes for the Rotorflight dashboard widget system. The system supports two modes:

* **Standalone (imperative/function-based) themes**
* **Declarative (table-based) themes**

Both modes can coexist and support theme switching. Each approach offers its own workflow and flexibility.

---

## Table of Contents

* [Overview](#overview)
* [Standalone (Function-based) Themes](#standalone-function-based-themes)

  * [Example](#standalone-example)
* [Declarative (Table-based) Themes](#declarative-table-based-themes)

  * [Example](#declarative-example)
  * [Supported Hooks](#supported-hooks)
  * [Grid and Box Options](#grid-and-box-options)
* [Theme Switching](#theme-switching)
* [Best Practices](#best-practices)
* [FAQ](#faq)

---

## Overview

A **theme** is a Lua module (file) that returns either:

* a set of functions (the original/standalone method), or
* a table describing the grid layout and boxes, with optional hooks (the new declarative method).

The dashboard automatically loads the theme for the current "state" (flight mode, session, etc.), calls its functions, and passes it widget and telemetry context.

---

## Standalone (Function-based) Themes

**Standalone** themes are Lua files that export functions such as `paint`, `wakeup`, and `event`.
You control **all drawing, updating, and event handling**. This is the legacy and most flexible method, but requires you to handle layout and all LCD calls directly.

### Standalone Example

```lua
-- themes/mytheme.lua

local function paint(widget)
    -- Draw everything manually!
    lcd.color(lcd.RGB(100,100,255))
    lcd.drawText(10, 20, "My Standalone Theme")
end

local function wakeup(widget)
    -- Called periodically (e.g. for polling sensors)
end

local function event(widget, category, code)
    -- Handle input (e.g. button presses)
end

return {
    paint = paint,
    wakeup = wakeup,
    event = event
}
```

**In this mode:**

* The dashboard calls your `paint`, `wakeup`, and `event` as appropriate.
* You are responsible for **all** drawing.

---

## Declarative (Table-based) Themes

**Declarative** themes are Lua files that return a table describing the grid layout and its boxes, plus optional hooks.
The dashboard takes care of rendering the grid and basic box logic for you. You can supply extra hooks (`wakeup`, `event`, `paint`) to customize behavior.

### Declarative Example

```lua
-- themes/clean.lua

local function wakeup(widget)
    -- Optional: log, poll, or update state
end

local function paint(widget, layout, boxes)
    -- Optional: draw overlay graphics
    lcd.font(FONT_XS)
    lcd.color(lcd.RGB(0, 200, 0))
    lcd.drawText(10, 220, "Overlay Info!")
end

return {
    layout = { cols = 2, rows = 5, padding = 4 },
    boxes = {
        {col = 1, row = 1, rowspan = 4, type = "telemetry", source = "voltage", title = "VOLTAGE", unit = "V"},
        {col = 2, row = 1, rowspan = 4, type = "telemetry", source = "fuel", title = "FUEL", unit = "%"},
        {col = 1, row = 5, type = "telemetry", source = "governor", title = "GOVERNOR"},
        {col = 2, row = 5, type = "telemetry", source = "rpm", title = "RPM", unit = "rpm"}
    },
    wakeup = wakeup,
    paint = paint
}
```

**In this mode:**

* The dashboard automatically renders the grid and boxes.
* The theme can add hooks for special logic or overlays.
* Only needs to describe the grid, box types, and optional hooks.

---

### Supported Hooks

Declarative themes can define any of these functions:

* `wakeup(widget)`: Called periodically (e.g. for polling, state updates)
* `event(widget, category, code)`: Handle input/events (e.g. button presses)
* `paint(widget, layout, boxes)`: Run **after** the grid/boxes are drawn (for overlays, etc.)

---

### Grid and Box Options

* `layout`: Table describing the grid (cols, rows, padding).
* `boxes`: Array of box definitions with options:

  * `col`, `row`, `rowspan`, `colspan`
  * `type`: `"telemetry"`, `"text"`, `"image"`, `"modelimage"`, etc.
  * Box-specific options: `title`, `unit`, `color`, `bgcolor`, `align`, `transform`, paddings, etc.
* All boxes can use **padding**, **alignment**, and many visual options.
  See code for advanced features (e.g., degree unit handling, custom images).

---

## Theme Switching

Themes can be loaded based on:

* Flight mode (e.g., `"preflight"`, `"inflight"`)
* Session state
* User settings

The dashboard loads the right theme and runs the hooks as the mode changes.

---

## Best Practices

* Use **declarative themes** for quick layouts and overlays.
* Use **standalone themes** for maximum customizability or legacy support.
* Name files descriptively and organize in a `themes/` folder.
* Use the `paint` hook for overlays—don't hack the core render logic.
* Use `wakeup` for polling and periodic logic.

---

## FAQ

**Q: Can I combine both modes?**
A: Yes. Each mode is loaded by the dashboard system, and you can provide both for migration or hybrid purposes.

**Q: What if I only want to override overlay graphics?**
A: Use a declarative theme and provide a `paint` function for overlays.

**Q: How do I pass custom config?**
A: Add custom keys to your theme table as needed; just avoid clashing with reserved names.

---

**For more examples, see the `themes/` folder and reference the default themes provided with the dashboard system.**

---

*Rotorflight Dashboard Theme System — Developer Guide*
