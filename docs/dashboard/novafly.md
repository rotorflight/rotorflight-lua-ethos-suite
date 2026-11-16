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
- The bank screen is ready only when STATUS, the governor profile and STATUS
  again have answered. A read that gets no answer within 14 s is an error; the
  screen shows it and reads again every 3 s until the flight controller answers.
- The cards of the three banks belong to the flight controller (its MCU id),
  not to the radio model: a different flight controller on the same model
  starts with empty cards and reads again.
- On RFSuite Ethos 2.3.x the colour belongs to the connected model; without a
  connection the long press changes nothing and sounds the low tone. On this
  suite the colour is in `settings.ini` and changes with or without a
  connection.
- A write that has left the screen is always carried to its end: read back,
  compared, then saved or written back, even when the screen has stopped
  waiting (no answer within 14 s, or Back during the save). A second save
  waits until the first one has ended, at most 30 s; a first write that
  answers after that no longer writes to the flight controller. The screen
  then re-reads the bank.
- The colour chosen with the long press is written to the theme's section of
  `settings.ini`, the same place the settings page writes to.
- The bank screen talks to the flight controller over the suite's `msp.request`
  bus with the `lib/msp_status`, `lib/msp_governor_profile`,
  `lib/msp_governor_config` and `lib/msp_eeprom` codecs; on RFSuite Ethos 2.3.x
  radios it uses that release's MSP API. The chain is the same on both: STATUS,
  the governor profile, STATUS again, the write, the read-back, the EEPROM save.
  With governor mode LIMIT or DIRECT the bank shows its maximum throttle in
  percent instead of the head speed.
- In the simulator a write is acknowledged and the read-back returns the fixture,
  so a save ends with "Read-back differs. NOT confirmed as saved." and the old
  set is written back. The simulated STATUS reports PID profile 6 while the
  simulated sensors report bank 1, so the three banks show "not read" until the
  two agree.
- The first frames after a theme load show only the panel: the theme builds
  its angle and glyph tables in two steps and loads at most eight masks per
  wakeup, so no single callback nears the Ethos instruction limit.
- Size: 459 files, 1.6 MB, of which 435 are glyph masks.

Source: `src/rfsuite/widgets/dashboard/themes/novafly/`.

*Checked in the Ethos 26.1.2 X18 simulator with this suite's simulated
telemetry, and on an X18 radio with RFSuite Ethos 2.3.x; not yet on a radio
with this suite.*
