
# Rotorflight Dashboard Theme System — 2024 Feature Update

This section describes all supported **box types**, new **selection/navigation** features, and advanced theme customization options available in the latest Rotorflight dashboard.

---

## 📦 Box Type Reference

You can use the following `type` values for each box in your theme’s `boxes` array. Each type has its own display logic and available options:

| `type`       | Description                                                                   | Box Options Used                              |
|--------------|-------------------------------------------------------------------------------|-----------------------------------------------|
| `telemetry`  | Telemetry sensor value (numeric or text, with units/transform)                | `source`, `title`, `unit`, `transform`, etc.  |
| `text`       | Arbitrary text value, can use source or be static                             | `source`, `title`, `unit`, etc.               |
| `image`      | Display an image from a path or value                                         | `source` or `value` (path), `imagewidth`, etc.|
| `modelimage` | Automatically show the current model’s image                                  | (auto-detects model)                          |
| `governor`   | Show Governor state from telemetry                                            | (auto)                                        |
| `craftname`  | Show current model/craft name                                                 | (auto)                                        |
| `apiversion` | Show the API version of Rotorflight                                           | (auto)                                        |
| `session`    | Display a value from the session (use `source` for key)                       | `source` (e.g., `"rx_rssi"`), etc.            |
| `blackbox`   | Show Blackbox storage used/total                                              | (auto, shows MB)                              |
| `function`   | Call a custom drawing function (`value` is your function)                     | `value = function(x, y, w, h) ... end`        |

**Example usage:**

```lua
{ type = "telemetry", source = "voltage", title = "VOLTAGE", unit = "V" }
{ type = "session", source = "rx_rssi", title = "RSSI" }
{ type = "governor", title = "Governor" }
{ type = "blackbox", title = "Blackbox" }
{ type = "function", value = function(x, y, w, h) lcd.drawText(x, y, "Custom!") end }
```

> All box types can also use: `col`, `row`, `colspan`, `rowspan`, `padding`, `color`, `bgcolor`, `title`, `unit`, `onpress`, and more.

---

## 🆕 Box Selection, Keyboard & Touch Navigation

**Any box with an `onpress` handler is focusable/selectable.**
You can highlight and activate these boxes using a rotary/keyboard or by touch.

**Navigation:**
- **Rotary left/right**: Move selection between all boxes that define `onpress`.
- **Enter (OK/press)**: Activates the selected box’s `onpress`.
- **Exit**: Removes selection highlight.

**Touch:**
- Tapping a box with `onpress` will highlight it and fire its event, keeping selection in sync with rotary navigation.

#### Custom Highlight Style

Add the following to your theme’s `layout` table to customize highlight color/border:

```lua
layout = {
    ...,
    selectcolor = lcd.RGB(0, 200, 255),  -- Custom color (any lcd.RGB or named color)
    selectborder = 2                     -- Border thickness (pixels)
}
```
*If not set, defaults to yellow (255,255,0) and 4px thickness.*

---

## 🖲️ Example Box with `onpress`

```lua
{
    col = 2, row = 2, type = "telemetry", title = "ALT",
    onpress = function(widget, box, x, y, cat, val)
        -- Custom behavior when box is selected or tapped
    end
}
```

> **Tip:** Touching a box moves the selection focus to that box, so rotary/enter continues from there. On non-touch radios, navigation still works with rotary/keypad.

---

## 🛠️ Advanced: Custom Drawing

For complete control, use a box with `type = "function"` and a custom function as the `value`:

```lua
{
    col = 4, row = 1, type = "function",
    value = function(x, y, w, h)
        lcd.drawRectangle(x, y, w, h, 1)
        lcd.drawText(x+10, y+10, "Special!")
    end
}
```

---

## 📚 Other Box and Layout Options

- **Padding/Alignment**: Use `padding`, `titlealign`, `valuealign`, etc., for finer control.
- **Transforms**: Apply math transforms to telemetry values (see code for details).
- **Images**: Use `imagewidth`, `imageheight`, `imagealign`, etc.
- **Overlay and Wakeup**: Add `paint` or `wakeup` functions to the theme table for overlays or polling.

---

## 🎨 Theme Locations: System Themes vs User Themes

Rotorflight supports two distinct locations for dashboard themes:

### **System Themes**
- **Path:**  
  `/scripts/rfsuite/widgets/dashboard/themes/<themename>`
- **Description:**  
  System themes come pre-installed with Rotorflight. These serve as the built-in or default options, and provide a great starting point or reference for customizations.

### **User Themes**
- **Path:**  
  `/scripts/rfsuite.user/dashboard/<themename>`
- **Description:**  
  User themes are your personal, editable copies. To add a custom theme, simply place your theme folder here. User themes can be modified freely and will not be overwritten by updates.

> **Tip:** If a user theme and a system theme have the same name, both will appear in the theme selector—user themes are clearly marked and can be prioritized as needed.

**How the theme selector works:**
- The dashboard will display both user and system themes when you choose a theme.
- Your selection is saved using a key like `user/themename` or `system/themename`, so the dashboard knows exactly where to look.
- You can safely test or modify themes in the user location without affecting system files.

---

For more information, examples, and advanced customization, see the rest of this documentation or the default themes in the `themes/` folder.

---

*Rotorflight Dashboard System — Theme Developer Guide (2024 Edition)*
