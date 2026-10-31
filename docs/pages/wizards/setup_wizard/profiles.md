---
title: Profiles & gain
sidebar_label: Profiles & gain
sidebar_position: 35
---

# Profiles & gain

Step 4 of the Model setup wizard. One switch picks the flight profile (the PID profile, and
with it the rates), and master gain in flight is set with trim buttons or a knob on a spare
channel.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 4 *Profiles & gain*. Four screens: the
safety card, the profile switch, the master gain and the channels in use.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Servos unplugged, All blades removed | Two toggles on the safety card (No / Yes). Start is enabled once both are Yes. |
| Profiles and rates | The switch picks the PID profile and the rate profile 1, 2 or 3 together. |
| PID profiles only | The switch picks the PID profile; the rates stay as they are. |
| Not used | The helicopter flies on one profile. |
| Assign | Press, then move the switch through every position. The wizard records where each position really is, so each one lands on its own profile. Use writes the profile range. |
| Trim buttons | The trim buttons step the master gain, all on one spare channel. Set up the GAIN mix on the radio first (see below). |
| Knob | A knob or slider sets the master gain, 50 % to 150 %, on a spare channel. |
| Not used (gain) | The master gain stays as it is. Find it later in flight, or on the Profiles tab. |
| Channels in use | The channels the step uses: ARM, Rescue and Trainer from the mode switches, the profile switch and the master gain. |

## Notes

- The profile switch fits an 8-channel radio. Master gain on a trim button or a knob needs
  a channel of its own, so it fits only if the Rescue or Trainer switch is not used.
- Trim buttons, on the Ethos example: set the elevator and rudder trims to **OFF** under
  *Model → Trims*, so they no longer trim the sticks. Then add a **Free mix** named GAIN
  under *Model → Mixes*: active condition Always on, source Maximum, operation Add, output a
  spare channel (CH9 in the examples). Add one action per trim button with these weights:
  cyclic down 30 %, cyclic up 40 %, yaw down 50 %, yaw up 60 %.
- Master gain steps by 5 % per press and goes from 25 % to 200 %. Each button press reads
  as one value on the channel; the wizard tells the buttons apart by those values.
- On other radios, set up the same weights on a spare channel, with each trim button
  switching its own weight in.
- The changes already work on the flight controller, but are stored only with Save and
  continue.
- Use the Profiles tab later for fine tuning, and the Adjustments tab for the adjustment
  slots.

## Related

- [Mode switches](modes.md): the switches of ARM, Rescue and Trainer.
- [Adjustments](../../setup/controls/adjustments.md): the adjustment slots on their own page.
- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
