-- Arming-disable flag decoding, shared by the Diagnostics -> FBL Status page
-- and its offline check (bin/fblstatus/verify_arming_flags.lua).
--
-- Split out of app/pages/diagnostics_fblstatus.lua so the mask arithmetic can
-- be exercised without a radio, an FC or an Ethos runtime. The page keeps the
-- layout; this file keeps the arithmetic, and the split matches the two
-- modules that page already pulls in for the same reason
-- (lib/msp_status.lua, lib/msp_dataflash_summary.lua).
--
-- The names are the app.modules.fblstatus.arming_disable_flag_* keys, held here
-- as @i18n tags. bin/package/resolve_i18n_tags.py substitutes the
-- translated string at build time, so what ships in the ZIP is plain text in
-- the pilot's language -- this file is never asked to translate anything.
--
-- Why the list is separate from the summary: see #2346. The page used to join
-- every active flag into one value-column string, and that column is the
-- narrow half of the line, so on a 480x320 radio the blocking reason was
-- clipped off the right edge. The count goes in the value column, the names go
-- in full-width lines below it.

if package.loaded["rfsuite.lib.arming_flags"] then
  return package.loaded["rfsuite.lib.arming_flags"]
end

local arming_flags = {}

-- Bits 0..25. The firmware's own arming-disable mask is wider than this in
-- later versions; a set bit above 25 is reported as its number rather than
-- dropped, so an unknown bit is visible instead of silently missing.
local FLAG_COUNT = 26

local FLAG_TAGS = {
  [0] = "@i18n(app.modules.fblstatus.arming_disable_flag_0)@",
  [1] = "@i18n(app.modules.fblstatus.arming_disable_flag_1)@",
  [2] = "@i18n(app.modules.fblstatus.arming_disable_flag_2)@",
  [3] = "@i18n(app.modules.fblstatus.arming_disable_flag_3)@",
  [4] = "@i18n(app.modules.fblstatus.arming_disable_flag_4)@",
  [5] = "@i18n(app.modules.fblstatus.arming_disable_flag_5)@",
  [6] = "@i18n(app.modules.fblstatus.arming_disable_flag_6)@",
  [7] = "@i18n(app.modules.fblstatus.arming_disable_flag_7)@",
  [8] = "@i18n(app.modules.fblstatus.arming_disable_flag_8)@",
  [9] = "@i18n(app.modules.fblstatus.arming_disable_flag_9)@",
  [10] = "@i18n(app.modules.fblstatus.arming_disable_flag_10)@",
  [11] = "@i18n(app.modules.fblstatus.arming_disable_flag_11)@",
  [12] = "@i18n(app.modules.fblstatus.arming_disable_flag_12)@",
  [13] = "@i18n(app.modules.fblstatus.arming_disable_flag_13)@",
  [14] = "@i18n(app.modules.fblstatus.arming_disable_flag_14)@",
  [15] = "@i18n(app.modules.fblstatus.arming_disable_flag_15)@",
  [16] = "@i18n(app.modules.fblstatus.arming_disable_flag_16)@",
  [17] = "@i18n(app.modules.fblstatus.arming_disable_flag_17)@",
  [18] = "@i18n(app.modules.fblstatus.arming_disable_flag_18)@",
  [19] = "@i18n(app.modules.fblstatus.arming_disable_flag_19)@",
  [20] = "@i18n(app.modules.fblstatus.arming_disable_flag_20)@",
  [21] = "@i18n(app.modules.fblstatus.arming_disable_flag_21)@",
  [22] = "@i18n(app.modules.fblstatus.arming_disable_flag_22)@",
  [23] = "@i18n(app.modules.fblstatus.arming_disable_flag_23)@",
  [24] = "@i18n(app.modules.fblstatus.arming_disable_flag_24)@",
  [25] = "@i18n(app.modules.fblstatus.arming_disable_flag_25)@",
}

-- The summary line's text. Bounded by construction: a count and a fixed word,
-- never the flag names. "#2346: the value column cannot hold the names."
local ACTIVE_FMT = "@i18n(app.modules.fblstatus.arming_flags_active_fmt)@"

arming_flags.FLAG_COUNT = FLAG_COUNT
arming_flags.FLAG_TAGS = FLAG_TAGS
arming_flags.ACTIVE_FMT = ACTIVE_FMT

function arming_flags.normalize(mask)
  local value = tonumber(mask)
  if not value or value ~= value or value < 0 then return 0 end
  return value
end

function arming_flags.hasBit(mask, bit)
  return math.floor(arming_flags.normalize(mask) / (2 ^ bit)) % 2 >= 1
end

-- Active flags, lowest bit first -- the order the pilot clears them in.
-- A list of display strings, never a joined string: joining is what made the
-- original unreadable, so the join deliberately does not exist here.
function arming_flags.active(mask)
  mask = arming_flags.normalize(mask)
  local active = {}
  for bit = 0, 31 do
    if arming_flags.hasBit(mask, bit) then
      active[#active + 1] = FLAG_TAGS[bit] or string.format("0x%X", 2 ^ bit)
    end
  end
  if #active == 0 and mask > 0 then
    -- Fallback for values wider than 32 bits.
    active[1] = string.format("0x%X", mask)
  end
  return active
end

function arming_flags.count(mask)
  return #arming_flags.active(mask)
end

-- Short by construction, and the only thing that ever reaches the value
-- column. The page colours it; the colour is not decided here because only
-- GREEN and RED are proven to exist as globals (app/diagnostics_common.lua).
-- `active` may be passed in when the caller already has the list, so a page
-- that needs both does not walk the mask twice.
function arming_flags.summary(mask, active)
  active = active or arming_flags.active(mask)
  if #active == 0 then return "@i18n(app.modules.fblstatus.ok)@", 0 end
  return string.format(ACTIVE_FMT, #active), #active
end

-- What the page used to build, kept only so the offline check can assert that
-- the old form really was over budget -- i.e. that the clipping was real and
-- not a guess. Not called by the page.
function arming_flags.joinedTextForComparison(mask)
  return table.concat(arming_flags.active(mask), ", ")
end

package.loaded["rfsuite.lib.arming_flags"] = arming_flags
return arming_flags
