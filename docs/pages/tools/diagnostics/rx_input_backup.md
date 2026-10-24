---
title: Backup RX
sidebar_label: Backup RX
sidebar_position: 40
---

# Backup RX

Live readout of the backup RX input: which protocol it is using, whether it has
a link, which receiver is currently driving the model, and the channel values
it receives. Use it on the bench to check that a backup receiver is wired and
bound correctly, and to watch it take over when the main RX link is pulled.

## Where to find it

*System* → *Tools* → *Diagnostics* → *Backup RX*

Greyed out until the flight controller answers. Read-only: nothing on this page
writes to the flight controller.

The backup input itself is set up on [Ports](../../setup/ports.md), by giving a
serial port the *Serial Rx (Backup)* function, and its protocol is chosen in the
firmware (`rx_input_backup_provider`).

## What it shows

| Line | What it shows |
| --- | --- |
| Protocol | The backup provider: SBUS, FBUS, FPORT, FPORT2, EXBUS or CRSF. `-` when no backup input is configured. |
| Link | **Up** (green) while the backup receiver is sending frames, **Down** (red) otherwise. **Not Configured** when no port has the backup function. |
| Active Source | **Main** (green) while the main receiver drives the model, **Backup** (red) once the backup has taken over. |
| Channel 1–18 | The value of each channel the backup receiver reports. Channels it does not send stay `-`. |

The page refreshes about three times a second. The reload button asks for a
fresh reading straight away.

## Notes

- While a backup input is configured and has not linked, arming is blocked with
  *Backup RX* (see [FBL Status](fblstatus.md)). Bind and power the backup
  receiver before flying.
- Needs firmware with backup RX support (rotorflight-firmware#490). Older
  firmware does not answer the request and the lines stay `-`.

## Related

- [Ports](../../setup/ports.md)
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
