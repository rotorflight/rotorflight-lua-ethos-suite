-- The 3D helicopter: a low-poly copy of the Rotorflight Configurator's model
-- (rotorflight-configurator resources/models/bell_cw.gltf and bell_ccw.gltf,
-- a Bell 206 style scale fuselage), drawn at a given attitude inside a box.
-- Used by the Alignment page (app/alignment_visual.lua); built to be shared
-- by any page that shows a helicopter, such as a setup wizard.
--
--   heli3d.setup(spec)        -- which variant (default: clockwise main rotor)
--   heli3d.pose(pose)         -- light up, hide or move parts; draw arrows
--   heli3d.draw(x, y, w, h, roll, pitch, yaw[, zoom])   -- from paint
--   heli3d.service()          -- from wakeup, on every page that draws it
--   local ux, uy = heli3d.noseDirection(roll, pitch, yaw)
--
-- Ethos stops any callback that runs 20000 Lua instructions. Building the
-- mesh and computing a frame each cost more than that in one go, so neither
-- happens in paint: service() does one step per wakeup (a build stage, the
-- pose, or one slice of a frame) and finishes a frame into a display list of
-- screen triangles; draw() records the view it wants and replays the last
-- finished frame for that box. A new view shows a few wakeups later; a live
-- attitude runs a frame behind.
--
-- Angles are degrees in MSP_ATTITUDE's sense: roll > 0 dips the right side,
-- pitch > 0 dips the nose (the firmware's angle mode puts forward stick and
-- a nose-down attitude on the same side), yaw > 0 turns the nose right. Yaw 0 shows the model from behind (tail towards the viewer), as
-- the pilot sees it standing behind the model; callers that follow the live
-- heading subtract their own reference yaw first. draw() sizes the model so
-- it fits the box in any attitude (at zoom 1) and clips to the box.
--
-- spec (setup):
--   spec.rotor   "cw" (default) | "ccw": main rotor direction seen from
--                above, as the Configurator picks bell_cw / bell_ccw. The
--                tail rotor sits on the right of the boom for "cw" and on
--                the left for "ccw" (left and right as seen from behind).
--
-- pose (pose), every field optional; nil puts everything back to normal:
--   pose.lit     {group = true, ...}  drawn in the highlight colour
--   pose.hide    {group = true, ...}  not drawn
--   pose.disc    {roll = deg, pitch = deg}  tilts the main rotor disc about
--                the hub, in MSP_ATTITUDE's sense: pitch > 0 dips its front
--                (forward cyclic), roll > 0 dips its right side
--   pose.arrows  {{at = anchor, dir = direction}, ...}  arrows drawn from an
--                anchor, in the text colour
--
--   groups:      "body" (cabin and boom), "mainrotor" (disc), "head" (mast
--                and hub), "tailrotor" (disc and gearbox), "fin", "stab"
--                (horizontal stabiliser), "skids"
--   anchors:     "nose", "hub", "tail" (tail rotor hub), "discfront",
--                "discback", "discleft", "discright" (main rotor disc edges;
--                they follow pose.disc)
--   directions:  "up", "down", "left", "right", "forward", "back" (the
--                helicopter's own axes, so an arrow turns with the model)
--
-- pose() and setup() act on a different table only: callers keep their pose
-- tables in constants and pass the same one each paint.
--
-- The mesh is written in the glTF file's own coordinates (x = right side,
-- y = up, z = aft; the nose is at z -43, the fin tip at z 101, the main rotor
-- disc has a radius of 78) so its numbers can be checked against it, and
-- converted once, at build, to this renderer's X = nose(+)/tail(-),
-- Y = left(+)/right(-), Z = up(+)/down(-).
--
-- Rendering: the attitude becomes one rotation matrix (built by passing the
-- three axes through rotatePoint(), the orientation the Alignment page was
-- tuned with), every vertex is rotated and projected once into reused
-- buffers, faces of closed parts that point away from the camera are dropped,
-- the rest are flat-shaded from a fixed light and drawn far-to-near. The
-- rotor discs are translucent, as in the Configurator. The camera sits
-- CAMERA_ELEVATION above the model's level plane, so a level rotor disc shows
-- as a disc instead of a line. No tables are allocated per paint or frame;
-- shaded colours are built once per theme, the mesh once per setup().

if package.loaded["rfsuite.lib.heli3d"] then
  return package.loaded["rfsuite.lib.heli3d"]
end

local cos = math.cos
local sin = math.sin
local rad = math.rad
local floor = math.floor
local sqrt = math.sqrt
local max = math.max
local min = math.min
local pi = math.pi
local t_sort = table.sort

local BASE_VIEW_PITCH_R = rad(-90)
local BASE_VIEW_YAW_R = rad(90)
local CAMERA_DIST = 7.0
local CAMERA_NEAR_EPS = 0.25
local CAMERA_ELEVATION_R = rad(20)
local CAM_EC = cos(CAMERA_ELEVATION_R)
local CAM_ES = sin(CAMERA_ELEVATION_R)

local function rotatePoint(x, y, z, pitchR, yawR, rollR)
  local cbp = cos(BASE_VIEW_PITCH_R)
  local sbp = sin(BASE_VIEW_PITCH_R)
  local px = x
  local py = y * cbp - z * sbp
  local pz = y * sbp + z * cbp

  local cby = cos(BASE_VIEW_YAW_R)
  local sby = sin(BASE_VIEW_YAW_R)
  local bx = px * cby + pz * sby
  local by = py
  local bz = -px * sby + pz * cby

  local cz = cos(rollR)
  local sz = sin(rollR)
  local cx = cos(pitchR)
  local sx = sin(pitchR)
  local cy = cos(yawR)
  local sy = sin(yawR)

  local x1 = bx * cz - by * sz
  local y1 = bx * sz + by * cz
  local z1 = bz

  local x2 = x1
  local y2 = y1 * cx - z1 * sx
  local z2 = y1 * sx + z1 * cx

  local x3 = x2 * cy + z2 * sy
  local y3 = y2
  local z3 = -x2 * sy + z2 * cy

  return x3, y3, z3
