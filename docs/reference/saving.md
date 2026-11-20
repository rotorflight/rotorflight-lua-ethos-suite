# Saving to the flight controller

A page's Save writes its values to the flight controller, then asks the flight controller to store them
in its EEPROM. The first step changes the running configuration at once; only the second makes the
values permanent. The two can fail separately.

## When a save fails

The dialog *Save failed* says which case it is.

- **Nothing was sent.** The first write was refused or lost, or a write was refused before any value
  reached the flight controller. The dialog says the settings were not saved, and the flight controller
  runs what it ran before.
- **Some values were sent.** A write went out and a later step failed, or the values went out and the
  EEPROM commit failed. The flight controller may already run the new values until it restarts, and it
  runs the old ones after the next power-up. The dialog says so, and offers **Restart FC**. A restart
  makes the flight controller load what it has stored, and the wait for it to come back is the one the
  save uses.

Restart FC is not offered while the model is armed.

## A profile switch during a save

The flight controller stores a PID or rate profile setting in whichever profile is active when the write
arrives. So on a page that edits one profile (PIDs, PID Controller, Tail Rotor, Rates, Rescue and the
other profile pages), Save asks the flight controller which profile is active right before each write. If
it is not the profile the page read, Save stops there: nothing more is sent and nothing is stored. A
switch before the first write fails with nothing sent; a switch after a write fails with some values
sent, as above. Either way the page then reads the new profile.

A write whose answer is lost is sent again only after the same check, so it cannot land in a profile
selected in the meantime.
