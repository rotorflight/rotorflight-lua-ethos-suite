-- Gate: lib/heli3d.lua, the 3D helicopter shared by the Alignment page and
-- any page that shows a helicopter.
--
-- Run it from the repository root:
--     lua5.4 bin/heli3d/verify_heli3d.lua
--
-- Checks, against a fake lcd that records the triangles paint draws:
--   * every service() step and every draw() stays far under Ethos's 20000
--     instruction limit per callback (counted with a debug hook, as
--     bin/perf does), through a build, a pose and a rotor change;
--   * the model's orientation: from behind, the "cw" tail rotor is right
--     of the boom and the "ccw" one left of it; roll > 0 dips the right side,
--     pitch > 0 points the nose down, yaw 90 points it right;
--   * the pose: hide removes the rotor disc, lit recolours it, disc tilts
--     the disc front down for pitch > 0;
--   * draw() allocates nothing once a frame is finished.

local LIMIT = 12000   -- well under Ethos's 20000, for headroom on the radio

package.path = "src/rfsuite/?.lua;" .. package.path

local tris = {}
local current
lcd = {
  RGB = function(r, g, b, a) return string.format("%d,%d,%d,%s", r, g, b, a or 1) end,
  darkMode = function() return true end,
  getWindowSize = function() return 800, 480 end,
  setClipping = function() end,
  invalidate = function() end,
  color = function(c) current = c end,
  drawFilledTriangle = function(x1, y1, x2, y2, x3, y3)
    tris[#tris + 1] = {x1, y1, x2, y2, x3, y3, current}
  end,
}

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print("  ok    " .. label)
  else
    failures = failures + 1
    print("  FAIL  " .. label)
    if detail then print("        " .. tostring(detail)) end
  end
end

local count = 0
local function measure(fn, ...)
  count = 0
  debug.sethook(function() count = count + 1 end, "", 1)
  local r = fn(...)
  debug.sethook()
  return count, r
end

local _, heli = measure(dofile, "src/rfsuite/lib/heli3d.lua")

local BOX_X, BOX_Y, BOX_W, BOX_H = 0, 0, 400, 300

-- Service until the frame for this view is finished; the worst step and
-- the worst paint on the way.
local worstStep, worstPaint, worstWhere = 0, 0, ""
local function settle(r, p, y, where)
  for _ = 1, 80 do
    local c = measure(heli.draw, BOX_X, BOX_Y, BOX_W, BOX_H, r, p, y)
    if c > worstPaint then worstPaint = c end
    local s, did = measure(heli.service)
    if s > worstStep then worstStep, worstWhere = s, where end
    if not did then return true end
  end
  return false
end

local function frame(r, p, y, where)
  settle(r, p, y, where)
  tris = {}
  heli.draw(BOX_X, BOX_Y, BOX_W, BOX_H, r, p, y)
  local t = tris
  tris = {}
  return t
end

-- An arrow's start (its first triangle's first point) on screen: the
-- anchor's position, with everything else hidden so the arrow is all that
-- is drawn.
local HIDE_ALL = {body = true, mainrotor = true, head = true, tailrotor = true, fin = true, stab = true, skids = true}
local function anchorOnScreen(rotor, at, dir, r, p, y)
  heli.setup({rotor = rotor})
  heli.pose({hide = HIDE_ALL, arrows = {{at = at, dir = dir}}})
  local t = frame(r, p, y, "anchor " .. at)
  if #t < 3 then return nil end
  return t[1][1], t[1][2], t[3][1], t[3][2]
end

local CX, CY = BOX_X + BOX_W / 2, BOX_Y + BOX_H / 2

print("Orientation")
local x = anchorOnScreen("cw", "tail", "right", 0, 0, 0)
check("cw: tail rotor right of the boom, seen from behind", x and x > CX + 3, x)
x = anchorOnScreen("ccw", "tail", "right", 0, 0, 0)
check("ccw: tail rotor left of the boom, seen from behind", x and x < CX - 3, x)
local sx, sy, tx = anchorOnScreen("cw", "tail", "right", 0, 0, 0)
check("arrow \"right\" points right, seen from behind", sx and tx > sx, tostring(sx) .. " -> " .. tostring(tx))
local _, levelY = anchorOnScreen("cw", "discright", "up", 0, 0, 0)
local _, rolledY = anchorOnScreen("cw", "discright", "up", 30, 0, 0)
check("roll > 0 dips the right side", levelY and rolledY and rolledY > levelY + 10, tostring(levelY) .. " -> " .. tostring(rolledY))
local ux, uy = heli.noseDirection(0, 20, 0)
check("pitch > 0 points the nose down", uy and uy < -0.9, uy)
ux, uy = heli.noseDirection(0, 0, 90)
check("yaw 90 points the nose right", ux and ux > 0.9, ux)

print("Pose")
heli.setup(nil)
heli.pose(nil)
local plain = frame(0, 0, 30, "plain")
local discColour
for i = 1, #plain do
  if plain[i][7]:match(",0%.16$") then discColour = plain[i][7] break end
end
check("the rotor discs are drawn translucent", discColour ~= nil)
heli.pose({hide = {mainrotor = true}})
local hidden = frame(0, 0, 30, "hide")
check("hide mainrotor drops the 16 disc triangles", #plain - #hidden == 16, #plain .. " -> " .. #hidden)
heli.pose({lit = {mainrotor = true}})
local lit = frame(0, 0, 30, "lit")
local litCount = 0
for i = 1, #lit do if lit[i][7] == "255,165,30,0.45" then litCount = litCount + 1 end end
check("lit mainrotor draws the disc in the highlight colour", litCount == 16, litCount)
heli.pose({hide = HIDE_ALL, arrows = {{at = "discfront", dir = "up"}}})
local fy = frame(0, 0, 90, "disc level")[1][2]
heli.pose({hide = HIDE_ALL, disc = {pitch = 15}, arrows = {{at = "discfront", dir = "up"}}})
local fy2 = frame(0, 0, 90, "disc tilted")[1][2]
check("disc pitch > 0 dips its front", fy2 > fy + 5, fy .. " -> " .. fy2)

print("Instructions")
heli.pose(nil)
for i = 1, 8 do
  if i == 4 then heli.setup({rotor = "ccw"}) end
  if i == 6 then heli.pose({lit = {tailrotor = true}, disc = {roll = 10, pitch = -8},
    arrows = {{at = "tail", dir = "left"}, {at = "hub", dir = "up"}, {at = "nose", dir = "right"}}}) end
  frame(i * 23, -i * 9, i * 47, "view " .. i)
end
check(string.format("worst service() step under %d (%d, %s)", LIMIT, worstStep, worstWhere), worstStep < LIMIT)
check(string.format("worst draw() under %d (%d)", LIMIT, worstPaint), worstPaint < LIMIT)

print("Allocation")
lcd.drawFilledTriangle = function() end
lcd.color = function() end
heli.pose(nil)
settle(5, 5, 5, "alloc")
collectgarbage("stop")
local before = collectgarbage("count")
for _ = 1, 50 do
  heli.draw(BOX_X, BOX_Y, BOX_W, BOX_H, 5, 5, 5)
  heli.service()
end
local grown = collectgarbage("count") - before
collectgarbage("restart")
check("draw() and an idle service() allocate nothing", grown < 0.5, string.format("%.2f KB", grown))

print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
