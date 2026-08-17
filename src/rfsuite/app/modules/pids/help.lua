--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local data = {}

data['help'] = {}

data['help']['default'] = {"FeedForward (Roll/Pitch): Start at 70, increase until stops are sharp with no drift. Keep roll and pitch equal.", "I Gain (Roll/Pitch): Raise gradually for stable piro pitch pumps. Too high causes wobbles; match roll/pitch values.", "Tail P/I/D Gains: Increase P until slight wobble in funnels, then back off slightly. Raise I until tail holds firm in hard moves (too high causes slow wag). Adjust D for smooth stops-higher for slow servos, lower for fast ones.", "Test & Adjust: Fly, observe, and fine-tune for best performance in real conditions."}

data['fields'] = {}

return data
