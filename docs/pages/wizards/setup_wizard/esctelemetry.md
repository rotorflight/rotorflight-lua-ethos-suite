---
title: ESC telemetry
sidebar_label: ESC telemetry
sidebar_position: 38
---

# ESC telemetry

Step 12 of the Model setup wizard. It has eight screens. The first asks that all blades are removed.
The second sets whether the ESC sends telemetry to the flight controller, the ESC's protocol, and the
serial port the telemetry uses. The third finds how the telemetry wire is connected, and shows the
battery voltage and the ESC temperature. Screens 4 to 8 set the voltage and current sources, the
battery (cell count and capacities), and SmartFuel.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 12 *ESC telemetry*. Eight screens: "Step 1 of 8"
to "Step 8 of 8".

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the model is
armed.

## Screen 1: the blades

| Setting | What it does |
| --- | --- |
| All blades removed | Confirms that the main and tail blades are off. Start is greyed out until it is ticked. |

## Screen 2: the telemetry

| Setting | What it does |
| --- | --- |
| ESC telemetry: Used / Not used | Used: the ESC sends RPM, voltage, current and temperature to the flight controller. Not used: the flight controller measures the battery itself, or nothing does. |
| Protocol | The ESC's telemetry protocol, from the list the flight controller's API version offers. Greyed out when not used. Changing the protocol needs a restart. |
| Port | The serial port the telemetry uses, chosen from the ports the Ports page offers (for example UART5 on a board with a telemetry port). On Used, the first free UART is taken. Choosing another port frees the previous one. The port change needs a restart. |

This step is a restart point. When a restart is owed, the forward button is *Save and restart*: the
flight controller restarts, and the step reopens on screen 3, where the port is live. Without a restart
owed, the forward button goes to screen 3.

## Screen 3: the wiring

| Setting | What it does |
| --- | --- |
| Status | Not run, the combination being tried (1 to 4), or the result: Found, Telemetry only, Not found, Rejected, Timed out, Not supported or Stopped. |
| Wiring: Detect / Stop | Detect tries the four combinations of half duplex and pin swap on the telemetry port, and stops at the one that receives the ESC. On a YGE it starts from half duplex, so the wiring that can program the ESC is tried first. Stop ends a run early. |
| Battery voltage | Read from the telemetry. Shows "--" until the battery is connected and the telemetry arrives. |
| ESC temperature | Read from the telemetry, the same way. |

## Screens 4 and 5: the voltage and current source

| Setting | What it does |
| --- | --- |
| Voltage Source / Current Source | Where the flight controller reads the value: None, Battery ADC, ESC Telemetry, or FrSky F.BUS. |
| Voltage / Current | The live reading of that source. The ESC's telemetry is read live. ADC and F.BUS read the flight controller's own measurement, shown while it is fresh. "--" when there is none. |

## Screen 6: the battery

| Setting | What it does |
| --- | --- |
| Selected | The active battery profile, shown only. The step does not change it. |
| Cell Count | The cells of the active profile: 0 to 24. 0 detects them automatically. |

## Screen 7: the capacities

Six batteries on one screen, in three rows: Battery 1 with Battery 4, Battery 2 with Battery 5, and
Battery 3 with Battery 6, each label before its field. Each is a capacity in mAh, 0 to 40000. Editing a
battery does not activate it.

## Screen 8: SmartFuel

| Setting | What it does |
| --- | --- |
| Smart Fuel | The flight controller's SmartFuel mode: off (local), voltage, current, or combined. |

A voltage or combined mode needs a voltage source; without one, the screen says so. On firmware without
SmartFuel the screen says that too.

## Notes

- The step comes after the Connect servos gate. The servos are plugged in by then, which is why the
  first screen asks for the blades to be removed.
- If there is no free UART, the step says so. Free one on the Ports page, then come back to the step.
- Only free ports (and the one already in use) are offered, so an occupied port is never replaced
  silently.
- Until the restart the port is not live: the readings show "--", and Detect is greyed out with the reason.
- Changing the protocol also needs a restart: the port was opened at boot with the previous protocol's baud and callback.
- A detection run takes a few seconds and gives up after twelve. Leaving the step, or Stop, ends it, and the
  flight controller restores the wiring it had.
- On a YGE, Detect first writes half duplex to the flight controller, so the search tries the half-duplex
  wirings first. When the run ends, the wiring you had is written back. Without this, a YGE that sends
  telemetry by itself stops the search at the first wiring, and its parameters cannot be read.
- Found writes the half-duplex and pin-swap settings and asks for a restart: *Save and restart* is the
  button on screen 3.
- Telemetry only means the run found telemetry on a wiring without half duplex, on a YGE. That wiring
  receives the telemetry but cannot program the ESC. The settings are written as found. The ESC cannot
  be programmed over that wiring; its Half Duplex setting is on the ESC telemetry page
  ([ESC telemetry](../../setup/esc_motors/telemetry.md)), where it can be changed by hand.
- Not found, Rejected, Timed out and Stopped write nothing. Check the telemetry wire between the ESC and
  the flight controller and that the ESC has power, then try again.
- Castle Link has no wiring to detect, so the step says so and does not run.
- The flight controller needs the ESC sensor trial command (MSP2 0x5F0C). Without it the status reads
  Not supported.
- The battery and SmartFuel settings apply at once. They are kept for Discard with the rest of the step.
- Setting ESC telemetry to Not used also clears the stored protocol, so the feature is not turned back on
  by the flight controller's config check (F.BUS with a master port).

## Related

- [Connect servos](connect.md): the gate before this step.
- [ESC & spin test](esc.md): the calibration and the spin test that follow.
- [Motor & ESC](motor.md): the ESC protocol and the gear ratios, the step before this one.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
