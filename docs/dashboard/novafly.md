# NovaFly RC

The NovaFly cockpit as a dashboard theme: one full-screen instrument panel for
480 × 320 radios (X18, X18S, X18RS). The same screen serves preflight, inflight
and postflight.

## Select and configure

Select **System → Settings → Dashboard → Themes → NovaFly RC**. Open
**System → Settings → Dashboard → Settings → NovaFly RC** to choose the panel
colour. Theme selection and the colour work offline while the Suite background
task runs; a model-specific selection requires a connected flight controller
with a known MCU ID.

## Screen

The panel is a bitmap in one of nine colours. On it the theme draws:

- the arming state, top left, and the link (RSSI and VFR), top right;
- the heading arrow and the flight timer;
- the head speed dial with the current head speed;
- the active PID bank and rate profile;
- pack voltage, cell voltage, battery percentage, current, BEC voltage and
  transmitter battery;
- ESC temperature, flight-controller temperature and load, altitude and the
  model name.

Digits are drawn with an italic font made of bitmap masks (`gfx/kursiv`), so a
value does not jump when a digit changes. A value whose masks are not loaded
yet is drawn with the system font for that frame.

A long press on the panel head, with the model on the ground and not armed,
steps through the colours. Tapping **BANK** or **RATE** opens the bank screen:
it reads the active PID bank from the flight controller over MSP, shows the
governor head speed of that bank, and lets it be stepped with minus and plus.
**Save** writes the whole bank back and reads it back for confirmation; it is
refused while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Colour | Panel colour: Blue (default), Magenta, Green, Orange, Yellow, Carbon, Carbon green, Carbon violet, Carbon red. |

The colour is stored as `farbe` in the `dashboard.novafly` section of
`SCRIPTS:/rfsuite.user/settings.ini`; the selection ID is `system/novafly`.

## Notes

- The layout exists for 480 × 320 only. The theme picker and the settings grid
  show NovaFly RC only on a 480 × 320 window (X18, X18S, X18RS) and hide it on
  any other size, the way Bastion is hidden below 784 × 294.
- The theme carries its own texts for de, en, es, fr, it and nl, chosen by the
  radio language.
- Temperatures follow the radio's temperature unit, in the value, the colour
  limits and the unit sign.
- The bank screen reads the flight controller's active bank right before it
  writes and again before it would write a set back, and it never writes while
  the model is armed. A bank change during a save is reported and nothing is
  persisted; the screen then shows the new bank.
- The colour chosen with the long press is written to the theme's section of
  `settings.ini`, the same place the settings page writes to.
- On this suite the bank screen opens and closes, but it reads and sets nothing
  yet: its flight-controller path still uses the 2.3.x MSP API. The port to the
  suite's `msp.request` bus is pending; on RFSuite Ethos 2.3.x radios the screen
  works.
- The first frames after a theme load show only the panel: the theme builds
  its angle and glyph tables in two steps and loads at most eight masks per
  wakeup, so no single callback nears the Ethos instruction limit.
- Size: 459 files, 1.6 MB, of which 435 are glyph masks.

Source: `src/rfsuite/widgets/dashboard/themes/novafly/`.

*Checked in the Ethos 26.1.2 X18 simulator with this suite's simulated
telemetry, and on an X18 radio with RFSuite Ethos 2.3.x; not yet on a radio
with this suite.*
