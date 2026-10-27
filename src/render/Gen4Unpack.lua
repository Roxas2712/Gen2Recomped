-- Vertex decoding extracted from Gen4Model; existing source notices apply.
-- Copyright (c) 2026 Cedric. See LICENSE.md.
-- No graphics objects are created here. The live shape/record options retain
-- callback-visible edits on the synchronous model path.
local M={}
local VERTEX_BYTES,LEGACY_VERTEX_BYTES,FX16,UV_UNITS=16,14,4096,16
local G4_JOINTS=16
local GRASS_MATERIALS={nectgr=true,s_grass=true}
-- A vertex that is not part of a card. Shared rather than built per vertex,
-- because most of Sinnoh is not a tree.
local NO_PIVOT = { 0, 0, 0 }

-- G1 -- THE VERTICES AS ONE BUFFER, NOT ONE TABLE EACH.
--
-- A chunk has 1,500-3,200 vertices and a map change decodes dozens of chunks
-- plus every prop; each vertex became a fifteen-element Lua table that
-- newMesh then read back one field at a time.  With the FFI the same floats
-- go straight into a ByteData laid out as FORMAT says, and newMesh takes the
-- buffer whole.  Shapes a joint animation re-poses on the CPU keep the
-- tables (setVertex reads them back); everything else -- which is nearly
-- everything -- takes the buffer.  Performance.gen4ByteVertices = false, or
-- a runtime without the FFI, keeps the tables for every shape.
local ffiOk, ffi = pcall(require, "ffi")
if not ffiOk then ffi = nil end
local function packedVertices(count, enabled, width)
  if not (ffi and enabled and love and love.data and love.data.newByteData) then
    return nil
  end
  local ok, data = pcall(love.data.newByteData, count * width * 4)
  if not ok or not data or not data.getFFIPointer then return nil end
  local okPtr, ptr = pcall(data.getFFIPointer, data)
  if not okPtr or ptr == nil then return nil end
  return data, ffi.cast("float *", ptr)
end

-- WHICH FACES THE CARTRIDGE AUTHORED TO FACE THE CAMERA.
--
-- Platinum builds a tree as a flat quad leaning back toward its fixed camera,
-- and that lean is a single exact normal: (0, 0.819, 0.575).  Measured over
-- the whole cartridge it appears on `tree01`, `tree2_01`, `tree04_2`,
-- `conttree_b/t`, `conttree2_b/t`, `tree3_02`, `bf_tree03` and nothing else --
-- 60,273 triangles across 45 materials.  Walls are (1,0,0) or (0,0,1), the
-- ground is (0,1,0), and `searock` and `imped` lean at a DIFFERENT 45 degrees,
-- so none of them are caught.
--
-- Two simpler rules were tried and thrown away.  "Taller than it is flat"
-- catches every dungeon wall and step.  "Made only of 4-vertex quads" is
-- better -- a tree shape really is 56 to 240 loose quads while a wall is 6-
-- and 8-vertex boxes -- but the FLAT quads are the sea, the lakes and the
-- grass floor, and standing those on end would take the world apart.
--
-- The normal is computed from the geometry rather than read from the vertex,
-- because a cache imported before normals were carried is 14 bytes a vertex
-- and has none.  The lighting pass measured the same normal independently off
-- a 16-byte cache, which is a second source for it.
local TREE_NY, TREE_NZ, TREE_TOL = 0.819, 0.575, 0.04

