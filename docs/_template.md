---
title: <Page title, as the tile reads>
sidebar_label: <Tile label>
sidebar_position: <order of the tile in its menu, times 10>
---

# <Page title>

<!-- One or two sentences: what the page configures and why a pilot opens it.
     No longer than the settings table needs. -->

## Where to find it

*Configuration* → *Setup* → *<Tile>*

<!-- Name every condition that makes the page absent, greyed out or read-only.
     Common Ethos conditions:
       offline = true                 -> Always available offline without an active flight controller connection.
       requiresServoBus = true        -> Only available when servo bus output is enabled.
       escProtocolId = <n>            -> Lit only while the flight controller reports this ESC telemetry protocol.
       visibleWhen = developerMode    -> Hidden until Developer mode is enabled under System → Settings → Developer.
       lockedWhileArmed = true        -> Read-only while the model is armed.
       Standard telemetry page        -> Greyed out until the flight controller answers.
     Leave out lines that do not apply. If none apply, write: Always available. -->

## Settings

<!-- One row per control, in the order they appear on the page. Say what the setting does, not
     what it is called a second time. Give the range, the unit and the default where the pilot
     needs them. A control that only appears under a condition says so in its row. -->

| Setting | What it does |
| --- | --- |
| <Label> | <What it does. Range, unit, default.> |

## Notes

<!-- Optional. Only what a pilot would otherwise get wrong: a save that reboots the flight
     controller, EEPROM persistence, an interaction with another page, or a safety point.
     Delete the section if there is nothing to say. -->

## Related

<!-- Optional. Link the Rotorflight documentation for the underlying feature instead of
     restating it. Delete the section if there is nothing to link. -->

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos 2.3.1.*
