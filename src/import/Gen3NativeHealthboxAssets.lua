-- Native FR/LG/E healthbox font masks retain the cartridge's full rows.
-- In particular Emerald FONT_SMALL has two leading rows; trimming them is
-- appropriate for generic menus but changes the battle text baseline.
local M={}
local VERSIONS={firered=true,leafgreen=true,emerald=true}
function M.extract(x,elements,boxColors,barColors)
  if not VERSIONS[x.version]then return end
  local small
  for _,f in ipairs((x.manifest.font or{}).faces or{})do
    if f.role=='small'then small=f;break end
  end
  assert(small and small.bits==2 and small.count==512,'Native healthbox small font unavailable')
  local Image=require('src.import.ImageWriter')
  local fg,sh=Image.blank(256,512),Image.blank(256,512)
  local widths={};local across=small.tilesAcross or 2
  local stride=small.glyphBytes or 64
  for id=0,511 do
    widths[id]=x.rom:u8(small.widths+id)
    assert(widths[id]<=16,'Native small glyph exceeds its cell')
    for y=0,12 do for px=0,(small.cellWidth or 8)-1 do
      local tile=math.floor(y/8)*across+math.floor(px/8)
      local word=x.rom:u16(small.glyphs+id*stride+tile*16+y%8*2)
      local role=math.floor(word/2^(2*(7-px%8)))%4
      local image=role==1 and fg or role==2 and sh
      if image then image:setPixel(id%16*16+px,math.floor(id/16)*16+y,1,1,1,1)end
    end end
  end
  x:saveImage(fg,'battle/hud/small_fg.png');x:saveImage(sh,'battle/hud/small_shadow.png')
  -- Pad the final row without reading into a neighbouring ROM resource.
  local padded={};for i=1,80*32 do padded[i]=elements[i]or 0 end
  x:saveImage(x:hudImage(padded,1,40,2,barColors),'battle/hud/elements.png')
  x:saveImage(x:hudImage(padded,1,40,2,boxColors),'battle/hud/elements_exp.png')
  return{format=1,version=x.version,widths=widths,
    foreground='assets/generated/battle/hud/small_fg.png',
    shadow='assets/generated/battle/hud/small_shadow.png',
    elements='assets/generated/battle/hud/elements.png',
    elementsExp='assets/generated/battle/hud/elements_exp.png',
    source='ROM: untrimmed FONT_SMALL, native glyph 0x105 and interface element tiles'}
end
function M.valid(s,version)
  if not VERSIONS[version]or type(s)~='table'or s.format~=1 or s.version~=version
    or type(s.widths)~='table'then return false end
  for _,k in ipairs({'foreground','shadow','elements','elementsExp'})do
    if type(s[k])~='string'or s[k]==''then return false end
  end
  for id=0,511 do
    local w=s.widths[id]
    if type(w)~='number'or w%1~=0 or w<0 or w>16 then return false end
  end
  return true
end
function M.missing(version)
  if not VERSIONS[version]then return{}end
  local Fs=require('src.import.CacheFs')
  local raw=Fs.read('data/generated/constants.lua');local f=raw and loadstring(raw)
  if f then setfenv(f,{})end
  local ok,c=false,nil;if f then ok,c=pcall(f)end
  local s=ok and type(c)=='table'and c.gen3BattleHud and c.gen3BattleHud.native
  if not M.valid(s,version)then return{'<gba:native-healthbox-font>'}end
  local missing={}
  if version=='emerald'then
    local frames=c.gen3BattlerFrames
    if type(frames)~='table'or frames.format~=1 or frames.version~=version
      or type(frames.frontTable)~='number'or type(frames.backTable)~='number'
      or frames.frontTable==frames.backTable then
      missing[#missing+1]='<emerald:native-front-back-coordinates>'
    end
  end
  if version=='leafgreen'then
    local terrain=c.gen3BattleTerrain
    -- The old FireRed table begins 36 bytes into LeafGreen's table and can
    -- still produce 18 malformed pictures. Reject that apparently ready cache.
    if type(terrain)~='table'or not terrain.tableAt or type(terrain.order)~='table'
      or #terrain.order~=20 or type(terrain.images)~='table'then
      missing[#missing+1]='<leafgreen:native-battle-terrain>'
    else
      for _,key in ipairs(terrain.order)do
        local path=terrain.images[key]
        if type(path)~='string'or not Fs.exists(path)then
          missing[#missing+1]='<leafgreen:battle-terrain-'..tostring(key)..'>'
        end
      end
    end
  end
  for _,k in ipairs({'foreground','shadow','elements','elementsExp'})do
    if not Fs.exists(s[k])then missing[#missing+1]=s[k]end
  end
  return missing
end
return M