-- billboardPivots(shape, positions, count) -> per-vertex pivot, card count
--
-- Each card gets its OWN centre, found by walking the shape's triangles as a
-- graph: a card is one connected component, and every one of them is exactly
-- four vertices.
-- HOW MANY TIMES A CARD REPEATS ITS TEXTURE ACROSS ITS WIDTH, above which it
-- is a CONTINUOUS STRIP and not a tree.
--
-- Reported from play, twice: *"the border trees ... rotating as a large group
-- of trees instead of individually above their trunks"*, and again after the
-- pivot was moved to the base -- *"many groups of trees canopys are still
-- pivoting as if theyre rows rather than from the trunk of every tree"*.
--
-- The second report is not a pivot fault.  Measured: 100% of card components
-- are exactly one quad, so nothing is being merged.  What IS happening is that
-- Platinum draws a forest border as ONE CARD -- `conttree` is *continuous*
-- tree -- 256 world units wide and 20 tall, repeating a 64-pixel texture four
-- times.  All 2,956 `conttree_t` cards and all 3,738 `conttree2_t` cards are
-- wider than 48 units; the widest are 256.  A quad cannot bend, so there is no
-- pivot that turns those four trees individually: the geometry for them does
-- not exist.
--
-- SUBDIVIDING THEM WAS TRIED AND ABANDONED.  Splitting a strip at its texture
-- tiles needs the repeat count to be a whole number, and across the cartridge
-- **23,171 of 30,147 cards have a non-integer u-span over texture width** --
-- the UVs address sub-rectangles, not whole tiles. There is no derivable place
-- to cut, and cutting at a guessed one would break a strip into panels that
-- swing apart at the seams.
--
-- So a strip is left exactly as the cartridge drew it, which is what it was
-- authored for, and only cards that really are one tree turn to face you.
-- 1.5 rather than 2 so a card that repeats "about twice" is treated as the
-- strip it is.
-- 1.25, NOT 1.5, AND THE DIFFERENCE IS THE WHOLE OF REPORT #188.
--
-- Reported from play a third time: *"some of the trees are pivoting together
-- for example 3 trees are pivoting from one point"*.
--
-- Measured over all 666 chunks of the cartridge, u-span divided by texture
-- width lands on clean values -- and 2,396 components sit at EXACTLY 1.50:
--
--     0.66 x6328   0.53 x6279   0.34 x6272     <- single trees
--     4.00 x3534 (excluded)   2.50 x1187 (excluded)   2.00 x1159 (excluded)
--     1.50 x2396   <- ON the old threshold, and the test is `>`, so KEPT
--     1.00 x2250   <- a single tree, correctly kept
--
-- A strict `>` against 1.5 lets every one of those 2,396 through, and at a
-- 64-wide texture that component is 96 world units across: THREE 32-unit
-- trees turning about one pivot, which is the report word for word.
--
-- 1.25 rather than 1.4 or 1.49 because it is the MIDDLE OF A MEASURED GAP:
-- 21,758 components are at or under 1.00 repeats, 2,396 are at 1.50, and
-- only EIGHTEEN of 30,147 lie strictly between the two.  A threshold in an
-- empty gap cannot be knocked over by float wobble in the s16 divide, which
-- is exactly what setting it on 1.5 and testing with `>=` would risk.
local STRIP_REPEATS = 1.25

-- ...AND A `conttree` IS NEVER ONE TREE, WHICH THE CARTRIDGE SAYS IN THE NAME.
--
-- `conttree` is CONTINUOUS tree.  The u-span test is a proxy -- it reads the
-- texture's repeat, not the quad's size -- and it misses the strips whose UVs
-- are stretched rather than tiled.  The name does not miss them, and the
-- separation is total:
--
--     conttree* components   n=10,217  min width 64.0  median 128  max 256
--                            AT OR UNDER 40 UNITS: ZERO
--     every other component  n=19,930  median 33      98.3% at or under 40
--
-- The narrowest `conttree` in the game is 64 units, which is already two
-- trees; an ordinary tree card is 33.  There is no overlap to argue about.
--
-- Effect, measured: billboarded cards wider than 48 units fall from 4,493
-- (18.6% of all cards) to 51 (0.3%), and the widest from 96.0 to 85.3.  The
-- name rule alone does most of it -- 18.6% to 0.4% -- and the threshold trims
-- the rest.
local function isContinuousStrip(shape)
  local name = shape and shape.texture
  return type(name) == "string" and name:find("conttree", 1, true) ~= nil
end