end

---------------------------------------------------------------------------
-- Mesh
---------------------------------------------------------------------------

-- glTF -> renderer: scale, and the glTF point that becomes the origin (the
-- middle of the whole model, rotor disc included, a little behind the mast).
local MODEL_SCALE = 0.028
local ORIGIN_Y = 3.0
local ORIGIN_Z = 11.0

local MAT_BODY = 1
local MAT_TRIM = 2
local MAT_GLASS = 3
local MAT_METAL = 4
local MAT_DISC = 5
local MAT_ACTIVE = 6
local MAT_ACTIVE_DISC = 7

local G_BODY = 1
local G_MAINROTOR = 2
local G_HEAD = 3
local G_TAILROTOR = 4
local G_FIN = 5
local G_STAB = 6
local G_SKIDS = 7
local GROUPS = {body = G_BODY, mainrotor = G_MAINROTOR, head = G_HEAD, tailrotor = G_TAILROTOR,
  fin = G_FIN, stab = G_STAB, skids = G_SKIDS}

local MX, MY, MZ = {}, {}, {}
local vertexCount = 0

-- Faces: up to four vertex indices (FD = 0 for a triangle), a material (its
-- own, FBASE, and the one drawn, FMAT), a group, and whether the face is a
-- flat plate seen from both sides (discs, fin, stabiliser) or one side of a
-- closed part (culled when facing away).
local FA, FB, FC, FD, FMAT, FBASE, FGROUP, FTWO = {}, {}, {}, {}, {}, {}, {}, {}
local faceCount = 0

-- The main rotor disc's vertices (rest positions, renderer axes), which
-- pose.disc tilts about the hub.
local DISC_V, DRX, DRY, DRZ = {}, {}, {}, {}
local discCount = 0
local hubX, hubY, hubZ = 0, 0, 0

-- Arrow anchors, renderer axes.
local ANCHOR_X, ANCHOR_Y, ANCHOR_Z = {}, {}, {}

local MODEL_RADIUS = 1

-- +1 for "cw" (tail rotor on the right, glTF +x), -1 for "ccw".
local tailSide = 1

local function vtx(gx, gy, gz)
  vertexCount = vertexCount + 1
  MX[vertexCount] = -(gz - ORIGIN_Z) * MODEL_SCALE
  MY[vertexCount] = -gx * MODEL_SCALE
  MZ[vertexCount] = (gy - ORIGIN_Y) * MODEL_SCALE
  return vertexCount
end

local function anchor(name, gx, gy, gz)
  ANCHOR_X[name] = -(gz - ORIGIN_Z) * MODEL_SCALE
  ANCHOR_Y[name] = -gx * MODEL_SCALE
  ANCHOR_Z[name] = (gy - ORIGIN_Y) * MODEL_SCALE
end

local function pushFace(a, b, c, d, mat, group, twoSided)
  faceCount = faceCount + 1
  FA[faceCount], FB[faceCount], FC[faceCount], FD[faceCount] = a, b, c, d or 0
  FMAT[faceCount], FBASE[faceCount] = mat, mat
  FGROUP[faceCount] = group
  FTWO[faceCount] = twoSided
end

local function plate(a, b, c, d, mat, group)
  pushFace(a, b, c, d, mat, group, true)
end

-- One face of a closed part. (rx, ry, rz) is a glTF point inside the part
-- next to this face; the winding is flipped if needed so the normal points
-- away from it, which is all the back-face test needs.
local function solid(a, b, c, d, mat, group, rx, ry, rz)
  local ix = -(rz - ORIGIN_Z) * MODEL_SCALE
  local iy = -rx * MODEL_SCALE
  local iz = (ry - ORIGIN_Y) * MODEL_SCALE
  local ux, uy, uz = MX[b] - MX[a], MY[b] - MY[a], MZ[b] - MZ[a]
  local vx, vy, vz = MX[c] - MX[a], MY[c] - MY[a], MZ[c] - MZ[a]
  local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
  local n = d and 4 or 3
  local gx = (MX[a] + MX[b] + MX[c] + (d and MX[d] or 0)) / n - ix
  local gy = (MY[a] + MY[b] + MY[c] + (d and MY[d] or 0)) / n - iy
  local gz = (MZ[a] + MZ[b] + MZ[c] + (d and MZ[d] or 0)) / n - iz
  if nx * gx + ny * gy + nz * gz < 0 then
    if d then a, b, c, d = a, d, c, b else b, c = c, b end
  end
  pushFace(a, b, c, d, mat, group, false)
end

