-- Timed overrides held by the Setup Wizard (lib/override_hold.lua).
--
-- A hold is sent with a timeout, and re-sent every REFRESH_S while the wizard keeps it, so
-- the FC drops it by itself if the radio link or the wizard goes away (#2690). A release is
-- sent without a timeout and clears the override at once.
--
-- The tracker only keeps the time and the list of held items; the messages are built and sent
-- by the caller.

local M = {}

M.TIMEOUT_MS = 3000
M.REFRESH_S = 1.0

local function keyOf(kind, key)
  return kind .. ":" .. tostring(key)
end

function M.new()
  local self = {items = {}}

  -- Records a hold that the caller has just sent at `now`.
  function self:hold(kind, key, value, now)
    self.items[keyOf(kind, key)] = {kind = kind, key = key, value = value, sentAt = now}
  end

  -- The hold of `kind`/`key` is released by the caller; returns the held value, or nil.
  function self:release(kind, key)
    local k = keyOf(kind, key)
    local item = self.items[k]
    self.items[k] = nil
    return item and item.value or nil, item ~= nil
  end

  function self:isHeld(kind, key)
    return self.items[keyOf(kind, key)] ~= nil
  end

  -- Every held item of `kind`, for a release of all of them.
  function self:list(kind)
    local out = {}
    for _, item in pairs(self.items) do
      if item.kind == kind then out[#out + 1] = item end
    end
    return out
  end

  -- The holds due a refresh at `now`: each returned item is marked as sent.
  function self:due(now)
    local out = {}
    for _, item in pairs(self.items) do
      if now - item.sentAt >= M.REFRESH_S then
        item.sentAt = now
        out[#out + 1] = item
      end
    end
    return out
  end

  function self:clear()
    self.items = {}
  end

  return self
end

return M
