-- Armed-state menu gating policy (Issue #2302).
--
-- Owns one decision: which menu entries are `lockedWhileArmed`, i.e. which
-- lead to a flight-critical write path (an FC or ESC parameter page) and
-- should therefore be badged and refuse to navigate while the model is
-- armed. app/tool.lua marks the leaves; everything else is derived here so
-- the classification has exactly one place to be wrong.
--
-- Split out of app/tool.lua rather than kept inline there for two reasons:
-- it is pure table logic with no form/lcd/bus dependency, so it can be
-- exercised directly; and app/tool.lua is already the largest file in the
-- suite (it eagerly loadMasks every icon at load time), so policy code does
-- not belong in it.

local armed_gating = {}

-- An entry carrying `visibleWhen` is treated as UNLOCKED, without calling
-- the predicate. Visibility there is a runtime decision -- Developer depends
-- on developerModeEnabled, which is only set once the tool opens -- so
-- evaluating it during resolution would be meaningless. Treating a dynamic
-- child as "absent" is also the only direction that could wrongly *lock* a
-- menu, so the conservative reading is the safe one.
local function isStaticallyVisible(entry)
  return entry.visibleWhen == nil
end

-- Recurses into a child menu first and only then folds the derived value
-- into the parent's entry -- the other order clears the flag before the
-- child has been resolved. The depth cap is a cycle guard; the real tree is
-- three levels deep, so it is never reached in practice.
local function resolveEntries(entries, menus, depth)
  if depth > 16 then return false end
  local allLocked = true
  local anyClassified = false

  for i = 1, #entries do
    local entry = entries[i]
    if isStaticallyVisible(entry) then
      anyClassified = true
      if entry.menuId then
        local sub = menus[entry.menuId]
        if sub and sub.entries then
          sub.lockedWhileArmed = resolveEntries(sub.entries, menus, depth + 1)
        end
        -- A hand mark on a submenu tile wins over the derived value, so an
        -- explicitly gated container stays gated even if a future child is
        -- made read-only.
        if entry.lockedWhileArmed ~= true then
          local resolved = menus[entry.menuId]
          entry.lockedWhileArmed = (resolved and resolved.lockedWhileArmed == true) or nil
        end
      end
      if entry.lockedWhileArmed ~= true then allLocked = false end
    else
      -- Still recurse, so a container that is hidden right now (Developer,
      -- gated on developerModeEnabled) has its own entries classified by the
      -- time it becomes visible -- otherwise opening it later would show
      -- tiles with no gating at all. The result lands on the child menu
      -- table but is deliberately NOT folded into this entry: a dynamic
      -- child must not be able to lock the menu that contains it.
      entry.lockedWhileArmed = nil
      allLocked = false
      if entry.menuId then
        local sub = menus[entry.menuId]
        if sub and sub.entries then
          sub.lockedWhileArmed = resolveEntries(sub.entries, menus, depth + 1)
        end
      end
    end
  end

  -- An empty menu (logs_menu today) has nothing to gate and must not count
  -- as "all children locked".
  return anyClassified and allLocked
end

-- entries: the root or submenu entry list. menus: the {menuId -> {entries}}.
-- Idempotent, and only ever writes the *derived* fields -- a hand-marked
-- entry keeps its mark -- so it can safely be re-run on every tool open
-- without a reset pass (a reset would also wipe a hand mark on a future
-- root entry and silently unlock it).
function armed_gating.resolve(entries, menus)
  return resolveEntries(entries or {}, menus or {}, 1) == true
end

return armed_gating