-- Fuselage and boom stations, measured from the glTF's cross-sections:
-- {z, top half width, top y, widest half width, shoulder y, hip y, bottom
-- half width, bottom y}. Each becomes a ring of eight points: top left, top
-- right, shoulder right, hip right, bottom right, bottom left, hip left,
-- shoulder left. The roof steps up into the engine cowling at z -4; from
-- z 33 the rings are the tail boom.
local STATIONS = {
  {-43, 0.8, -6.8, 1.6, -7.3, -8.6, 0.8, -9.2},
  {-39, 2.5, -4.6, 6.3, -6.4, -9.0, 2.4, -11.0},
  {-34, 3.4, -1.0, 8.4, -5.0, -9.6, 4.5, -13.0},
  {-27, 4.0, 5.0, 9.8, -2.5, -10.0, 6.8, -14.2},
  {-18, 4.4, 9.5, 10.2, 3.0, -9.8, 7.6, -14.3},
  {-10, 4.5, 12.0, 10.3, 4.2, -9.0, 9.2, -14.2},
  {-4, 4.0, 15.7, 10.3, 4.6, -9.0, 9.3, -14.0},
  {8, 5.0, 15.6, 10.3, 4.7, -7.5, 8.8, -13.6},
  {16, 5.2, 14.9, 8.5, 4.7, -6.7, 6.7, -12.4},
  {23, 4.4, 14.0, 6.6, 4.0, -3.0, 4.8, -10.8},
  {29, 3.2, 11.4, 4.8, 4.5, 0.0, 2.2, -8.0},
  {33, 2.0, 9.0, 3.0, 6.5, 3.5, 1.6, 0.2},
  {55, 1.5, 9.4, 2.3, 7.6, 5.6, 1.3, 3.6},
  {86, 1.0, 10.4, 1.5, 9.5, 8.0, 0.9, 6.8},
}

-- Materials of each segment's eight bands (top, upper right, side right,
-- lower right, bottom, lower left, side left, upper left), segment k running
-- from station k to k + 1: a blue nose cap, the windscreen and chin windows,
-- the door windows either side of a pillar, a blue stripe down the boom.
local B, T, G = MAT_BODY, MAT_TRIM, MAT_GLASS
local SEGMENT_MATS = {
  {T, T, T, T, T, T, T, T},
  {T, T, T, G, G, G, T, T},
  {G, G, G, G, B, G, G, G},
  {G, G, G, B, B, B, G, G},
  {B, G, G, B, B, B, G, G},
  {B, B, B, B, B, B, B, B},
  {B, B, G, B, B, B, G, B},
  {B, B, B, B, B, B, B, B},
  {B, B, B, B, B, B, B, B},
  {B, B, B, B, B, B, B, B},
  {B, B, B, B, B, B, B, B},
  {B, B, T, B, B, B, T, B},
  {B, B, T, B, B, B, T, B},
}

local rings = {}

local function ring(k)
  local s = STATIONS[k]
  local z, tw, yt, hw, ys, yh, bw, yb = s[1], s[2], s[3], s[4], s[5], s[6], s[7], s[8]
  local r = rings[k] or {}
  r[1], r[2], r[3], r[4] = vtx(-tw, yt, z), vtx(tw, yt, z), vtx(hw, ys, z), vtx(hw, yh, z)
  r[5], r[6], r[7], r[8] = vtx(bw, yb, z), vtx(-bw, yb, z), vtx(-hw, yh, z), vtx(-hw, ys, z)
  rings[k] = r
end

local function segment(k)
  local r0, r1 = rings[k], rings[k + 1]
  local s0, s1 = STATIONS[k], STATIONS[k + 1]
  local rz = (s0[1] + s1[1]) * 0.5
  local ry = (s0[5] + s0[6] + s1[5] + s1[6]) * 0.25
  local mats = SEGMENT_MATS[k]
  for j = 1, 8 do
    local j2 = (j % 8) + 1
    solid(r0[j], r0[j2], r1[j2], r1[j], mats[j], G_BODY, 0, ry, rz)
  end
end

-- Close a ring (the nose tip, the boom end) with three quads; (rz) is a
-- glTF z inside the part behind that ring.
local function cap(k, mat, rz)
  local r = rings[k]
  local s = STATIONS[k]
  local ry = (s[5] + s[6]) * 0.5
  solid(r[1], r[2], r[3], r[8], mat, G_BODY, 0, ry, rz)
  solid(r[8], r[3], r[4], r[7], mat, G_BODY, 0, ry, rz)
  solid(r[7], r[4], r[5], r[6], mat, G_BODY, 0, ry, rz)
end

-- An n-sided upright prism around the y axis (x, z centre), y0 to y1, with
-- its top closed when asked.
local function prism(cx, cz, radius, y0, y1, n, mat, group, top)
  local lo, hi = {}, {}
  for k = 1, n do
    local a = (k - 0.5) * 2 * pi / n
    local px, pz = cx + radius * cos(a), cz + radius * sin(a)
    lo[k], hi[k] = vtx(px, y0, pz), vtx(px, y1, pz)
  end
  local ym = (y0 + y1) * 0.5
  for k = 1, n do
    local k2 = (k % n) + 1
    solid(lo[k], lo[k2], hi[k2], hi[k], mat, group, cx, ym, cz)
  end
  if top then
    for k = 2, n - 1, 2 do
      local k3 = (k + 1 <= n) and k + 1 or 1
      if k + 2 <= n then
        solid(hi[1], hi[k], hi[k3], hi[k + 2], mat, group, cx, ym, cz)
      else
        solid(hi[1], hi[k], hi[k3], nil, mat, group, cx, ym, cz)
      end
    end
  end
end

-- A translucent disc: a fan of n triangles about its centre. axis "y" lies
-- flat (the main rotor), axis "x" stands upright across the boom (the tail
-- rotor). The main rotor's vertices are kept so pose.disc can tilt them.
local function disc(cx, cy, cz, radius, n, axis, group, keep)
  local centre = vtx(cx, cy, cz)
  local first = vertexCount + 1
  for k = 1, n do
    local a = (k - 1) * 2 * pi / n
    if axis == "y" then
      vtx(cx + radius * cos(a), cy, cz + radius * sin(a))
    else
      vtx(cx, cy + radius * cos(a), cz + radius * sin(a))
    end
  end
  for k = 0, n - 1 do
    plate(centre, first + k, first + ((k + 1) % n), nil, MAT_DISC, group)
  end
  if keep then
    hubX, hubY, hubZ = MX[centre], MY[centre], MZ[centre]
    discCount = 0
    for v = centre, first + n - 1 do
      discCount = discCount + 1
      DISC_V[discCount] = v
      DRX[discCount], DRY[discCount], DRZ[discCount] = MX[v], MY[v], MZ[v]
    end
  end
