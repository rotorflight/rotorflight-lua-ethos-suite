---
title: Goosky
sidebar_label: Goosky
sidebar_position: 25
---

# Goosky

Setup -> ESC & Motors -> Forward Programming -> Goosky.

Goosky ESCs run AM32 firmware. This tile is the [AM32](am32.md) editor under the Goosky
name: the same ESC signature, the same settings and the same handshake. Pilots who look for
their ESC by brand find it here; the AM32 tile programs the same ESC.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Prog.* → *Goosky*

Greyed out until the flight controller answers. Read-only while the model is armed. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 16 or 1).

Protocol 16 (*Goosky*) is offered on the [Telemetry](../telemetry.md) page from API 12.10
(rotorflight-firmware#568) as an alias of protocol 1 (*BLHELI32*). On older firmware select
*BLHELI32*; the tile is lit under either.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |

The editor rows, what Save writes and how the ESC is chosen are those of the
[AM32](am32.md) page.

## Notes

- The line under the title reads *Goosky AM32 / EEPROM n / vX.Y*. The ESC reports no brand:
  *AM32*, the EEPROM layout version and the firmware version are what the ESC answered, and
  *Goosky* is the tile the page was opened from.
- Every read is checked against the AM32 signature, Reload included: a reply that is not an
  AM32 one (or that carries no signature at all) is refused, the editor is not loaded and
  the page cannot be saved.
- Changes are written to the ESC upon Save.

## Related

- [AM32](am32.md)
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
