---
title: Finish
sidebar_label: Finish
sidebar_position: 140
---

# Finish

Step 20 of the Model setup wizard. It sums up what the wizard set and saves it.

## Where to find it

*Configuration* → *Wizards* → *Model setup*, step 20 *Finish*.

Only inside the wizard. Greyed out until the flight controller answers. Read-only while the
model is armed.

## Settings

| Setting | What it does |
| --- | --- |
| Summary | The first page: the model picture on the left, and on the right what the wizard set, with the values right-aligned: the swashplate, the tail, the blade pitch, the ESC protocol, the ESC telemetry, the governor and the arm switch. |
| DShot150 note | Shown with DShot150 only: the governor and the RPM filter need DShot300 or an RPM sensor. |
| Before the first flight | The second page: two buttons that leave the wizard and open the Governor and the PIDs pages of the suite (the PID profile settings). Unsaved changes are asked about first, as when leaving the wizard. |
| Save and finish | On the last page: saves the changes to the flight controller and leaves the wizard. |

## Notes

- Fit the blades and do a careful first hover before you fly.
- The wizard sets the mode switches (step 3), the rate styles (step 6) and the governor (step 9) in
  their own steps. Further tuning, such as the PID gains and the rate curves, is on the suite's own
  pages: the buttons on the second page open the Governor and the PIDs. Back on those pages returns
  to the Wizards menu, not to the wizard.

## Related

- [Rotorflight documentation](https://doc.rotorflight.org/)

*Documented against RFSuite Ethos 2.3.1.*
