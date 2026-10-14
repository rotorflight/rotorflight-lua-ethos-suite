---
title: ZTW
sidebar_label: ZTW
sidebar_position: 100
---

# ZTW

Setup -> ESC & Motors -> Forward Programming -> ZTW.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Prog.* → *ZTW*

Greyed out until the flight controller answers. Read-only while the model is armed. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 7).

## Settings

| Setting | What it does |
| --- | --- |
| *None* | This page provides status or interactive operations without persistent settings. |


## Choosing the ESC

If the flight controller reports more than one ESC, this page lists them and you
pick the one to program. The list has one entry per ESC that is actually there.

With a single ESC there is nothing to choose, so the list is skipped and the page
goes straight to that ESC.

If the flight controller does not say how many ESCs there are, all four entries are
listed and only *ESC 1* can be opened. The page does not guess.

Every read is checked against this vendor's signature, Reload included: a reply that is
not this vendor's (or that carries no signature at all) is refused, the editor is not
loaded and the page cannot be saved, so another vendor's block in the slot is never
written back.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
