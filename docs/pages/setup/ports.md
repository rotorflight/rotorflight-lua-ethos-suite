---
title: Ports
sidebar_label: Ports
sidebar_position: 60
---

# Ports

Ports page. Loaded on demand from Setup -> Ports.

## Where to find it

*Configuration* → *Setup* → *Ports*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Loading serial ports... | Configures Loading serial ports.... |
| No serial ports reported by FC. | Configures No serial ports reported by FC.. |

## Notes

- Changes are written to the flight controller EEPROM upon Save.
- A *Save* or *Reload* confirmation that is still on screen when you leave the
  page is now closed with the page. Before, it stayed up over the next screen
  and its OK button did nothing, because the page behind it had already been
  disposed. (#2383, `src/rfsuite/app/pages/ports.lua`)
- Building the list of functions each port can take no longer runs over Ethos's
  per-callback instruction limit ("Max instructions count reached"). It
  checked every function against every other port one bit at a time, which
  measured ~25,000 instructions with four serial ports and ~255,000 with
  twelve, all in the one wakeup that draws the page; it now costs ~3,000 and
  ~11,000. The choices offered are unchanged. Measured off-device with
  `bin/perf/measure_app_instructions.lua`. (`src/rfsuite/app/pages/ports.lua`)

## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
