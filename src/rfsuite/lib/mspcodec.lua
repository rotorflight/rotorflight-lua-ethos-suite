-- Minimal, stateless MSP payload byte codec.
--
-- Pure functions only -- no module-level state -- so any subsystem may load
-- this without it becoming a "shared global" in the sense the rest of this
-- codebase forbids: nothing here is session/business state, it's just a
-- byte<->number codec, the same category of neutral utility as lib/bus.lua.
--
-- Arithmetic-based (no bit32/native bitwise ops) so it works unmodified
-- regardless of the Lua version's bitwise-operator support -- for this file
-- alone. The suite as a whole does require Lua 5.3+ for its native `<<`, `>>`,
-- `&` and `|` operators (tasks/msp/common.lua, tasks/msp/transport_sport.lua),
-- so this module's portability buys nothing on its own; it is kept because
-- arithmetic reads/writes are the cheaper spelling here, not as a guarantee
-- that the suite runs on an older runtime.
--
-- Every read is bounds-safe: a byte past the end of the buffer decodes as 0
-- rather than nil, so a truncated payload yields a wrong-but-numeric value
-- instead of a nil that silently propagates into the caller's arithmetic.
-- Decoders that cannot tolerate a missing field should check `#buf` against
-- the size their wire format requires before reading (see msp_battery.lua).

-- Self-caches via package.loaded (same mechanism lib/bus.lua uses) --
-- every MSP codec module (lib/msp_pid_tuning.lua etc.) loadfile()s this,
-- and every one of those in turn gets reloaded fresh on every page open,
-- so without caching this ran again on every single navigation for zero
-- benefit (pure functions, nothing page-specific). Added after a live
-- memory investigation confirmed the *bulk* of this rebuild's observed
-- RAM growth is an Ethos platform trait (the `form` widget system itself
-- retaining something per created field, outside Lua's own GC
-- reachability -- confirmed by checking that rotorflight-lua-ethos-suite
-- shows the same symptom) that no script-side change can eliminate --
-- but redundant reloading of stateless shared modules like this one is a
-- separate, real, avoidable cost. See AGENTS.md's "Memory stats
-- printing" section.
if package.loaded["rfsuite.lib.mspcodec"] then
  return package.loaded["rfsuite.lib.mspcodec"]
end

local math_floor = math.floor

local mspcodec = {}

function mspcodec.readU8(buf)
  local offset = buf.offset or 1
  local value = buf[offset] or 0
  buf.offset = offset + 1
  return value
end

function mspcodec.readS8(buf)
  local value = mspcodec.readU8(buf) or 0
  if value >= 0x80 then value = value - 0x100 end
  return value
end

function mspcodec.readU16(buf)
  local offset = buf.offset or 1
  local value = (buf[offset] or 0) + (buf[offset + 1] or 0) * 256
  buf.offset = offset + 2
  return value
end

function mspcodec.readS16(buf)
  local value = mspcodec.readU16(buf)
  if value >= 0x8000 then value = value - 0x10000 end
  return value
end

function mspcodec.readU32(buf)
  local offset = buf.offset or 1
  local value = (buf[offset] or 0)
    + (buf[offset + 1] or 0) * 256
    + (buf[offset + 2] or 0) * 65536
    + (buf[offset + 3] or 0) * 16777216
  buf.offset = offset + 4
  return value
end

-- Encode side: an MSP payload byte is an integer 0..255. A float reaching
-- here would be written as-is (`3.7 % 256` is 3.7), and the transport's `|`
-- bitwise operator would then abort with "number has no integer
-- representation". No current caller produces a float -- every encoder is fed
-- a value straight out of a read* above -- but the guard costs one floor and
-- keeps the failure here instead of two layers down in the transport.
local function toByte(value)
  return math_floor(value) % 256
end

function mspcodec.writeU8(buf, value)
  buf[#buf + 1] = toByte(value)
end

function mspcodec.writeS8(buf, value)
  if value < 0 then value = value + 0x100 end
  mspcodec.writeU8(buf, value)
end

function mspcodec.writeU16(buf, value)
  value = math_floor(value)
  buf[#buf + 1] = toByte(value)
  buf[#buf + 1] = toByte(value / 256)
end

function mspcodec.writeS16(buf, value)
  if value < 0 then value = value + 0x10000 end
  mspcodec.writeU16(buf, value)
end

function mspcodec.writeU32(buf, value)
  value = math_floor(value)
  buf[#buf + 1] = toByte(value)
  buf[#buf + 1] = toByte(value / 256)
  buf[#buf + 1] = toByte(value / 65536)
  buf[#buf + 1] = toByte(value / 16777216)
end

package.loaded["rfsuite.lib.mspcodec"] = mspcodec
return mspcodec