local function billboardPivots(shape, positions, count, textureWidth)
  local parent = {}
  for i = 1, count do parent[i] = i end
  local function find(a)
    while parent[a] ~= a do parent[a] = parent[parent[a]]; a = parent[a] end
    return a
  end
  local function union(a, b)
    a, b = find(a), find(b)
    if a ~= b then parent[a] = b end
  end

  local card = {}
  local indices = shape.indices or ""
  for t = 0, (shape.triangleCount or 0) - 1 do
    local at = t * 6
    local a1, a2, b1, b2, c1, c2 = indices:byte(at + 1, at + 6)
    if not c2 then break end
    local a = a1 + a2 * 256 + 1
    local b = b1 + b2 * 256 + 1
    local cc = c1 + c2 * 256 + 1
    local pa, pb, pc = positions[a], positions[b], positions[cc]
    if pa and pb and pc then
      union(a, b)
      union(b, cc)
      local ux, uy, uz = pb[1] - pa[1], pb[2] - pa[2], pb[3] - pa[3]
      local vx, vy, vz = pc[1] - pa[1], pc[2] - pa[2], pc[3] - pa[3]
      local nx = uy * vz - uz * vy
      local ny = uz * vx - ux * vz
      local nz = ux * vy - uy * vx
      local len = math.sqrt(nx * nx + ny * ny + nz * nz)
      if len > 1e-6 then
        nx, ny, nz = nx / len, ny / len, nz / len
        -- The winding decides the sign and both windings occur, so the test is
        -- made on the upward-pointing form of the normal.
        if ny < 0 then nx, ny, nz = -nx, -ny, -nz end
        if math.abs(nx) < TREE_TOL
           and math.abs(ny - TREE_NY) < TREE_TOL
           and math.abs(math.abs(nz) - TREE_NZ) < TREE_TOL then
          card[a], card[b], card[cc] = true, true, true
        end
      end
    end
  end

  -- A CARD TURNS ABOUT WHERE IT STANDS, not about its middle.
  --
  -- Reported from play, with a screenshot: *"the border trees to the town seem
  -- to be rotating billboards weird as a large group of trees instead of
  -- individually above their trunks"*.
  --
  -- The first version pivoted on the component's CENTROID, and a leaning card's
  -- centroid is not above its base -- the cartridge tilts them 35 degrees back,
  -- so the middle of the quad hangs behind the trunk.  Measured on Twinleaf's
  -- own border: every `conttree_b` card's centroid is 13.9 units behind its
  -- base and every `conttree_t` card's is 9.0 to 12.3.  Turning each about that
  -- point swings it through an arc it never should have left, which reads as
  -- the whole tree line sweeping sideways -- and because the trunk's offset
  -- (13.9) and the canopy's (12.3) DIFFER, the two halves of one tree come
  -- apart as they turn.
  --
  -- So the pivot is the middle of the card's LOWEST edge: the line where it
  -- meets the ground, which is the trunk. A trunk and the canopy above it
  -- share that axis even though they are separate components, so they stay
  -- together.
  -- A CONTINUOUS STRIP IS NOT A TREE -- see `STRIP_REPEATS` above.
  --
  -- Measured per component rather than per shape, because `conttree_b` mixes
  -- single cards with 256-wide strips in the same shape.
  local tw = tonumber(textureWidth)
  if tw and tw > 0 then
    local ulo, uhi = {}, {}
    for i = 1, count do
      if card[i] then
        local r = find(i)
        local u = positions[i][4]
        if u then
          if ulo[r] == nil or u < ulo[r] then ulo[r] = u end
          if uhi[r] == nil or u > uhi[r] then uhi[r] = u end
        end
      end
    end
    local strip = {}
    for r, lo in pairs(ulo) do
      if (uhi[r] - lo) > STRIP_REPEATS * tw then strip[r] = true end
    end
    if next(strip) then
      for i = 1, count do
        if card[i] and strip[find(i)] then card[i] = nil end
      end
    end
  end

  -- OUTSIDE the `tw` block on purpose: the name is readable whether or not the
  -- texture loaded, and a cache with no textures should still not billboard a
  -- forest border as one card.
  if isContinuousStrip(shape) then
    for i = 1, count do card[i] = nil end
  end

  local lowest = {}
  for i = 1, count do
    if card[i] then
      local r = find(i)
      local y = positions[i][2]
      if lowest[r] == nil or y < lowest[r] then lowest[r] = y end
    end
  end
  -- Half a unit: a card's base edge is flat, and the packed coordinates
  -- quantise to about a sixtieth of a unit, so this catches the base and
  -- nothing above it.
  local BASE_BAND = 0.5
  local sumX, sumZ, n = {}, {}, {}
  for i = 1, count do
    if card[i] then
      local r = find(i)
      if positions[i][2] - lowest[r] <= BASE_BAND then
        sumX[r] = (sumX[r] or 0) + positions[i][1]
        sumZ[r] = (sumZ[r] or 0) + positions[i][3]
        n[r] = (n[r] or 0) + 1
      end
    end
  end
  -- A card lying exactly flat has no "lowest edge" to speak of and every
  -- vertex lands in the band, which gives the centroid -- the right answer
  -- for something with no height to lean.
  local cards = 0
  for _ in pairs(n) do cards = cards + 1 end

  local out = {}
  for i = 1, count do
    if card[i] then
      local r = find(i)
      out[i] = { sumX[r] / n[r], sumZ[r] / n[r], 1 }
    else
      out[i] = NO_PIVOT
    end
  end
  return out, cards
