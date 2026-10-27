-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Translate rendering leaves of native tilesets. Collision, behaviours,
-- animation timing, map layouts and metatile identifiers stay with the host.
local W={}
function W.compile(own,entry,bytes,english)
 local original=own('@host/addresses/'..entry.game..'_world.lua')
 local localized=own(entry.world);local specs={}
 local function u32(s,off)local a,b,c,d=s:byte(off+1,off+4);assert(d);return a+b*256+c*65536+d*16777216 end
 for pair,row in pairs(original.pairs)do
  local target=assert(localized.pairs[pair],'Missing localized world pair '..pair)
  for _,kind in ipairs({'primary','secondary'})do
   local a,b=row[kind],target[kind]
   if a and b then
    -- Match the engine's struct by all three independently known pointers.
    local key=table.concat({a.tiles,a.palettes,a.metatiles},':')
    if specs[key]then assert(specs[key].tiles==b.tiles and specs[key].metatiles==b.metatiles,'Ambiguous world pair')else specs[key]=b end
   end
  end
 end
 local R=require('src.import.RomGba');local rom=R.new(bytes)
 local out={}
 for key,spec in pairs(specs)do
  local tiles=spec.compressed and assert(rom:lz77(spec.tiles))or rom:bytes(spec.tiles,512*32)
  if type(tiles)=='table'then local parts={};for i=1,#tiles do parts[i]=string.char(tiles[i])end;tiles=table.concat(parts)end
  local palettes={};for i=0,(spec.palette_count or 16)-1 do palettes[i+1]=R.palette(rom:bytes(spec.palettes+i*32,32))end
  out[key]={tiles=tiles,palettes=palettes,metatiles=bytes:sub(spec.metatiles+1,spec.metatiles+spec.metatile_bytes)}
 end
 return out
end
-- Give the two sign cells their own tiles. A tile used by another metatile
-- or by a host animation is never overwritten, even when it looks blank.
function W.shopSigns(world,addresses,data,english,spec)
 local function key(row)return table.concat({row.tiles,row.palettes,row.metatiles},':')end
 local function word(s,at)return assert(s:byte(at+1))+assert(s:byte(at+2))*256 end
 local primaries={};for pair,row in pairs(addresses.pairs)do
  if pair:match('^general__')then primaries[key(row.primary)]=true end
 end
 local plans={}
 for primary in pairs(primaries)do
  local bank=assert(world[primary]);local used={}
  local function reserve(row)
   for at=0,#row.metatiles-2,2 do used[word(row.metatiles,at)%1024]=true end
  end
  reserve(bank)
  for _,pair in pairs(addresses.pairs)do if key(pair.primary)==primary and pair.secondary then reserve(assert(world[key(pair.secondary)]))end end
  for _,row in pairs(data.map_tilesets or{})do
   -- Reserve animation slots conservatively across every map bank.
   for _,animation in ipairs(row.animations or{})do
    for tile=animation.tile,animation.tile+animation.count-1 do used[tile]=true end
   end
  end
  local free={};for tile=1,math.min(511,#bank.tiles/32-1)do if not used[tile]then free[#free+1]=tile end end
  assert(#free>=2,'No verified unused tiles for the localized shop sign')
  local function pixel(entry,x,y)
   local tile=entry%1024;assert(tile<512,'Shop sign moved to secondary tile bank')
   if math.floor(entry/1024)%2==1 then x=7-x end
   if math.floor(entry/2048)%2==1 then y=7-y end
   local b=assert(bank.tiles:byte(tile*32+y*4+math.floor(x/2)+1))
   return math.floor(b/2^(x%2*4))%16
  end
  local entries={word(bank.metatiles,66*16+2),word(bank.metatiles,67*16)}
  local upper={word(bank.metatiles,66*16+10),word(bank.metatiles,67*16+8)}
  for y=0,7 do for x=0,15 do
   local side=math.floor(x/8)+1;local e=entries[side]
   assert(math.floor(e/4096)==1 and pixel(e,x%8,y)==tonumber(spec.expected[y+1]:sub(x+1,x+1),16)
    and pixel(upper[side],x%8,y)==0,'Shop sign geometry changed; refusing a partial world patch')
  end end
  local pixels={};for y=0,7 do pixels[y]={};for x=0,15 do pixels[y][x]=y<3 and 1 or 2 end end
  for n,rows in ipairs(spec.letters)do for y,row in ipairs(rows)do for x=1,3 do
   if row:sub(x,x)=='1'then pixels[y-1][(n-1)*4+x]=y<=3 and 13 or 14 end
  end end end
  local tiles=bank.tiles;local metatiles=bank.metatiles
  for side=1,2 do
   local bytes={};for y=0,7 do for x=0,6,2 do bytes[#bytes+1]=string.char(pixels[y][(side-1)*8+x]+16*pixels[y][(side-1)*8+x+1])end end
   local at=free[side]*32;tiles=tiles:sub(1,at)..table.concat(bytes)..tiles:sub(at+33)
   at=side==1 and 66*16+2 or 67*16
   local e=4096+free[side];metatiles=metatiles:sub(1,at)..string.char(e%256,math.floor(e/256))..metatiles:sub(at+3)
  end
  plans[#plans+1]={bank=bank,tiles=tiles,metatiles=metatiles}
 end
 assert(#plans>0,'No shared Hoenn shop sign bank found')
 for _,p in ipairs(plans)do p.bank.tiles=p.tiles;p.bank.metatiles=p.metatiles end
 return #plans
end
function W.apply(data,world,english)
 local function word(off)local a,b,c,d=english:byte(off+1,off+4);assert(d);return a+b*256+c*65536+d*16777216-0x08000000 end
 local count=0
 for _,row in pairs(data.map_tilesets or{})do
  local at=row.address
  if at then
   local target=world[table.concat({word(at+4),word(at+8),word(at+12)},':')]
   if target then
    assert(#target.metatiles==#row.metatiles,'Localized metatile count differs from the supported base')
    row.tiles=target.tiles;row.palettes=target.palettes;row.metatiles=target.metatiles;row.tileCount=#target.tiles/32
    count=count+1
   end
  end
 end
 return count
end
return W
