-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Source-format field art, consumed by native actors/effects. Animation clocks,
-- collision, fishing results and field-move ownership stay with native gameplay.
local Assets = require('src.render.Assets')
local Version = require('src.core.GameVersion')
local M = {}
local ORDER = {'shock','question','happy','sad','heart','bolt','sleep','fish'}
local KEYS = {'shock','question','happy','sad','heart','bolt','sleep','fish',
  'grassRustle','jumpShadow','cutGrass','fishing','fishingFemale'}
local DIRECTIONS = {{-1,-1},{1,-1},{-1,1},{1,1}}
local caches = setmetatable({}, {__mode='k'})
local function reset() caches = setmetatable({}, {__mode='k'}) end
Assets.register{invalidate=reset,release=reset}
local function state(data)
  if not Version.isGen2() then return end
  local rows = data and data.field and data.field.emotes
  if type(rows) ~= 'table' then return end
  local held = caches[data]
  local order = rows.order or ORDER
  local unchanged = held and #held.order == #order
  if unchanged then
    for _,key in ipairs(KEYS) do if held.inputs[key] ~= rows[key] then unchanged=false;break end end
    if unchanged then
      for i,key in ipairs(order) do if held.order[i] ~= key then unchanged=false;break end end
    end
  end
  if unchanged then return held end
  held = {images={},paths={},inputs={},quads={},order={}}
  caches[data] = held
  for i,key in ipairs(order) do held.order[i] = key end
  for _,key in ipairs(KEYS) do
    local path = rows[key]
    held.inputs[key] = path
    if type(path) == 'string' and path ~= '' then
      local ok,image = pcall(Assets.image,path)
      if ok and image then held.images[key],held.paths[key] = image,path
      else require('src.core.Logger').warn('gen2 field art %s unavailable: %s',key,tostring(path)) end
    end
  end
  return held
end
function M.sync(world,data)
  local held = state(data)
  if held and world._nativeEmoteArt ~= held then
    world.emoteOrder,world.emoteImages = {},{}
    for i,key in ipairs(held.order) do world.emoteOrder[i]=key end
    for key,image in pairs(held.images) do world.emoteImages[key]=image end
    world.grassRustleImage,world.jumpShadowImage = held.images.grassRustle,held.images.jumpShadow
    world.cutGrassImage = held.images.cutGrass
    world.fishingSheet,world.fishingSheetFemale = held.paths.fishing,held.paths.fishingFemale
  elseif not held and world._nativeEmoteArt then
    world.emoteOrder,world.emoteImages,world.grassRustleImage,world.jumpShadowImage = nil,nil,nil,nil
    world.cutGrassImage,world.fishingSheet,world.fishingSheetFemale = nil,nil,nil
  end
  world._nativeEmoteArt = held
  return held
end
function M.emote(world,data,bubble)
  local held = M.sync(world,data)
  if not held then return end
  local key = type(bubble)=='string' and bubble or world.emoteOrder[bubble or 1]
  return world.emoteImages[key]
end
function M.token(data) return state(data) end
function M.fishing(data,gender)
  local held = state(data)
  if not held then return end
  local female = gender=='girl' or gender=='female' or gender==1
  local path = female and held.paths.fishingFemale or held.paths.fishing
  if path then return {down=path,up=path,left=path,right=path},
    {down={0,0,16,8},up={0,8,16,8},left={0,16,16,8},right={0,16,16,8}},held end
  return nil,nil,held
end
function M.shadow(data,actor,cx,cy)
  local held = state(data)
  local image = held and held.images.jumpShadow
  if not image then return false end
  local x = math.floor(actor.px-cx)
  -- A GSC shadow is one horizontal OBJ pair, not Gen1's mirrored 2x2 blob.
  local y=math.floor(actor.py-cy)+((actor.facing=='left' or actor.facing=='right') and 8 or 10)
  love.graphics.draw(image,x,y);love.graphics.draw(image,x+16,y,0,-1,1)
  return true
end
function M.grass(world,data,actor,cx,cy)
  local held = M.sync(world,data)
  local image = held and world.grassRustleImage
  if not (image and actor.moving) then return false end
  local grass = actor.grassShake
  if grass == nil and world.map and world.map.isGrassCell and actor.cellX then
    grass = world.map:isGrassCell(actor.cellX,actor.cellY)
      or actor.targetX and world.map:isGrassCell(actor.targetX,actor.targetY)
  end
  if not grass then return false end
  local progress = actor.progress or 0
  if progress >= (actor.stepFrames or 16) then return false end
  local shift = progress%8>=4 and 1 or 0
  local x,y = math.floor(actor.px-cx),math.floor(actor.py-cy)+4+shift
  love.graphics.draw(image,x-shift,y)
  love.graphics.draw(image,x+16+shift,y,0,-1,1)
  return true
end
function M.cut(world,data,animation,cam)
  local held = M.sync(world,data)
  local image = held and world.cutGrassImage
  if not image then return false end
  local iw,ih = image:getDimensions()
  if iw<32 or ih<8 then return false end
  local age = 32-animation.frames
  local frame = math.floor(age/8)%4
  held.quads[frame] = held.quads[frame] or love.graphics.newQuad(frame*8,0,8,8,iw,ih)
  local radius = math.floor(age/3)
  local x,y=animation.x*16-cam.x+4,animation.y*16-cam.y+4
  for _,dir in ipairs(DIRECTIONS) do
    love.graphics.draw(image,held.quads[frame],x+dir[1]*radius,y+dir[2]*radius)
  end
  return true
end
return M