end

local function s16(data, at)
  local a, b = data:byte(at + 1, at + 2)
  if not b then return 0 end
  local value = a + b * 256
  if value >= 32768 then value = value - 65536 end
  return value
end

-- One axis of a normal, back out of a signed byte.  Nil past the end of the
-- string, which is how a shorter vertex from an older cache announces itself
-- rather than silently reading into its neighbour.
local function s8(data, at)
  local byte = data:byte(at + 1)
  if not byte then return nil end
  if byte >= 128 then byte = byte - 256 end
  return byte / 127
end


-- unpack(shapeBytes, opts) -> decoded CPU data, with optional packed ByteData.
-- shape/record may be live source tables; their identities are never replaced.
function M.unpack(shapeBytes, opts)
  opts=opts or {}
  local shape=opts.shape or {
    vertices=shapeBytes,indices=opts.indices,vertexCount=opts.vertexCount,
    triangleCount=opts.triangleCount,matrixSlots=opts.matrixSlots,
    texture=opts.texture,unlit=opts.unlit,lightKnown=opts.lightKnown,noFog=opts.noFog,
  }
  local record=opts.record or opts
  local flags=opts.flags or {}
  local modelFlags=opts.modelFlags or opts
  local posScale=opts.posScale or 1
  local tw,th=opts.textureWidth or 1,opts.textureHeight or 1
  local image=opts.hasImage
  local FORMAT_FLOATS=opts.formatFloats or 16
  local cardCount=0
    local count = shape.vertexCount or 0
    local vertices = {}
    -- G4: the joints this shape restores from, densely renumbered, so the
    -- shader indexes a small array rather than the DS's 31-slot stack.  A
    -- shape that needs more than G4_JOINTS distinct slots stays on the CPU.
    local gpuSkin = nil
    if shape.matrixSlots and flags.gen4GpuSkin and count > 0 then
      local slots, byteOf, distinct = {}, {}, 0
      for i = 1, count do
        local slot = shape.matrixSlots:byte(i)
        if slot and not byteOf[slot] then
          distinct = distinct + 1
          if distinct > G4_JOINTS then gpuSkin = false; break end
          byteOf[slot] = distinct - 1
          slots[distinct] = slot
        end
      end
      if gpuSkin == nil and distinct > 0 then gpuSkin = { slots = slots, index = byteOf } end
    end
    if gpuSkin == false then gpuSkin = nil end
    -- G1: the buffer, unless this shape is re-posed per vertex on the CPU
    local packedData, packed
    if count > 0 and (gpuSkin or not shape.matrixSlots) then packedData, packed = packedVertices(count, flags.gen4ByteVertices, FORMAT_FLOATS) end
    -- Kept alongside, because classifying a card needs the whole triangle and
    -- the loop below sees one vertex at a time.
    -- Also collected for the back-wall cap, which needs the face normals to
    -- know whether a back is missing and which wall is a plain side.
    local positions = (record.billboard or record.capBack) and {} or nil
    local grassPending
    local uLo, uHi = math.huge, -math.huge
    -- THE STRIDE THIS CACHE WAS WRITTEN WITH, measured off the record rather
    -- than assumed from the constant.
    --
    -- The vertex grew from 14 bytes to 16 when the normal was added, and a
    -- cache imported before that change is still on disk in every install that
    -- has not re-imported.  Reading a 14-byte buffer at a 16-byte stride does
    -- not fail -- it misaligns EVERY vertex after the first, so the world comes
    -- back as confetti with no error anywhere.  Dividing the buffer by the
    -- vertex count is the one question that has a right answer on both.
    local stride = VERTEX_BYTES
    if count > 0 and shape.vertices then
      local measured = math.floor(#shape.vertices / count)
      if measured == LEGACY_VERTEX_BYTES or measured == VERTEX_BYTES then
        stride = measured
      end
    end
    local lit = (stride >= VERTEX_BYTES)
    -- THE LIGHT, if this caller brought one.  `shade(nx, ny, nz)` answers a
    -- multiplier per channel and is built by `Gen4Shade` from the map's own
    -- area-light template -- which is why it arrives as an argument rather
    -- than being looked up here: this file is handed shapes by the ground
    -- (which knows the map) and by screens that have no map at all, and a
    -- model with no light must keep drawing exactly as it did.
    local shade = record.shade
    -- ...and the map's fog, which paints every shape that has not opted out
    -- (Gen4ModelPack `noFog`) in its colour
    local fog = record.fog
    -- The shape's own box, kept while the vertices are still here.  It is what
    -- `framing` works from: the header states a bounding box too, but it does
    -- not agree with the geometry on two thirds of this cartridge's models, so
    -- the measured one is the one to trust.
    local lo = { math.huge, math.huge, math.huge }
    local hi = { -math.huge, -math.huge, -math.huge }
    -- A CACHE OLDER THAN THE `unlit` FLAG still has lightmapped shapes, and
    -- they are the ones whose vertices carry BAKED COLOURS. Reported from
    -- play: "the indoors of buildings are missing their lighting and appear
    -- dark in platinum". Every shape of the Jubilife Pokemon Center's room
    -- issues COLOR and no NORMAL (vertex colours 132..255), and shaded with
    -- the decoder's resting normal its floor came out at 0.61 x 0.774 of its
    -- texture -- under half. A shape lit by NORMAL commands issues no COLOR,
    -- so its vertices stay pure white: a non-white vertex is the lightmap.
    local unlit = shape.unlit
    -- A CACHE THAT CARRIES THE FLAG says lit by leaving it off (Gen4Ground
    -- sets `lightKnown`): the DS replaces a vertex's colour when a NORMAL
    -- lights it, so whatever colour such a shape packed is not drawn
    local litByNormal = (unlit == nil and shape.lightKnown and not modelFlags.legacyLight) and true or false
    if litByNormal then unlit = false end
    if unlit == nil and shade and lit then
      for i = 0, count - 1 do
        local at = i * stride
        local r, g, b = shape.vertices:byte(at + 11, at + 13)
        if (r and r < 255) or (g and g < 255) or (b and b < 255) then unlit = true; break end
      end
    end
    -- G2: THE LIGHT GOES TO THE SHADER, NOT INTO THE COLOUR.  Exactly the
    -- vertices the CPU path below would multiply get their normal stored
    -- instead; every other vertex stores (0, 0, 0) and the shader leaves it
    -- alone.  The template itself is a uniform (Gen4Model.light), so a new
    -- band no longer rebuilds this mesh.  `legacyLight` keeps the CPU path.
    local gpuLight = flags.gen4GpuLight and shade and lit and not unlit
                     and not modelFlags.legacyLight
    for i = 0, count - 1 do
      local at = i * stride
      local r, g, b = shape.vertices:byte(at + 11, at + 13)
      r, g, b = r or 255, g or 255, b or 255
      if litByNormal and shade and lit then r, g, b = 255, 255, 255 end
      local lnx, lny, lnz = 0, 0, 0
      -- ...not on a shape with no NORMALs (Gen4ModelPack `unlit`):
      -- its vertex colours ARE its lighting
      if shade and lit and not unlit then
        -- The normal, back out of its three signed bytes.  Absent on a cache
        -- imported before the stride changed, and `s8` answers nil there --
        -- which leaves the colour alone rather than multiplying it by a
        -- normal that is really the first two bytes of the next vertex.
        local nx, ny, nz = s8(shape.vertices, at + 13),
                           s8(shape.vertices, at + 14),
                           s8(shape.vertices, at + 15)
        if nx and ny and nz then
          if gpuLight then
            lnx, lny, lnz = nx, ny, nz
          else
            local lr, lg, lb = shade(nx, ny, nz)
            r = r * (lr or 1)
            g = g * (lg or 1)
            b = b * (lb or 1)
          end
        end
      end
      if fog and not shape.noFog then
        r, g, b = (fog[1] or 0) * 255, (fog[2] or 0) * 255, (fog[3] or 0) * 255
        -- a fogged vertex is its fog colour and nothing else
        lnx, lny, lnz = 0, 0, 0
      end
      local x = s16(shape.vertices, at) / FX16 * posScale
      local y = s16(shape.vertices, at + 2) / FX16 * posScale
      local z = s16(shape.vertices, at + 4) / FX16 * posScale
      if x < lo[1] then lo[1] = x end
      if y < lo[2] then lo[2] = y end
      if z < lo[3] then lo[3] = z end
      if x > hi[1] then hi[1] = x end
      if y > hi[2] then hi[2] = y end
      if z > hi[3] then hi[3] = z end
      local u = s16(shape.vertices, at + 6) / UV_UNITS / tw
      local v = s16(shape.vertices, at + 8) / UV_UNITS / th
      local joint = 0
      if gpuSkin then joint = gpuSkin.index[shape.matrixSlots:byte(i + 1)] or 0 end
      if packed then
        local o = i * FORMAT_FLOATS
        packed[o], packed[o + 1], packed[o + 2] = x, y, z
        packed[o + 3], packed[o + 4] = u, v
        packed[o + 5], packed[o + 6], packed[o + 7], packed[o + 8] = r / 255, g / 255, b / 255, 1
        packed[o + 9], packed[o + 10], packed[o + 11] = 0, 0, 0
        packed[o + 12], packed[o + 13], packed[o + 14] = lnx, lny, lnz
        packed[o + 15] = joint
      else
      vertices[i + 1] = {
        x, y, z, u, v,
        -- ...and back to the 0..1 the float attribute wants.
        r / 255, g / 255, b / 255, 1,
        -- filled in below, once the triangles say which vertices are cards
        0, 0, 0,
        -- G2: the normal the shader lights against, or nothing
        lnx, lny, lnz,
        -- G4: the joint, when the shader re-poses this shape
        joint,
      }
      end
      if positions then
        -- the TEXEL coordinate, not the 0..1 one: the strip test compares it
        -- against the texture's own width, so it has to be in texture units.
        local texel = s16(shape.vertices, at + 6) / UV_UNITS
        -- ...AND THE TEXEL V, which the back wall's band needs.  Kept beside
        -- the u rather than derived later because this is the only place the
        -- raw vertex is still in hand.
        positions[i + 1] = { x, y, z, texel,
                             s16(shape.vertices, at + 8) / UV_UNITS }
        if texel < uLo then uLo = texel end
        if texel > uHi then uHi = texel end
      end
    end

    -- WHICH OF THESE ARE CARDS, and where each one turns.
    --
    -- Only when the caller asked: `record.billboard` is set for terrain chunks
    -- and NOT for buildings, and that is measured rather than tidy.  Run over
    -- `build_model.narc` the same classifier catches 184 triangles -- a school
    -- roof, a fountain, a shop front -- that happen to sit at the tree's lean
    -- and would then swing to face the camera.  The cartridge's trees live in
    -- the terrain, so that is where the rule is allowed to apply.
    if positions then
      -- ONLY WHEN THE TEXTURE REALLY LOADED.  `tw` falls back to 1, and a
      -- width of 1 would make the strip test reject every card with a u span
      -- over 1.5 texels -- which is all of them.  Passing nil there skips the
      -- test and billboards on the geometry alone, which is what a cache with
      -- no textures should do rather than silently doing nothing.
      local pivots, cards =
        billboardPivots(shape, positions, count, image and tw or nil)
      if cards > 0 then
        for i = 1, count do
          local pv = pivots[i]
          if packed then
            local o = (i - 1) * FORMAT_FLOATS
            packed[o + 9], packed[o + 10], packed[o + 11] = pv[1], pv[2], pv[3]
          else
            local v = vertices[i]
            v[10], v[11], v[12] = pv[1], pv[2], pv[3]
          end
        end
        cardCount = cards
      end
      -- ...AND THE GRASS STANDS UP, where the material says a wild Pokemon
      -- lives in it.  The flat quad stays: from the cartridge's own camera the
      -- card is edge-on and what you see is still the ground tile.
      if record.tileUnits and record.tileUnits > 0
         and GRASS_MATERIALS[tostring(shape.texture or "")] then
        grassPending = { shape = shape, positions = positions }
      end
    end

  return {count=count,vertices=vertices,packedData=packedData,packed=packed,
    positions=positions,lo=lo,hi=hi,gpuSkin=gpuSkin,stride=stride,
    uLo=uLo,uHi=uHi,cards=cardCount,grassPending=grassPending}
end
return M
