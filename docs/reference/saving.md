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
