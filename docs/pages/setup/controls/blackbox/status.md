---
title: Status
sidebar_label: Status
sidebar_position: 30
---

# Status

Controls -> Blackbox -> Status page.

## Where to find it

*Configuration* → *Setup* → *Controls* → *Blackbox* → *Status*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Erasing the dataflash

The Tool button erases the dataflash after a confirmation. It is off on a board without dataflash, until the board reports the dataflash as ready, and while an erase runs. The erase dialog closes once a read taken after the erase answers: the flash is ready, or the board reports no dataflash. A read that fails does not end the wait, so the page never reports an erase as finished on a reading from before it.

## Settings

| Setting | What it does |
| --- | --- |
| Dataflash | Configures Dataflash. |
| SD Card | Configures SD Card. |

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
