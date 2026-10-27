---
title: Connect servos
sidebar_label: Connect servos
sidebar_position: 70
---

# Connect servos

Step 8 of the Model setup wizard. It saves and restarts the flight controller if a restart is
owed, then checks the motor and servo outputs before you plug the servos in.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 8 *Connect servos*. This is the gate of the
wizard: a restart that a step owes happens here.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Save and restart | Shown when a restart is owed (from the board orientation, swashplate, servo type, motor or receiver steps). It saves and restarts the flight controller with the servos still unplugged, so the new outputs take effect before anything moves. The wizard waits up to 20 s for the link to come back. |
| Main motor | Checks the main motor output. |
| Tail motor | Checks the tail motor output. Shown only for a motor tail. |
| Servo list | Lists every servo the wizard will use, with its role and an OK or Missing status. |

## Notes

- Keep the blades off, and keep clear of the motor.
- Plug the servos in and power them only when this step asks you to.
- If a servo is missing, the step says so: check the outputs and the swash type.
- A step after this one shows "A restart is still owed" while a restart has not happened. Go
  back to this step to do it.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
