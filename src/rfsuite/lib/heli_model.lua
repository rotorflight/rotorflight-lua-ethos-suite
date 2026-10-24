-- A helicopter drawn solid at a given attitude: flat faces in Rotorflight
-- blue under WingFlight's light, a perspective camera on the left side, nose to the left
-- as in the photos. A chubby toy shape: a round cabin running into a short
-- tapered tail, low skids, broad blades and a T tail with a cross tail rotor.
-- Used by the Setup Wizard's orientation check (app/setup_wizard_art.lua);
-- any page that shows an attitude can use it the same way: service() from
-- wakeup, draw() from paint, for the same box.
--
-- Nothing here depends on a page or on the wizard.
--
--   model.service(roll, pitch)  from wakeup, one step per call: the mesh
--                               (a few steps, once), then a frame for the
--                               attitude (a few steps). true when a new frame
--                               is ready to show.
--   model.draw(x, y, w, h)      from paint: replays the last finished frame
--                               for this box; draws nothing until there is one.
--
-- Ethos stops a callback after 20000 Lua instructions, so the work is split
-- as WingFlight's plane3d.lua splits it: paint computes nothing, every step
-- stays a few thousand instructions, and the finished frame is a list of
-- screen triangles that only the last step writes (paint never sees half a
-- frame).
--
-- Body axes: x forward (nose +), y left, z up (right-handed). The camera
-- stands on the left, so the nose points left on the screen as in the photos,
-- and the tail rotor (on the right) sits behind the fin. The attitude turns
-- the body: roll first (positive lowers the right side), then pitch (positive
-- lowers the nose); both as the Alignment page (app/alignment_visual.lua)
-- shows them. Angles are degrees, as MSP_ATTITUDE gives them.

local model = {}

local sqrt, sin, cos, rad = math.sqrt, math.sin, math.cos, math.rad
local floor, min = math.floor, math.min
local tsort = table.sort

local CAMERA_DIST = 7.0
local AMBIENT, DIFFUSE, LEVELS = 0.45, 0.65, 8
local MAT_BODY, MAT_SURFACE, MAT_WHITE, MAT_CANOPY, MAT_PROP = 1, 2, 3, 4, 5

