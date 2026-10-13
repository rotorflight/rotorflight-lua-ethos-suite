---
title: FC status
sidebar_label: FC status
sidebar_position: 50
---

# FC status

Which of the flight controller's own status words get called out, rather than which of the
telemetry values cross a threshold.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *FC status*

Always available offline without an active flight controller connection. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| *Gyro overflow* | Calls out when the flight controller reports a gyro overflow. On by default. |
| *GPS not responding* | Calls out when the GPS stops answering. On by default. |
| *Blackbox full* | Calls out when the flight controller's logging buffer is full. On by default. |
| *Control limit* | Calls out when the flight controller reports that it is limiting control. **Off by default** — it can be chatty in 3D flight. |

## Notes

- **This is the one category on the screen that needs a live flight controller.** The four
  callouts follow decoded System Status and System Config telemetry words, which need MSP API
  12.10 or newer. Without a link, or with older firmware, none of them can speak — the page
  still opens and still saves, because the settings are local.
- What counts as a problem, and how loudly, is decided by one table of rules in
  `lib/system_alerts.lua`, which the dashboard footer and these callouts share. Turning a
  callout off here silences the sound; it does not change what the dashboard shows.
- Changes are saved to the radio's settings store, not to the flight controller.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*