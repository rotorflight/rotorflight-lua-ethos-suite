# Dashboard controls

The RFSuite dashboard widget has two overlays on top of whatever theme is
showing: a toolbar along the bottom and an info panel from the top. Both are
hidden until you ask for them, so they never cover the theme on their own.

Source: `src/rfsuite/widgets/dashboard.lua`.

## Toolbar

Open it by sliding up on the dashboard, or with a long press of PAGE. Close it
by sliding down or pressing the rotary down. It closes by itself after 10
seconds without a touch or key press. While it is open the dashboard behind it
is dimmed.

| Tile | Does | Greyed out when |
| --- | --- | --- |
| Reset | Resets the flight (timers and min/max stats) after a confirmation. | Never. |
| Erase | Erases the blackbox dataflash after a confirmation. | Not connected. |
| Battery | Opens the battery picker (below) to choose the active battery profile. | Not connected, or fewer than two battery profiles are set. |
| Info | Opens the info panel (below). | Never. |
| Setup | Opens the RFSuite system tool. | Ethos is older than 26.1. |

## Battery picker

The picker shows the battery profiles as a grid, one cell per pack, with the
pack number and its capacity. It is three cells across on a dashboard 400 px
wide or wider, and two cells across on a narrower one. It opens with the pack
the FC reports as active already selected.

It drops down from the top of the dashboard, like the info panel, as tall as
its grid needs (at most 85% of the dashboard). The rest of the dashboard is
dimmed behind it, so the panel is the part to look at.

It opens in two ways:

- from the **Battery** tile on the toolbar;
- by itself, once each time the radio connects to an FC with more than one
  battery profile. This follows **Settings > General > Integration > Battery
  profile on connect**, which is on by default.

To change the active pack, tap its cell, or turn the rotary to it and press
Enter. The FC receives the change, and the picker closes.

Exit or Return closes the picker and changes nothing. So does a tap on the
dimmed part of the dashboard, or a swipe up, the same as for the info panel.
Choosing the pack that is already active changes nothing and shows a short
confirmation.

## Info panel

Slide down on the dashboard to open it, or pick **Info** on the toolbar. It
drops from the top, as tall as its contents need (at most 85% of the
dashboard), and updates live. The dashboard behind it is dimmed. Unlike the
toolbar it does not time out. It closes when you:

- press Exit, Return or Enter, slide up, or tap anywhere on the dashboard;
- arm the model. You can open it again while armed.

When the toolbar is open, sliding down closes the toolbar first. Only one of the
two is open at a time. Exit reaches the panel only while the dashboard widget
has focus, the same as the toolbar's keys.

**Left column: Controller**

| Row | Shows |
| --- | --- |
| Link | Telemetry link type (S.Port or CRSF), plus link quality when the link reports it. |
| Flight mode | Failsafe, GPS Rescue, Rescue, Horizon, Angle, or Normal, from the FC's Flight Mode sensor. The first that applies, in the order the firmware's own CRSF flight-mode text uses. |
| Governor | Governor state (OFF, IDLE, SPOOLUP, ACTIVE, …), when the governor sensor or the System Status sensor reports. With the FC's governor mode set to None or Limit (an external ESC governs), the state never leaves OFF in the firmware, so the tile shows **PASSTHRU** instead of OFF. |
| Arming | **Ready** (green), **Blocked** (amber), or **Armed** (red). When blocked, each reason is listed at the bottom of the column. `-` until the FC reports its arming flags (or System Status). |
| Profile | Active PID, rate and battery profile numbers. |
| BEC Voltage | BEC voltage, when the sensor reports it. |
| Blackbox | How full the blackbox dataflash is. |

**Right column: Battery, then GPS**

| Row | Shows |
| --- | --- |
| Pack | Cell count and capacity of the active battery profile, for example `6S  2200mAh`. |
| Voltage | Pack voltage. |
| Used | mAh used so far. |

A **GPS** section with the **Satellites** count follows only while the FC's
**GPS Sats** sensor is reporting (S.Port and CRSF/ELRS). Without one the column
is just Battery.

Each row only appears once its value is known. If the panel can't fit
everything, the last rows of a column are left off. While no model is connected,
both columns show **Not connected**.

## Status banner

When the flight controller sends the **System Status** or **System Config**
telemetry sensor (firmware with MSP API 12.10 or newer, sensor selected under
*Setup* → *Telemetry*), a banner across the bottom of the dashboard shows the
most important problem they report. REBOOT REQUIRED and BLACKBOX FULL come
from System Config, the others from System Status, so each banner needs its
own sensor selected. Critical problems are red, warnings amber. When
more than one is active, the banner adds a count, for example
`GYRO OVERFLOW (+2)`. The banner goes away by itself when the problem clears.

| Banner | Level | Shown while |
| --- | --- | --- |
| FAILSAFE | Critical | The FC is in a failsafe phase. |
| BATTERY CRITICAL | Critical | The FC reports the battery as critical. |
| GYRO OVERFLOW | Critical | The gyro has overflowed. |
| GOVERNOR FALLBACK | Warning | The governor has lost its headspeed signal and is on its fallback throttle. |
| GPS NOT RESPONDING | Warning | The GPS was talking to the FC earlier on this connection and has stopped. |
| ACC NOT CALIBRATED | Warning | An accelerometer is fitted but has never been calibrated. |
| TEST OVERRIDE ACTIVE | Warning | A servo, motor or mixer override from a setup tool is on. |
| REBOOT REQUIRED | Warning | A saved setting only takes effect after a reboot. Needs **System Config**. |
| BLACKBOX FULL | Warning | The blackbox storage is full. Needs **System Config**. |

The "background task not running" and "unsupported firmware" banners take
priority over these. With older firmware, or without either sensor, there is
no status banner, and the rest of the dashboard works as before.
