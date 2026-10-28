-- RS healthbox palette, blank name tile and all four native status variants.
local M={}
local STATUS={'PSN','PAR','SLP','FRZ','BRN'}
local VARIANTS={21,71,86,101}

function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native healthboxes')
  local A=load('src.import.gba.rs.assets')
  local K=load('src.import.gba.rse.boot_gfx')
  local S=load('src.import.gba.syms').of(x.version)
  local c=A.context(rom,cache,{},'rs_healthbox')
  local V={SYMS=S,sym=S.off}
  load('src.import.gba.games.rs.text_chrome')(V)
  load('src.import.gba.games.rs.battle')(V)
  local B=V.BATTLE_UI
  local raw=rom:readString(B.healthbox_elements,B.healthbox_elements_span_size)
  local pal=c:palFrom(rom:readString(B.healthbox_pal,32),16)
  local barPal=c:palFrom(rom:readString(B.healthbar_pal,32),16)
  local blank=c:strip('blank',raw,8,8,1,pal,4,43).png
  local elements=c:strip('elements',raw,320,24,1,barPal,4).png
  local elementsExp=c:strip('elements_exp',raw,320,24,1,pal,4).png
  local dynamic=c:pal('gBattleInterfaceStatusIcons_DynPal',16)
  local function pixel(tile,dx,dy)
    local byte=assert(raw:byte(tile*32+dy*4+math.floor(dx/2)+1),'RS status tile outside element span')
    return dx%2==0 and byte%16 or math.floor(byte/16)
  end
  local icons={}
  for bid=0,3 do
    local rows={};icons[bid+1]=rows
    for ailment,key in ipairs(STATUS)do
      local pixels={};local colors={}
      for n=0,15 do colors[n]=barPal[n]end
      colors[16]=dynamic[ailment-1]
      local first=VARIANTS[bid+1]+(ailment-1)*3
      local other=VARIANTS[(bid+1)%4+1]+(ailment-1)*3
      for y=0,7 do for x0=0,23 do
        local a=pixel(first+math.floor(x0/8),x0%8,y)
        local b=pixel(other+math.floor(x0/8),x0%8,y)
        local ca,cb=barPal[a],barPal[b]
        local different=(a==0)~=(b==0)or ca%32768~=cb%32768
        pixels[#pixels+1]=different and 16 or a
      end end
      rows[key]=c:png(('status_%d_%s.png'):format(bid,key),24,8,pixels,colors,true)
    end
  end
  assert(A.finish(c,{screen='healthbox',blank=blank,status=icons}))
  x._constants.gen3RsHealthbox={format=1,version=x.version,blank=blank,status=icons,
    elements=elements,elementsExp=elementsExp,palette=K.palList(pal,0,16),
    source='ROM: RS healthbox palette, element tile43, four status-element variants and dynamic status palette'}
  local coords=x._constants.gen3BattlerCoords or{}
  -- Gen1Recomp's pinned RS profile retains the original OAM centre contract.
  -- Emerald's instruction addresses cannot recover this table from RS.
  coords.healthbox={singlesPlayer={x=158,y=88},singlesOpponent={x=44,y=30},
    playerLeft={x=159,y=77},opponentLeft={x=44,y=19},playerRight={x=171,y=102},opponentRight={x=32,y=44}}
  coords.healthboxSource='Pinned Gen1Recomp native RS healthbox/profile OAM centres'
  x._constants.gen3BattlerCoords=coords
end

function M.valid(s,version)
  if type(s)~='table'or s.format~=1 or s.version~=version
    or type(s.blank)~='string'or type(s.elements)~='string'or type(s.elementsExp)~='string'
    or type(s.palette)~='table'or #s.palette~=16
    or type(s.status)~='table'or #s.status~=4 then return false end
  for _,rows in ipairs(s.status)do
    if type(rows)~='table'then return false end
    for _,key in ipairs(STATUS)do if type(rows[key])~='string'then return false end end
  end
  for _,word in ipairs(s.palette)do
    if type(word)~='number'or word%1~=0 or word<0 or word>32767 then return false end
  end
  return true
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local raw=Fs.read('data/generated/constants.lua');local chunk=raw and loadstring(raw)
  if chunk then setfenv(chunk,{})end
  local ok,c=false,nil;if chunk then ok,c=pcall(chunk)end
  local s=ok and type(c)=='table'and c.gen3RsHealthbox
  if not M.valid(s,version)then return {'<rs:native-healthbox>'}end
  local absent={}
  for _,path in ipairs({s.blank,s.elements,s.elementsExp})do
    if not Fs.exists(path)then absent[#absent+1]=path end
  end
  for _,rows in ipairs(s.status)do for _,path in pairs(rows)do
    if not Fs.exists(path)then absent[#absent+1]=path end
  end end
  return absent
end
return M
