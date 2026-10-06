# Dashboard controls

The RFSuite dashboard widget has two overlays on top of whatever theme is
showing: a toolbar along the bottom and an info panel from the top. Both are
hidden until you ask for them, so they never cover the theme on their own.

Source: `src/rfsuite/widgets/dashboard.lua`.

## Toolbar

Open it by sliding up on the dashboard, or with a long press of PAGE. Close it
by sliding down or pressing the rotary down. It closes by itself after 10
seconds without a touch or key press.

| Tile | Does | Greyed out when |
| --- | --- | --- |
| Reset | Resets the flight (timers and min/max stats) after a confirmation. | Never. |
| Erase | Erases the blackbox dataflash after a confirmation. | Not connected. |
| Battery | Picks the active battery profile. | Not connected, or fewer than two battery profiles are set. |
| Info | Opens the info panel (below). | Never. |
| Setup | Opens the RFSuite system tool. | Ethos is older than 26.1. |

## Info panel

Slide down on the dashboard to open it, or pick **Info** on the toolbar. It
drops from the top, as tall as its contents need (at most 85% of the
dashboard), and updates live. Unlike the toolbar it does not time out. It
closes when you:

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
| Governor | Governor state (OFF, IDLE, SPOOLUP, ACTIVE, …), when the governor sensor reports. |
| Arming | **Ready** (green), **Blocked** (amber), or **Armed** (red). When blocked, each reason is listed at the bottom of the column. `-` until the FC reports its arming flags. |
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
