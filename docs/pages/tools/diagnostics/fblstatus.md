---
title: FBL Status
sidebar_label: FBL Status
sidebar_position: 30
---

# FBL Status

Tools -> Diagnostics -> FBL Status page.

## Where to find it

*System* → *Tools* → *Diagnostics* → *FBL Status*

Greyed out until the flight controller answers. Read-only while the model is armed.

## Arming-disable flags

*Arming Flags* shows **OK** in green while nothing blocks arming. When the
flight controller reports one or more reasons, it shows the **number** of active
reasons in red, and the reasons themselves are listed one per line underneath,
in full width, lowest flag first — the order in which they are normally
cleared.

The reasons are listed rather than joined into the value column because that
column is only the narrow right-hand half of a row. A bench mask with five
reasons is 43 to 80 characters long depending on language, and in German
`RX-Wiederherstellung fehlgeschlagen` alone is 35 — neither fits the value
column on a 480×320 radio, where the reason that actually blocked arming was
cut off at the right edge. Each reason now gets a row of its own.

Clearing a reason while the page is open empties its row rather than removing
it, so a row can stay empty for as long as the page stays open. Leaving and
re-entering the page starts from a clean list.

A flag the suite has no name for is shown as its raw mask value (`0x40000000`)
rather than dropped, so a reason is never invisible.

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |

## Read-only

Nothing on this page writes to the flight controller.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
