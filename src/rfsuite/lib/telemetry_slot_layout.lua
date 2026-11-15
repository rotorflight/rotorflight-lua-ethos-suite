-- Where the Telemetry page writes each sensor when the pilot saves (issue #2671).
--
-- The radio has 40 telemetry slots. The page manages some of them (the sensors
-- its catalog lists) and keeps the rest where they are (native CRSF ids, say).
-- A save must not move a sensor that stays selected: its slot is kept, the
-- slots of sensors that were switched off are freed, and a newly selected
-- sensor takes the first free slot. Before this, every save refilled the
-- managed slots in catalogue order, so even a save with no change moved
-- sensors and packed them to the front.
--
-- Pure on purpose: no form, catalog or runtime. The page passes in what it
-- manages, so the rule can be checked without the radio.

local layout = {}

-- slots: the FC's slot array (ids, 0 = empty; may be shorter than slotCount).
-- wanted: the managed ids to show as selected, in the order the page wants
--         them written when they have to be placed.
-- isManaged(id): true for the ids the page manages.
-- Returns a new array of slotCount entries. Unmanaged ids keep their slot.
-- A managed id that is selected keeps its slot; a second copy of it, or a
-- slot holding a deselected managed id, is freed. Ids that were not placed
-- take the first free slot, in the order of wanted.
-- Second return value: how many wanted ids found no free slot. The page
-- refuses the save in that case instead of dropping a sensor silently.
function layout.place(slots, wanted, isManaged, slotCount)
  local out = {}
  local wantedSet = {}
  for _, id in ipairs(wanted) do wantedSet[id] = true end

  local placed = {}
  for i = 1, slotCount do
    local id = (slots and slots[i]) or 0
    if id ~= 0 and not isManaged(id) then
      out[i] = id
    elseif id ~= 0 and wantedSet[id] and not placed[id] then
      out[i] = id
      placed[id] = true
    else
      out[i] = 0
    end
  end

  local free = 1
  local unplaced = 0
  for _, id in ipairs(wanted) do
    if not placed[id] then
      while free <= slotCount and out[free] ~= 0 do free = free + 1 end
      if free > slotCount then
        unplaced = unplaced + 1
      else
        out[free] = id
        placed[id] = true
      end
    end
  end
  return out, unplaced
end

return layout
