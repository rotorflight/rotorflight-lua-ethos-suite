-- Check that accelerometer trims are shown as raw tenths-of-a-degree values.

local ROOT = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]bin[/\\]")
assert(ROOT, "could not locate repository root")
package.path = ROOT .. "/src/?.lua;" .. ROOT .. "/src/?/init.lua;" .. package.path

local codec = dofile(ROOT .. "/src/rfsuite/lib/msp_acc_trim.lua")
for _, key in ipairs({"pitch", "roll"}) do
  local meta = codec.FIELD_META[key]
  assert(meta.min == -300 and meta.max == 300, key .. " trim range changed")
  assert(meta.suffix == nil, key .. " trim must not be labelled in degrees")
end

local f = assert(io.open(ROOT .. "/docs/pages/setup/accelerometer.md", "r"))
local docs = f:read("*a")
f:close()
assert(docs:find("tenths of a degree", 1, true), "docs must explain tenths-of-a-degree units")
assert(not docs:find("-300 to 300 °", 1, true), "docs must not label raw trim values as degrees")

print("accelerometer trim units are documented and displayed correctly")