-- Colours by material: body, surfaces, gear, canopy, blades. The body is the
-- blue of the Rotorflight logo (#007CC7), the canopy smoked glass; the rest
-- and the light are WingFlight's (its app/plane3d.lua).
local PALETTE = {
  dark = {{0, 124, 199}, {78, 80, 88}, {235, 235, 230}, {120, 126, 138}, {160, 160, 165}},
  light = {{0, 124, 199}, {45, 45, 52}, {215, 215, 210}, {70, 76, 88}, {120, 120, 125}},
}

-- Work per step of a frame: points projected, faces shaded.
local POINT_STEP, FACE_STEP = 60, 50

local function norm3(x, y, z)
  local l = sqrt(x * x + y * y + z * z)
  return x / l, y / l, z / l
end
-- The screen axes in body coordinates: towards the camera (C), right (R), up (U).
local CX, CY, CZ = norm3(-0.35, 0.85, 0.40)
local RX, RY = norm3(-CY, CX, 0)
local UX, UY, UZ = norm3(-RY * CZ, RX * CZ, -RX * CY + RY * CX)
-- The light, fixed on the screen: above, to the left and towards the viewer.
local LVX, LVY, LVZ = norm3(-0.45, 0.75, 0.50)

---------------------------------------------------------------------------
-- Mesh: points, then faces (up to four points; d = 0 for a triangle). A face
-- is a plate (seen from both sides) or one side of a closed part (hidden when
-- it turns away). Normals are unit vectors in body axes.
---------------------------------------------------------------------------

local MX, MY, MZ = {}, {}, {}
local FA, FB, FC, FD, FMAT, FPLATE = {}, {}, {}, {}, {}, {}
local FNX, FNY, FNZ = {}, {}, {}
local nV, nF = 0, 0

local function vtx(x, y, z)
  nV = nV + 1
  MX[nV], MY[nV], MZ[nV] = x, y, z
  return nV
end

local IDS = {}
-- Newell's normal of a face, turned away from the point (ix, iy, iz) for a
-- closed part (the inside of that part).
local function addFace(a, b, c, d, mat, plate, ix, iy, iz)
  local n = (d == 0) and 3 or 4
  IDS[1], IDS[2], IDS[3], IDS[4] = a, b, c, d
  local nx, ny, nz, cx, cy, cz = 0, 0, 0, 0, 0, 0
  for i = 1, n do
    local p, q = IDS[i], IDS[i % n + 1]
    nx = nx + (MY[p] - MY[q]) * (MZ[p] + MZ[q])
    ny = ny + (MZ[p] - MZ[q]) * (MX[p] + MX[q])
    nz = nz + (MX[p] - MX[q]) * (MY[p] + MY[q])
    cx, cy, cz = cx + MX[p], cy + MY[p], cz + MZ[p]
  end
  cx, cy, cz = cx / n, cy / n, cz / n
  local l = sqrt(nx * nx + ny * ny + nz * nz)
  if l > 0 then nx, ny, nz = nx / l, ny / l, nz / l end
  if not plate and nx * (cx - ix) + ny * (cy - iy) + nz * (cz - iz) < 0 then
    nx, ny, nz = -nx, -ny, -nz
  end
  nF = nF + 1
  FA[nF], FB[nF], FC[nF], FD[nF] = a, b, c, d
  FMAT[nF], FPLATE[nF] = mat, plate
  FNX[nF], FNY[nF], FNZ[nF] = nx, ny, nz
end

-- A closed box, six faces.
local function addBox(x0, x1, y0, y1, z0, z1, mat)
  local a, b = vtx(x0, y0, z0), vtx(x0, y1, z0)
  local c, d = vtx(x0, y1, z1), vtx(x0, y0, z1)
  local e, f = vtx(x1, y0, z0), vtx(x1, y1, z0)
  local g, h = vtx(x1, y1, z1), vtx(x1, y0, z1)
  local ix, iy, iz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
  addFace(a, b, c, d, mat, false, ix, iy, iz)
  addFace(e, h, g, f, mat, false, ix, iy, iz)
  addFace(a, e, h, d, mat, false, ix, iy, iz)
  addFace(b, c, g, f, mat, false, ix, iy, iz)
  addFace(a, e, f, b, mat, false, ix, iy, iz)
  addFace(d, c, g, h, mat, false, ix, iy, iz)
end

-- Fuselage and tail in one: rings of eight points, nose to tail. Each
-- station is {x, z of the centre, half width, height above the centre,
-- below it}: a round cabin that tapers into the tail boom.
local SIDES = 8
local COS_T = {1, 0.70711, 0, -0.70711, -1, -0.70711, 0, 0.70711}
local SIN_T = {0, 0.70711, 1, 0.70711, 0, -0.70711, -1, -0.70711}
local STATIONS = {
  {1.25, 0.62, 0.10, 0.12, 0.12},
  {1.10, 0.66, 0.38, 0.40, 0.36},
  {0.80, 0.70, 0.55, 0.58, 0.48},
  {0.30, 0.72, 0.62, 0.66, 0.52},
  {-0.25, 0.74, 0.58, 0.60, 0.50},
  {-0.75, 0.80, 0.42, 0.44, 0.36},
  {-1.25, 0.88, 0.24, 0.24, 0.20},
  {-1.90, 0.96, 0.13, 0.13, 0.11},
  {-2.55, 1.02, 0.08, 0.08, 0.07},
}
local RING = {}

-- Glass: the upper front half of the cabin, down to just below its middle line.
local function isGlass(xm, k, k2)
  return xm > 0.0 and (SIN_T[k] + SIN_T[k2]) > -0.3
end

local function buildRings()
  for s = 1, #STATIONS do
    local st = STATIONS[s]
    RING[s] = nV + 1
    for k = 1, SIDES do
      local sn = SIN_T[k]
      vtx(st[1], st[3] * COS_T[k], st[2] + (sn >= 0 and st[4] or st[5]) * sn)
    end
  end
end

-- The side faces from station `from` to station `to` + 1.
local function buildSegments(from, to)
  for s = from, to do
    local a, b = STATIONS[s], STATIONS[s + 1]
    local xm, zm = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
    for k = 1, SIDES do
      local k2 = k % SIDES + 1
      local p1, p2 = RING[s] + k - 1, RING[s] + k2 - 1
      local q1, q2 = RING[s + 1] + k - 1, RING[s + 1] + k2 - 1
      addFace(p1, p2, q2, q1, isGlass(xm, k, k2) and MAT_CANOPY or MAT_BODY, false, xm, 0, zm)
    end
  end
end

-- Nose and tail ends, fans to a point.
local function buildEnds()
  local last = #STATIONS
  local first, tailSt = STATIONS[1], STATIONS[last]
  local nose = vtx(first[1] + 0.07, 0, first[2])
  local tail = vtx(tailSt[1] - 0.07, 0, tailSt[2])
  for k = 1, SIDES do
    local k2 = k % SIDES + 1
    addFace(nose, RING[1] + k - 1, RING[1] + k2 - 1, 0,
      isGlass(first[1], k, k2) and MAT_CANOPY or MAT_BODY, false, 0, 0, 0.75)
    addFace(tail, RING[last] + k2 - 1, RING[last] + k - 1, 0, MAT_BODY, false, -1.5, 0, 0.9)
  end
end

-- Mast, head and the first blade (broad, with some thickness, so it shows
-- edge on too).
local function buildRotorA()
  addBox(-0.05, 0.05, -0.05, 0.05, 1.30, 1.52, MAT_SURFACE)
  addBox(-0.15, 0.15, -0.15, 0.15, 1.50, 1.64, MAT_SURFACE)
  addBox(0.14, 2.25, -0.11, 0.11, 1.55, 1.61, MAT_PROP)
end

-- A closed prism: a flat shape in the x-z plane (three or four corners
-- {x, z}, in order), from y0 to y1.
local function addPrism(pts, y0, y1, mat)
  local n = #pts
  local lo, hi = {}, {}
  local ix, iz = 0, 0
  for i = 1, n do
    lo[i] = vtx(pts[i][1], y0, pts[i][2])
    hi[i] = vtx(pts[i][1], y1, pts[i][2])
    ix, iz = ix + pts[i][1], iz + pts[i][2]
  end
  ix, iz = ix / n, iz / n
  local iy = (y0 + y1) / 2
  addFace(lo[1], lo[2], lo[3], lo[4] or 0, mat, false, ix, iy, iz)
  addFace(hi[1], hi[2], hi[3], hi[4] or 0, mat, false, ix, iy, iz)
  for i = 1, n do
    local j = i % n + 1
    addFace(lo[i], lo[j], hi[j], hi[i], mat, false, ix, iy, iz)
  end
end

-- A blade from (x1, z1) to (x2, z2) in the x-z plane, half width hw, from
-- y0 to y1.
local function addBlade(x1, z1, x2, z2, hw, y0, y1, mat)
  local dx, dz = x2 - x1, z2 - z1
  local l = sqrt(dx * dx + dz * dz)
  local nx, nz = -dz / l * hw, dx / l * hw
  addPrism({{x1 + nx, z1 + nz}, {x2 + nx, z2 + nz}, {x2 - nx, z2 - nz}, {x1 - nx, z1 - nz}}, y0, y1, mat)
end

-- The second blade, the horizontal stabiliser (on the boom, ahead of the
-- fin) and the fin: a triangle swept back, its foot in the boom.
local function buildRotorB()
  addBox(-2.25, -0.14, -0.11, 0.11, 1.55, 1.61, MAT_PROP)
  addBox(-2.18, -1.96, -0.34, 0.34, 1.00, 1.04, MAT_SURFACE)
  addPrism({{-2.10, 1.04}, {-2.64, 1.04}, {-2.70, 1.68}}, -0.03, 0.03, MAT_SURFACE)
end

-- The tail rotor: two blades and a hub, on the right (y < 0), beside the
-- boom and behind the fin.
local function buildTailRotor()
  addBlade(-2.20, 1.50, -2.80, 0.86, 0.04, -0.13, -0.09, MAT_PROP)
  addBox(-2.54, -2.46, -0.15, -0.07, 1.14, 1.22, MAT_SURFACE)
end

-- One side's skid (low under the body, its front turned up) and its two
-- short struts (s = 1: left, -1: right).
local function buildSkid(s)
  addBox(-0.70, 0.80, s * 0.40, s * 0.49, -0.10, -0.03, MAT_WHITE)
  addBox(0.80, 0.90, s * 0.40, s * 0.49, -0.10, 0.06, MAT_WHITE)
  addBox(0.375, 0.465, s * 0.38, s * 0.46, -0.03, 0.36, MAT_WHITE)
  addBox(-0.425, -0.335, s * 0.38, s * 0.46, -0.03, 0.40, MAT_WHITE)
end

-- One build step per call; each stays a few thousand instructions.
local BUILD = {
  buildRings,
  function() buildSegments(1, 3) end,
  function() buildSegments(4, 6) end,
  function() buildSegments(7, 8) end,
  buildEnds,
  buildRotorA,
  buildRotorB,
  buildTailRotor,
  function() buildSkid(1) end,
  function() buildSkid(-1) end,
}

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

-- Per point, this frame: depth, and the screen position.
local VZ, SXA, SYA = {}, {}, {}
-- Per face, this frame: its colour; and the visible faces as depth keys
-- (depth band * 1024 + face index), sorted far to near.
local FCOL = {}
local ORDER = {}
local orderCount, ordMax = 0, 0
-- The display list the last frame made: screen triangles and their colours.
local LX1, LY1, LX2, LY2, LX3, LY3, LCOL = {}, {}, {}, {}, {}, {}, {}
local listCount = 0

-- The rotation from body to view axes, for the frame being made.
local m11, m12, m13, m21, m22, m23, m31, m32, m33 = 1, 0, 0, 0, 1, 0, 0, 0, 1

-- The fixed fit, in model units: the helicopter turned up to 30 degrees each
-- way in roll and pitch (5-degree steps), so the scale never changes between
-- frames. Measured from the model's own triangles; measure again after
-- changing the camera or the model.
local FIT_MINX, FIT_MAXX, FIT_MINY, FIT_MAXY = -2.7515, 3.5725, -3.0694, 1.4316

local built = 0
local phase, cursor = 0, 1                         -- 0 idle, 1 points, 2 faces, 3 list
local wx, wy, ww, wh = nil, nil, nil, nil          -- the box paint last asked for
local pRoll, pPitch, pDark = 0, 0, false           -- the frame being made
local pX, pY, pW, pH = 0, 0, 0, 0
local pal, scale, ox, oy = nil, 1, 0, 0
local frameReady = false
local fRoll, fPitch, fDark = 0, 0, false           -- the finished frame
local fX, fY, fW, fH = 0, 0, 0, 0

local shadeCache = {}
-- The shades of each material: LEVELS steps from the ambient to the full light.
local function shadeFor(dark)
  local key = dark and 1 or 2
  local t = shadeCache[key]
  if t then return t end
  local palette = dark and PALETTE.dark or PALETTE.light
  t = {}
  for mat = 1, #palette do
    local c = palette[mat]
    local row = {}
    for i = 1, LEVELS do
      local s = AMBIENT + DIFFUSE * (i - 1) / (LEVELS - 1)
      row[i] = lcd.RGB(min(255, floor(c[1] * s)), min(255, floor(c[2] * s)), min(255, floor(c[3] * s)))
    end
    t[mat] = row
  end
  shadeCache[key] = t
  return t
end

-- A frame's start: the rotation for its attitude, its colours and its fit.
local function startFrame()
  -- y is left: a positive roll lowers the right side, so it turns +y up.
  local r, p = rad(-pRoll), rad(pPitch)
  local cr, sr, cp, sp = cos(r), sin(r), cos(p), sin(p)
  -- The screen axes times the body's turn: first the pitch (B * P), then the roll (* Rl).
  local a11, a12, a13 = RX * cp, RY, RX * sp
  local a21, a22, a23 = UX * cp - UZ * sp, UY, UX * sp + UZ * cp
  local a31, a32, a33 = CX * cp - CZ * sp, CY, CX * sp + CZ * cp
  m11, m12, m13 = a11, a12 * cr - a13 * sr, a12 * sr + a13 * cr
  m21, m22, m23 = a21, a22 * cr - a23 * sr, a22 * sr + a23 * cr
  m31, m32, m33 = a31, a32 * cr - a33 * sr, a32 * sr + a33 * cr
  pal = shadeFor(pDark)
  scale = min((pW - 12) / (FIT_MAXX - FIT_MINX), (pH - 6) / (FIT_MAXY - FIT_MINY))
  ox = pX + pW / 2 - scale * (FIT_MINX + FIT_MAXX) / 2 + 0.5
  oy = pY + pH / 2 - scale * (FIT_MINY + FIT_MAXY) / 2 + 0.5
  orderCount = 0
end

-- Points from..to into view and onto the screen (perspective; y down).
local function projectPoints(from, to)
  for i = from, to do
    local x, y, z = MX[i], MY[i], MZ[i]
    local vx = m11 * x + m12 * y + m13 * z
    local vy = m21 * x + m22 * y + m23 * z
    local vz = m31 * x + m32 * y + m33 * z
    local f = CAMERA_DIST / (CAMERA_DIST - vz)
    VZ[i] = vz
    SXA[i] = floor(ox + scale * vx * f)
    SYA[i] = floor(oy - scale * vy * f)
  end
end

-- Faces from..to: which show, how lit, and their depth key.
local function shadeFaces(from, to)
  for f = from, to do
    local nx, ny, nz = FNX[f], FNY[f], FNZ[f]
    local vz = m31 * nx + m32 * ny + m33 * nz
    local plate = FPLATE[f]
    if plate or vz > 0 then
      local vx = m11 * nx + m12 * ny + m13 * nz
      local vy = m21 * nx + m22 * ny + m23 * nz
      local lit = vx * LVX + vy * LVY + vz * LVZ
      if plate then
        if lit < 0 then lit = -lit end
      elseif lit < 0 then
        lit = 0
      end
      local a, b, c, d = FA[f], FB[f], FC[f], FD[f]
      local depth
      if d == 0 then
        depth = (VZ[a] + VZ[b] + VZ[c]) / 3
      else
        depth = (VZ[a] + VZ[b] + VZ[c] + VZ[d]) / 4
      end
      orderCount = orderCount + 1
      ORDER[orderCount] = floor((depth + 4) * 1000) * 1024 + f
      FCOL[f] = pal[FMAT[f]][floor(lit * (LEVELS - 1) + 0.5) + 1]
    end
  end
end

local function addTriangle(x1, y1, x2, y2, x3, y3, col)
  local n = listCount + 1
  listCount = n
  LX1[n], LY1[n], LX2[n], LY2[n], LX3[n], LY3[n], LCOL[n] = x1, y1, x2, y2, x3, y3, col
end

-- The last step: sort (a plain numeric sort, no Lua comparator), then write
-- the display list in one go.
local function listFrame()
  for i = orderCount + 1, ordMax do ORDER[i] = nil end
  ordMax = orderCount
  tsort(ORDER)
  listCount = 0
  for k = 1, orderCount do
    local f = ORDER[k] % 1024
    local a, b, c, d = FA[f], FB[f], FC[f], FD[f]
    local col = FCOL[f]
    addTriangle(SXA[a], SYA[a], SXA[b], SYA[b], SXA[c], SYA[c], col)
    if d ~= 0 then addTriangle(SXA[a], SYA[a], SXA[c], SYA[c], SXA[d], SYA[d], col) end
  end
end

---------------------------------------------------------------------------
-- The public calls
---------------------------------------------------------------------------

-- From wakeup: one step of work. The mesh first, then a frame for the
-- attitude, once paint has asked for a box.
function model.service(roll, pitch)
  if not wx then return false end
  if built < #BUILD then
    built = built + 1
    BUILD[built]()
    return false
  end
  if phase == 0 then
    local dark = lcd.darkMode() and true or false
    if frameReady and roll == fRoll and pitch == fPitch and dark == fDark
        and wx == fX and wy == fY and ww == fW and wh == fH then
      return false
    end
    pRoll, pPitch, pDark = roll, pitch, dark
    pX, pY, pW, pH = wx, wy, ww, wh
    startFrame()
    phase, cursor = 1, 1
  end
  if phase == 1 then
    local to = min(cursor + POINT_STEP - 1, nV)
    projectPoints(cursor, to)
    if to < nV then cursor = to + 1 else phase, cursor = 2, 1 end
    return false
  end
  if phase == 2 then
    local to = min(cursor + FACE_STEP - 1, nF)
    shadeFaces(cursor, to)
    if to < nF then cursor = to + 1 else phase = 3 end
    return false
  end
  listFrame()
  phase = 0
  frameReady = true
  fRoll, fPitch, fDark = pRoll, pPitch, pDark
  fX, fY, fW, fH = pX, pY, pW, pH
  return true
end

-- From paint: replay the finished frame if it is for this box and theme.
function model.draw(x, y, w, h)
  wx, wy, ww, wh = x, y, w, h
  if not frameReady or x ~= fX or y ~= fY or w ~= fW or h ~= fH then return end
  if (lcd.darkMode() and true or false) ~= fDark then return end
  local last = nil
  for i = 1, listCount do
    local col = LCOL[i]
    if col ~= last then
      lcd.color(col)
      last = col
    end
    lcd.drawFilledTriangle(LX1[i], LY1[i], LX2[i], LY2[i], LX3[i], LY3[i])
  end
end

return model
