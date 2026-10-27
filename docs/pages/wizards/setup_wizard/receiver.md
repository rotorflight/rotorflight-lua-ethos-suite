---
title: Receiver
sidebar_label: Receiver
sidebar_position: 20
---

# Receiver

Step 2 of the Model setup wizard. It sets the receiver protocol, checks that the receiver
sends every channel, sets the channel order, and measures the throttle range.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 2 *Receiver*. The step works through
several screens: the prepare card, the link card, the channel order, the sticks, the
throttle range and the summary.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Servos unplugged, All blades removed | Two toggles on the prepare card (No / Yes). Start is enabled once both are Yes. |
| Protocol | The receiver protocol, in alphabetical order. F.Port2 is offered only on API 12.7 to 12.9; from 12.10 the FBUS driver detects it. Choosing a protocol writes it to the flight controller. A wrong protocol cuts the radio link, so the card warns first. |
| Save and restart | Saves the protocol and restarts the flight controller, which applies it. |
| Channel order: presets | ELRS, FrSky, Futaba/Hitec or Spektrum/JR. Each bar should follow its own stick. |
| Channel order: Detect | Move the sticks as asked and the wizard sets the order from them. The other sticks stay still. |
| Check the sticks | Each stick shows its live position in percent. Next waits until each of the four sticks has reached 95 % in both directions. |
| Throttle range: Measure, Stop, Use | Measure, move the throttle end to end, Stop, then Use the measured range. Under 300 µs of travel the step asks you to move it end to end again. |
| Throttle range: Defaults | Uses the default throttle range instead of a measurement. |

## Notes

- Bars and throttle measurement use the radio's own channel outputs through the receiver
  map. On S.Port, F.Port and FBUS every MSP reply pauses the flight controller's telemetry
  sensors, so the values come from the radio instead.
- Every few seconds the step compares the radio's channels with what the flight controller
  receives. If a stick differs (an inverted or limited channel output), the step names it.
- The last screen says whether the way forward is Next (nothing changed) or Save and
  continue (the changes already work on the flight controller but are not yet stored in
  its EEPROM).
- The port and the wiring are not changed here. They stay in the Configurator.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
