-- ESC parameter transactions for the Setup Wizard's throttle range (#2704), as the EdgeTX suite's
-- lib/esc_params.lua does it: read the ESC block, write the changed fields, read it back and compare.
--
-- No UI and no page state here. The codec and the send function are passed in, so the caller decides
-- the bus; the messages are the codec's own (buildReadMessage / buildWriteMessage).

local M = {}

-- ESC telemetry protocol id -> the parameter family. Only the families that have a throttle range
-- are listed; the range limits are the codec's own (msp_esc_parameters_yge.lua).
M.families = {
  [9] = {
    name = "YGE",
    codec = "lib/msp_esc_parameters_yge.lua",
    range = {
      zero = "stick_zero_us", zeroMin = 900, zeroMax = 1900,
      span = "stick_range_us", spanMin = 600, spanMax = 1500,
    },
  },
}

function M.familyFor(protocol)
  return M.families[protocol]
end

-- The ESC's own fields for a throttle range: the 0 % pulse, and the span up to 100 %.
-- Assumption carried over from the EdgeTX suite: stick_zero_us is the 0 % pulse and stick_range_us
-- its span. Not yet checked against a YGE ESC.
-- Returns nil and a reason when the range is not one the ESC accepts.
function M.rangeChanges(family, minUs, maxUs)
  if not family or not family.range then return nil, "no_range" end
  local r = family.range
  if type(minUs) ~= "number" or type(maxUs) ~= "number" then return nil, "invalid" end
  if minUs <= 1000 or maxUs <= minUs then return nil, "invalid" end
  local span = maxUs - minUs
  if minUs < r.zeroMin or minUs > r.zeroMax then return nil, "out_of_range" end
  if span < r.spanMin or span > r.spanMax then return nil, "out_of_range" end
  return {[r.zero] = minUs, [r.span] = span}
end

-- True when the block already holds every value in `changes`.
function M.matches(block, changes)
  if not block then return false end
  for key, value in pairs(changes) do
    if block[key] ~= value then return false end
  end
  return true
end

-- A transaction bound to one codec and one send function.
--   send(msg)  sends a message built by the codec.
--   read(after)            after(block) or after(nil, "read")
--   write(changes, after)  needs a read first; after(block) when the block reads back as written,
--                          after(nil, reason) otherwise: "esc_not_read", "write", "mismatch".
function M.new(codec, send)
  local s = {codec = codec, block = nil}

  function s:read(after)
    self.block = nil
    send(codec.buildReadMessage(function(block)
      self.block = block
      after(block)
    end, function()
      after(nil, "read")
    end))
  end

  function s:verify(changes, after)
    self:read(function(block, err)
      if err then after(nil, err)
      elseif not M.matches(block, changes) then after(block, "mismatch")
      else after(block) end
    end)
  end

  -- A write needs a read in this visit (as the EdgeTX suite). The block is read again right before the
  -- write: the ESC must answer now, and a change made since the first read is kept, not overwritten.
  function s:write(changes, after)
    if not self.block then
      after(nil, "esc_not_read")
      return false
    end
    self:read(function(fresh, err)
      if err or not fresh then
        after(nil, err or "esc_not_read")
        return
      end
      local data = {}
      for key, value in pairs(fresh) do data[key] = value end
      for key, value in pairs(changes) do data[key] = value end
      send(codec.buildWriteMessage(data, function()
        self:verify(changes, after)
      end, function()
        self.block = nil
        after(nil, "write")
      end))
    end)
    return true
  end

  return s
end

return M