end

-- An axis-aligned box (glTF units).
local function box(x0, x1, y0, y1, z0, z1, mat, group)
  local a, b = vtx(x0, y0, z0), vtx(x1, y0, z0)
  local c, d = vtx(x1, y0, z1), vtx(x0, y0, z1)
  local e, f = vtx(x0, y1, z0), vtx(x1, y1, z0)
  local g, h = vtx(x1, y1, z1), vtx(x0, y1, z1)
  local mx, my, mz = (x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5
  solid(a, b, c, d, mat, group, mx, my, mz)
  solid(e, f, g, h, mat, group, mx, my, mz)
  solid(a, b, f, e, mat, group, mx, my, mz)
  solid(d, c, g, h, mat, group, mx, my, mz)
  solid(a, d, h, e, mat, group, mx, my, mz)
  solid(b, c, g, f, mat, group, mx, my, mz)
end

-- A square tube along a path of {y, z} points at a given x: the skids.
local TUBE = 0.75
local function tube(x, path)
  local prev
  for i = 1, #path do
    local y, z = path[i][1], path[i][2]
    local q = {vtx(x - TUBE, y + TUBE, z), vtx(x + TUBE, y + TUBE, z),
      vtx(x + TUBE, y - TUBE, z), vtx(x - TUBE, y - TUBE, z)}
    if prev then
      local my, mz = (y + path[i - 1][1]) * 0.5, (z + path[i - 1][2]) * 0.5
      for k = 1, 4 do
        local k2 = (k % 4) + 1
        solid(prev[k], prev[k2], q[k2], q[k], MAT_METAL, G_SKIDS, x, my, mz)
      end
    end
    prev = q
  end
end

-- A cross tube from the belly out to a skid, as a flat strip (glTF {x, y}
-- points at z, mirrored to the left).
local CROSS = {{7.5, -14.0}, {15.2, -16.8}, {17.2, -20.6}}
local function crossTube(z)
  for s = -1, 1, 2 do
    for i = 1, #CROSS - 1 do
      local a, b = CROSS[i], CROSS[i + 1]
      plate(vtx(s * a[1], a[2], z - 0.8), vtx(s * b[1], b[2], z - 0.8),
        vtx(s * b[1], b[2], z + 0.8), vtx(s * a[1], a[2], z + 0.8), MAT_METAL, G_SKIDS)
    end
  end
end

---------------------------------------------------------------------------
-- Building: one stage per service() call, each a few thousand instructions.
---------------------------------------------------------------------------

local oldVertices, oldFaces = 0, 0

local STAGES = {
  function()
    oldVertices, oldFaces = vertexCount, faceCount
    vertexCount, faceCount = 0, 0
    for k = 1, #STATIONS do ring(k) end
    cap(1, MAT_TRIM, -40)
    cap(#STATIONS, MAT_BODY, 80)
  end,
  function() for k = 1, 5 do segment(k) end end,
  function() for k = 6, 9 do segment(k) end end,
  function() for k = 10, #STATIONS - 1 do segment(k) end end,
  function()
    -- Horizontal stabiliser (blue, as in the Configurator), and the fin on
    -- the side of the boom away from the tail rotor: an upper and a lower
    -- (ventral) part, swept back.
    for s = -1, 1, 2 do
      plate(vtx(s * 2.0, 6.4, 55.5), vtx(s * 12.5, 6.4, 57.0), vtx(s * 12.5, 6.4, 63.0), vtx(s * 2.0, 6.4, 63.0), MAT_TRIM, G_STAB)
    end
    local fx = -2.9 * tailSide
    plate(vtx(fx, 10.3, 83.5), vtx(fx, 27.8, 97.6), vtx(fx, 27.8, 101.3), vtx(fx, 10.3, 92.0), MAT_BODY, G_FIN)
    plate(vtx(fx, 7.5, 85.0), vtx(fx, 7.5, 92.6), vtx(fx, -6.2, 96.9), vtx(fx, -6.2, 92.6), MAT_BODY, G_FIN)
    -- Tail rotor gearbox, and the tail rotor disc beside it.
    local g0, g1 = 0.4 * tailSide, 3.3 * tailSide
    box(min(g0, g1), max(g0, g1), 8.4, 10.5, 87.6, 89.7, MAT_METAL, G_TAILROTOR)
    disc(3.6 * tailSide, 9.45, 88.65, 12.4, 12, "x", G_TAILROTOR, false)
    anchor("tail", 4.5 * tailSide, 9.45, 88.65)
    anchor("nose", 0, -7.5, -44)
  end,
  function()
    -- Mast, rotor head, and the main rotor disc.
    prism(0, 0, 1.3, 15.0, 23.6, 6, MAT_METAL, G_HEAD, false)
    prism(0, 0, 5.4, 23.6, 26.0, 6, MAT_METAL, G_HEAD, true)
    disc(0, 25.6, 0, 78, 16, "y", G_MAINROTOR, true)
    anchor("hub", 0, 27, 0)
  end,
  function()
    -- Skids: a tube each side, turned up at the front, on two cross tubes.
    for s = -1, 1, 2 do
      tube(s * 17.7, {{-18.6, -25.5}, {-20.6, -20.0}, {-21.4, 14.3}})
    end
    crossTube(-15.5)
    crossTube(7.0)
  end,
  function()
    -- Free what a bigger mesh used before; measure the model.
    for i = vertexCount + 1, oldVertices do MX[i], MY[i], MZ[i] = nil, nil, nil end
    for i = faceCount + 1, oldFaces do
      FA[i], FB[i], FC[i], FD[i], FMAT[i], FBASE[i], FGROUP[i], FTWO[i] = nil, nil, nil, nil, nil, nil, nil, nil
    end
    MODEL_RADIUS = 0
    for i = 1, vertexCount do
      MODEL_RADIUS = max(MODEL_RADIUS, sqrt(MX[i] * MX[i] + MY[i] * MY[i] + MZ[i] * MZ[i]))
    end
  end,
}

---------------------------------------------------------------------------
-- Pose
---------------------------------------------------------------------------

-- Directions in renderer axes (X nose, Y left, Z up).
local DIRECTIONS = {
  up = {0, 0, 1}, down = {0, 0, -1},
  left = {0, 1, 0}, right = {0, -1, 0},
  forward = {1, 0, 0}, back = {-1, 0, 0},
}

local NO_POSE = {}
local NONE = {}

-- Groups hidden by the pose (by group number), and the arrows to draw:
-- anchor point and direction, renderer axes.
local HIDDEN = {}
local AX, AY, AZ, ADX, ADY, ADZ = {}, {}, {}, {}, {}, {}
local arrowCount = 0

-- Tilt the main rotor disc about the hub: pitch > 0 dips the front (+X),
-- roll > 0 the right side (-Y). Small-angle tilt of a flat disc, enough to show the
-- way the cyclic moves it.
local function tiltDisc(rollDeg, pitchDeg)
  local sp, cp = sin(rad(pitchDeg)), cos(rad(pitchDeg))
  local sr, cr = sin(rad(rollDeg)), cos(rad(rollDeg))
  for k = 1, discCount do
    local v = DISC_V[k]
    local x, y, z = DRX[k] - hubX, DRY[k] - hubY, DRZ[k] - hubZ
    MX[v] = hubX + x * cp
    MY[v] = hubY + y * cr
    MZ[v] = hubZ + z - x * sp + y * sr
  end
  return sp, cp, sr, cr
end

local LIT = {}

local function applyPose(p)
  local lit, hide = p.lit or NONE, p.hide or NONE
  for name, g in pairs(GROUPS) do
    HIDDEN[g] = hide[name] and true or false
    LIT[g] = lit[name] and true or false
  end
  for i = 1, faceCount do
    local base = FBASE[i]
    if LIT[FGROUP[i]] then base = (base == MAT_DISC) and MAT_ACTIVE_DISC or MAT_ACTIVE end
    FMAT[i] = base
  end
  local d = p.disc
  local sp, cp, sr, cr = tiltDisc(d and d.roll or 0, d and d.pitch or 0)
  -- The disc's edges, tilted with it (radius 78, glTF).
  local r = 78 * MODEL_SCALE
  ANCHOR_X.discfront, ANCHOR_Y.discfront, ANCHOR_Z.discfront = hubX + r * cp, hubY, hubZ - r * sp
  ANCHOR_X.discback, ANCHOR_Y.discback, ANCHOR_Z.discback = hubX - r * cp, hubY, hubZ + r * sp
  ANCHOR_X.discleft, ANCHOR_Y.discleft, ANCHOR_Z.discleft = hubX, hubY + r * cr, hubZ + r * sr
  ANCHOR_X.discright, ANCHOR_Y.discright, ANCHOR_Z.discright = hubX, hubY - r * cr, hubZ - r * sr
  local arrows = p.arrows or NONE
  local n = 0
  for i = 1, #arrows do
    local a = arrows[i]
    local dir = DIRECTIONS[a.dir]
    if dir and ANCHOR_X[a.at] then
      n = n + 1
      AX[n], AY[n], AZ[n] = ANCHOR_X[a.at], ANCHOR_Y[a.at], ANCHOR_Z[a.at]
      ADX[n], ADY[n], ADZ[n] = dir[1], dir[2], dir[3]
    end
  end
  for i = n + 1, arrowCount do AX[i], AY[i], AZ[i], ADX[i], ADY[i], ADZ[i] = nil, nil, nil, nil, nil, nil end
  arrowCount = n
end

---------------------------------------------------------------------------
-- Shading
---------------------------------------------------------------------------

-- Light from above, to the left and in front of the screen (view space:
-- x right, y up, z towards the viewer).
local LIGHT_X, LIGHT_Y, LIGHT_Z
do
  local lx, ly, lz = -0.45, 0.75, 0.50
  local l = sqrt(lx * lx + ly * ly + lz * lz)
  LIGHT_X, LIGHT_Y, LIGHT_Z = lx / l, ly / l, lz / l
end
local AMBIENT = 0.50
local DIFFUSE = 0.60
local SHADE_LEVELS = 8

-- {r, g, b[, alpha]}: an alpha marks a translucent material, drawn
-- unshaded. The Configurator's model: a grey body (its texture's #AAAAAA),
-- blue trim (#1F97C4), black glass and dark metal; its rotor discs are black
-- at 10% opacity, which on a dark screen becomes white.
local BASE_COLORS = {
  dark = {
    [MAT_BODY] = {178, 180, 184},
    [MAT_TRIM] = {31, 151, 196},
    [MAT_GLASS] = {40, 46, 56},
    [MAT_METAL] = {92, 92, 98},
    [MAT_DISC] = {255, 255, 255, 0.16},
    [MAT_ACTIVE] = {255, 165, 30},
    [MAT_ACTIVE_DISC] = {255, 165, 30, 0.45},
  },
  light = {
    [MAT_BODY] = {170, 170, 170},
    [MAT_TRIM] = {31, 151, 196},
    [MAT_GLASS] = {28, 30, 36},
    [MAT_METAL] = {70, 70, 76},
    [MAT_DISC] = {0, 0, 0, 0.13},
    [MAT_ACTIVE] = {255, 150, 0},
    [MAT_ACTIVE_DISC] = {255, 150, 0, 0.45},
  },
}

local shadeCache = {}
local arrowColors = {}

local function shadeTable(isDark)
  local key = isDark and "dark" or "light"
  local cached = shadeCache[key]
  if cached then return cached end
  cached = {}
  for mat, rgb in pairs(BASE_COLORS[key]) do
    local levels = {}
    for i = 1, SHADE_LEVELS do
      if rgb[4] then
        levels[i] = lcd.RGB(rgb[1], rgb[2], rgb[3], rgb[4])
      else
        local s = AMBIENT + DIFFUSE * (i - 1) / (SHADE_LEVELS - 1)
        levels[i] = lcd.RGB(min(255, floor(rgb[1] * s)), min(255, floor(rgb[2] * s)), min(255, floor(rgb[3] * s)))
      end
    end
    cached[mat] = levels
  end
  shadeCache[key] = cached
  return cached
end

local function arrowColor(isDark)
  local key = isDark and 1 or 2
  if not arrowColors[key] then arrowColors[key] = isDark and lcd.RGB(245, 245, 245) or lcd.RGB(20, 20, 20) end
  return arrowColors[key]
end

-- MSP_ATTITUDE degrees -> the angles rotatePoint() takes.
local function toRadians(roll, pitch, yaw)
  return rad(-(pitch or 0)), rad(-(yaw or 0)), rad(-(roll or 0))
end

---------------------------------------------------------------------------
-- Frames. draw() asks for a view and replays the last finished frame (a
-- display list of screen triangles); service() computes the next one in
-- slices (project vertices; cull and shade faces; sort; list), so paint
-- only ever replays. Each slice is a few thousand instructions.
---------------------------------------------------------------------------

local PROJECT_STEP = 130   -- vertices per slice
local SHADE_STEP = 70      -- faces per slice

local DEFAULT_SPEC = {rotor = "cw"}

local currentSpec, buildSpec, buildStage = nil, DEFAULT_SPEC, 1
local ready = false          -- a whole mesh is built
local currentPose, poseWanted = NO_POSE, true
local version = 0            -- bumps whenever the mesh or the pose changes

-- The view draw() last asked for.
local wantX, wantY, wantW, wantH, wantRoll, wantPitch, wantYaw, wantZoom, wantDark

-- The frame being computed: its phase (0 idle, 1 project, 2 shade, 3 sort,
-- 4 list) and the cursor within it.
local phase, cursor = 0, 1
local pX, pY, pW, pH, pRoll, pPitch, pYaw, pZoom, pDark, pVersion, pScale
local VX, VY, VZ, SX, SY = {}, {}, {}, {}, {}
local faceDepth, faceColor = {}, {}
local drawOrder, drawCount, prepCount = {}, 0, 0

-- The finished frame: triangles and their colours, and the view it shows.
local LX1, LY1, LX2, LY2, LX3, LY3, LCOL = {}, {}, {}, {}, {}, {}, {}
local listCount = 0
local listX, listY, listW, listH, listRoll, listPitch, listYaw, listZoom, listDark, listVersion

-- The frame's rotation matrix and projection, for the arrows.
local m11, m12, m13, m21, m22, m23, m31, m32, m33 = 1, 0, 0, 0, 1, 0, 0, 0, 1
local pcx, pcy = 0, 0

local function fartherFirst(a, b)
  return faceDepth[a] < faceDepth[b]
end

-- A model point (renderer axes) on screen, or nil behind the camera.
local function project(x, y, z)
  local vx = x * m11 + y * m12 + z * m13
  local vy = x * m21 + y * m22 + z * m23
  local vz = x * m31 + y * m32 + z * m33
  local denom = CAMERA_DIST - vz
  if denom <= CAMERA_NEAR_EPS then return nil end
  local f = CAMERA_DIST / denom * pScale
  return pcx + vx * f, pcy - vy * f
end

-- One arrow triangle onto the display list.
local function listTriangle(x1, y1, x2, y2, x3, y3, color)
  listCount = listCount + 1
  LX1[listCount], LY1[listCount], LX2[listCount], LY2[listCount] = x1, y1, x2, y2
  LX3[listCount], LY3[listCount], LCOL[listCount] = x3, y3, color
end

local function startFrame()
  pX, pY, pW, pH = wantX, wantY, wantW, wantH
  pRoll, pPitch, pYaw, pZoom, pDark, pVersion = wantRoll, wantPitch, wantYaw, wantZoom, wantDark, version
  pScale = max(4, (min(pW, pH) * 0.5 - 4) / MODEL_RADIUS * pZoom)
  pcx, pcy = pX + floor(pW * 0.5), pY + floor(pH * 0.5)
  local pitchR, yawR, rollR = toRadians(pRoll, pPitch, pYaw)
  -- The images of the three model axes, then the camera elevation (a tilt
  -- about the screen's horizontal axis).
  local ax, ay, az = rotatePoint(1, 0, 0, pitchR, yawR, rollR)
  local bx, by, bz = rotatePoint(0, 1, 0, pitchR, yawR, rollR)
  local cx3, cy3, cz3 = rotatePoint(0, 0, 1, pitchR, yawR, rollR)
  ay, az = ay * CAM_EC - az * CAM_ES, ay * CAM_ES + az * CAM_EC
  by, bz = by * CAM_EC - bz * CAM_ES, by * CAM_ES + bz * CAM_EC
  cy3, cz3 = cy3 * CAM_EC - cz3 * CAM_ES, cy3 * CAM_ES + cz3 * CAM_EC
  m11, m12, m13, m21, m22, m23, m31, m32, m33 = ax, bx, cx3, ay, by, cy3, az, bz, cz3
end

-- Rotate and project vertices from..to.
local function projectVertices(from, to)
  local ax, bx, cx3, ay, by, cy3, az, bz, cz3 = m11, m12, m13, m21, m22, m23, m31, m32, m33
  local cx, cy, scale = pcx, pcy, pScale
  for i = from, to do
    local x, y, z = MX[i], MY[i], MZ[i]
    local vx = x * ax + y * bx + z * cx3
    local vy = x * ay + y * by + z * cy3
    local vz = x * az + y * bz + z * cz3
    VX[i], VY[i], VZ[i] = vx, vy, vz
    local denom = CAMERA_DIST - vz
    if denom <= CAMERA_NEAR_EPS then
      SX[i] = false
    else
      local f = CAMERA_DIST / denom * scale
      SX[i] = cx + vx * f
      SY[i] = cy - vy * f
    end
  end
end

-- Faces from..to: those that show go on drawOrder (after prepCount), with
-- their depth and shaded colour. From 1 starts a frame's list.
local function shadeFaces(from, to)
  local shades = shadeTable(pDark)
  local count = (from == 1) and 0 or prepCount
  for i = from, to do
    local a, b, c, d = FA[i], FB[i], FC[i], FD[i]
    if not HIDDEN[FGROUP[i]] and SX[a] and SX[b] and SX[c] and (d == 0 or SX[d]) then
      local x0, y0, z0 = VX[a], VY[a], VZ[a]
      local ux, uy, uz = VX[b] - x0, VY[b] - y0, VZ[b] - z0
      local wx, wy, wz = VX[c] - x0, VY[c] - y0, VZ[c] - z0
      local nx, ny, nz = uy * wz - uz * wy, uz * wx - ux * wz, ux * wy - uy * wx
      local facing = nx * -x0 + ny * -y0 + nz * (CAMERA_DIST - z0)
      local visible = true
      if facing < 0 then
        if FTWO[i] then
          nx, ny, nz = -nx, -ny, -nz
        else
          visible = false
        end
      end
      if visible then
        local len = sqrt(nx * nx + ny * ny + nz * nz)
        local lambert = 0
        if len > 0 then
          lambert = (nx * LIGHT_X + ny * LIGHT_Y + nz * LIGHT_Z) / len
          if lambert < 0 then lambert = 0 end
        end
        count = count + 1
        drawOrder[count] = i
        if d == 0 then
          faceDepth[i] = (z0 + VZ[b] + VZ[c]) / 3
        else
          faceDepth[i] = (z0 + VZ[b] + VZ[c] + VZ[d]) * 0.25
        end
        faceColor[i] = shades[FMAT[i]][floor(lambert * (SHADE_LEVELS - 1) + 0.5) + 1]
      end
    end
  end
  prepCount = count
  if to >= faceCount then
    for i = count + 1, drawCount do drawOrder[i] = nil end
    drawCount = count
  end
end

-- Far to near into the display list, with the arrows on top.
local function listFrame()
  local old = listCount
  local n = 0
  for k = 1, drawCount do
    local i = drawOrder[k]
    local a, b, c, d = FA[i], FB[i], FC[i], FD[i]
    local col = faceColor[i]
    local ax, ay, cx, cy = SX[a], SY[a], SX[c], SY[c]
    n = n + 1
    LX1[n], LY1[n], LX2[n], LY2[n], LX3[n], LY3[n], LCOL[n] = ax, ay, SX[b], SY[b], cx, cy, col
    if d ~= 0 then
      n = n + 1
      LX1[n], LY1[n], LX2[n], LY2[n], LX3[n], LY3[n], LCOL[n] = ax, ay, cx, cy, SX[d], SY[d], col
    end
  end
  listCount = n
  local acol = arrowColor(pDark)
  local len = max(16, floor(pScale * 0.7))
  local head = max(6, floor(len * 0.42))
  local half = max(1, floor(len * 0.08))
  for k = 1, arrowCount do
    local mx, my, mz = AX[k], AY[k], AZ[k]
    local px, py = project(mx, my, mz)
    local qx, qy = project(mx + ADX[k] * 0.5, my + ADY[k] * 0.5, mz + ADZ[k] * 0.5)
    if px and qx then
      local ux, uy = qx - px, qy - py
      local ul = sqrt(ux * ux + uy * uy)
      -- Pointing (nearly) at the camera: no arrow to draw.
      if ul > 0.5 then
        ux, uy = ux / ul, uy / ul
        local nx, ny = -uy, ux
        local sx, sy = px + ux * 3, py + uy * 3
        local tx, ty = sx + ux * len, sy + uy * len
        local bx, by = tx - ux * head, ty - uy * head
        listTriangle(sx + nx * half, sy + ny * half, bx + nx * half, by + ny * half, bx - nx * half, by - ny * half, acol)
        listTriangle(sx + nx * half, sy + ny * half, bx - nx * half, by - ny * half, sx - nx * half, sy - ny * half, acol)
        local hw = head * 0.6
        listTriangle(tx, ty, bx + nx * hw, by + ny * hw, bx - nx * hw, by - ny * hw, acol)
      end
    end
  end
  for i = listCount + 1, old do
    LX1[i], LY1[i], LX2[i], LY2[i], LX3[i], LY3[i], LCOL[i] = nil, nil, nil, nil, nil, nil, nil
  end
  listX, listY, listW, listH = pX, pY, pW, pH
  listRoll, listPitch, listYaw, listZoom, listDark, listVersion = pRoll, pPitch, pYaw, pZoom, pDark, pVersion
end

-- The view asked for differs from the finished frame (or the model changed).
local function frameWanted()
  return wantX ~= nil and (listVersion ~= version or listX ~= wantX or listY ~= wantY or listW ~= wantW
    or listH ~= wantH or listRoll ~= wantRoll or listPitch ~= wantPitch or listYaw ~= wantYaw
    or listZoom ~= wantZoom or listDark ~= wantDark)
end

local heli3d = {}

heli3d.DEFAULT = DEFAULT_SPEC

-- Which variant to draw (see the header); nil for the default. A different
-- variant is built over the next service() calls; until then draw() keeps
-- showing the last frame.
function heli3d.setup(spec)
  spec = spec or DEFAULT_SPEC
  if spec == currentSpec then return end
  local same = currentSpec and (currentSpec.rotor == "ccw") == (spec.rotor == "ccw")
  currentSpec = spec
  if same then return end
  tailSide = (spec.rotor == "ccw") and -1 or 1
  buildSpec, buildStage, ready, phase = spec, 1, false, 0
end

-- Light up, hide or move parts and draw arrows (see the header); nil puts
-- everything back to normal. Applied by the next service() call, and only
-- when given a different table.
function heli3d.pose(p)
  p = p or NO_POSE
  if p == currentPose then return end
  currentPose, poseWanted = p, true
end

-- Ask for the model at (roll, pitch, yaw) inside the box, and draw the last
-- finished frame if it was made for this box (its attitude may be a step
-- behind: service() catches up). At zoom 1 (the default) the model's radius
-- is fitted to the box's shorter side, so it stays inside at any attitude;
-- perspective can push a part pointing at the camera slightly further,
-- which the clip catches. A caller whose model only tilts a little can zoom
-- in and let the clip take the rare overflow.
function heli3d.draw(x, y, w, h, roll, pitch, yaw, zoom)
  if w < 8 or h < 8 then return end
  if not currentSpec then heli3d.setup(nil) end
  wantX, wantY, wantW, wantH = x, y, w, h
  wantRoll, wantPitch, wantYaw, wantZoom = roll or 0, pitch or 0, yaw or 0, zoom or 1
  wantDark = lcd.darkMode() and true or false
  if listCount == 0 or listX ~= x or listY ~= y or listW ~= w or listH ~= h or listDark ~= wantDark then return end
  local sw, sh = lcd.getWindowSize()
  lcd.setClipping(x, y, w, h)
  local last = nil
  for i = 1, listCount do
    local col = LCOL[i]
    if col ~= last then lcd.color(col); last = col end
    lcd.drawFilledTriangle(LX1[i], LY1[i], LX2[i], LY2[i], LX3[i], LY3[i])
  end
  lcd.setClipping(0, 0, sw, sh)
end

-- The background work, one step per call: a build stage, the pose, or a
-- slice of a frame. Call it from wakeup on any page that draws the model.
-- Returns true when it did something; invalidates the screen when a frame
-- is finished.
function heli3d.service()
  if not currentSpec then heli3d.setup(nil) end
  if buildStage > 0 then
    STAGES[buildStage](buildSpec)
    if buildStage < #STAGES then
      buildStage = buildStage + 1
    else
      buildStage, ready, poseWanted = 0, true, true
    end
    return true
  end
  if not ready then return false end
  if poseWanted then
    poseWanted = false
    applyPose(currentPose)
    version = version + 1
    phase = 0
    return true
  end
  if phase == 0 then
    if not frameWanted() then return false end
    startFrame()
    phase, cursor = 1, 1
  end
  if phase == 1 then
    local to = min(vertexCount, cursor + PROJECT_STEP - 1)
    projectVertices(cursor, to)
    if to >= vertexCount then phase, cursor = 2, 1 else cursor = to + 1 end
  elseif phase == 2 then
    local to = min(faceCount, cursor + SHADE_STEP - 1)
    shadeFaces(cursor, to)
    if to >= faceCount then phase = 3 else cursor = to + 1 end
  elseif phase == 3 then
    if drawCount > 1 then t_sort(drawOrder, fartherFirst) end
    phase = 4
  else
    listFrame()
    phase = 0
    if lcd.invalidate then lcd.invalidate() end
  end
  return true
end

-- Where the nose points on screen, as a unit vector (x right, y up), or
-- nil when it points straight at or away from the viewer.
function heli3d.noseDirection(roll, pitch, yaw)
  local pitchR, yawR, rollR = toRadians(roll, pitch, yaw)
  local nx, ny, nz = rotatePoint(2.2, 0.0, 0.0, pitchR, yawR, rollR)
  local tx, ty, tz = rotatePoint(-2.2, 0.0, 0.0, pitchR, yawR, rollR)
  local nd, td = CAMERA_DIST - nz, CAMERA_DIST - tz
  if nd <= CAMERA_NEAR_EPS or td <= CAMERA_NEAR_EPS then return nil end
  local dx = nx * CAMERA_DIST / nd - tx * CAMERA_DIST / td
  local dy = ny * CAMERA_DIST / nd - ty * CAMERA_DIST / td
  local mag = sqrt(dx * dx + dy * dy)
  if mag <= 0.001 then return nil end
  return dx / mag, dy / mag
end

package.loaded["rfsuite.lib.heli3d"] = heli3d
return heli3d
