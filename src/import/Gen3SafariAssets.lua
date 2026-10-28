-- Native Safari text and Hoenn arithmetic tables; no cartridge bytes shipped.
local M={}
local VERSIONS={ruby=true,sapphire=true,emerald=true,firered=true,leafgreen=true}
local RS={menu='BattleText_MenuOptionsSafari',prompt='BattleText_PlayerMenu',balls='BattleText_SafariBalls',
  left='BattleText_SafariBallsLeft',gotAway='BattleText_GotAwaySafely',wildFled='BattleText_FledWild',
  watching='BattleText_WatchingCarefully',used='BattleText_Used1',outOfBalls='BattleText_SafariOver',boxFull='BattleText_BoxFull',
  goNear='BattleText_CreptCloser',tooNear='BattleText_CantGetCloser',pokeblock='BattleText_ThrewBlock',
  curious='BattleText_CuriousAbout',enthralled='BattleText_EnthralledBy',ignored='BattleText_IgnoredThing'}
local EM={menu='gText_SafariZoneMenu',prompt='gText_WhatWillPkmnDo2',balls='gText_SafariBalls',
  left='gText_SafariBallLeft',gotAway='sText_GotAwaySafely',wildFled='sText_WildPkmnFled',
  watching='sText_PkmnWatchingCarefully',used='sText_PlayerUsedItem',outOfBalls='sText_OutOfSafariBalls',boxFull='sText_BoxIsFull',
  goNear='sText_CreptCloser',tooNear='sText_CantGetCloser',pokeblock='sText_ThrewPokeblockAtPkmn',
  curious='sText_PkmnCuriousAboutX',enthralled='sText_PkmnEnthralledByX',ignored='sText_PkmnIgnoredX'}
-- Matching US 1.0 builds. LeafGreen's battle-message section is 0x1c4
-- bytes earlier; each label is decoded from that edition's own cartridge.
local FR={menu=0x3fe747,prompt=0x3fe6e6,balls=0x3fe80c,left=0x3fe81c,
  gotAway=0x3fcc8a,wildFled=0x3fccd2,watching=0x3fd218,used=0x3fd650,
  boxFull=0x3fd876,outOfBalls=0x3fd24d,rock=0x3fd1df,bait=0x3fd1fa,angry=0x3fd232,eating=0x3fd23f}
local function labels(ir)
  local out,parts={},{}
  local function flush()if #parts>0 then out[#out+1]=table.concat(parts);parts={}end end
  for _,s in ipairs(ir)do
    if s.t=='text'then parts[#parts+1]=s.s
    elseif s.t=='tag'then parts[#parts+1]=s.tag
    elseif s.t=='nl'or s.t=='ext'and s.cmd==19 then flush()end
  end
  flush();assert(#out==4,'Native Safari menu must contain four actions');return out
end
function M.extract(x)
  assert(VERSIONS[x.version],'Unknown native Safari edition')
  local hoenn=x.version~='firered'and x.version~='leafgreen'
  local load=require('compat.gen1-rs.Loader').new(hoenn and x.version or'emerald')
  local IR=load('src.core.game3.scripting.text_ir')
  local S=hoenn and load('src.import.gba.syms').of(x.version)
  local dialect=x.version=='ruby'or x.version=='sapphire'
  dialect=dialect and'rs'or hoenn and'rse'or'frlg'
  local text={}
  for key,symbol in pairs(hoenn and(x.version=='emerald'and EM or RS)or FR)do
    local at=hoenn and S.off(symbol)or symbol-(x.version=='leafgreen'and 0x1c4 or 0)
    local bytes={}
    for i=0,2047 do
      local b=x.rom:u8(at+i);bytes[#bytes+1]=b
      if b==255 then break end
    end
    assert(bytes[#bytes]==255,'Unterminated native Safari label '..key)
    text[key]=IR.decode(bytes,{dialect=dialect,battle=key~='menu'and key~='balls'and key~='left'})
  end
  local spec={format=1,version=x.version,dialect=dialect,textIR=text,labels=labels(text.menu),
    source='ROM: edition-specific Safari battle messages, menu and healthbox labels'}
  if hoenn then
    local em=x.version=='emerald'
    local function off(a,b)return S.off(em and a or b)end
    spec.escapeFactor=3
    spec.tables=load('src.import.gba.rse.safari_rse_extract').extract(
      {get=function(_,at)return x.rom:u8(at)end},{
        pkblToEscape=off('sPkblToEscapeFactor','gUnknown_081FA70C'),pkblToEscapeSize=15,
        goNearCatch=off('sGoNearCounterToCatchFactor','gUnknown_081FA71B'),goNearCatchSize=4,
        goNearEscape=off('sGoNearCounterToEscapeFactor','gUnknown_081FA71F'),goNearEscapeSize=4,
        flavorCompat=S.off('gPokeblockFlavorCompatibilityTable'),flavorCompatSize=125})
  end
  assert(M.valid(spec,x.version),'Incomplete native Safari extraction')
  assert(M.ballsValid(x._constants.gen3Balls),'Native GBA ball rules did not extract')
  x._constants.gen3SafariNative=spec;x:write('constants',x._constants)
end
local function integer(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
function M.valid(s,v)
  if not VERSIONS[v]or type(s)~='table'or s.format~=1 or s.version~=v
    or type(s.textIR)~='table'or type(s.labels)~='table'or #s.labels~=4 then return false end
  local hoenn=v~='firered'and v~='leafgreen'
  if s.dialect~=((v=='ruby'or v=='sapphire')and'rs'or hoenn and'rse'or'frlg')then return false end
  for key in pairs(hoenn and RS or FR)do
    if type(s.textIR[key])~='table'or #s.textIR[key]==0 then return false end
  end
  for _,label in ipairs(s.labels)do if type(label)~='string'or label==''then return false end end
  if not hoenn then return true end
  local t=s.tables
  if s.escapeFactor~=3 or type(t)~='table'or t.format~=1 then return false end
  for _,name in ipairs({'goNearCounterToCatchFactor','goNearCounterToEscapeFactor'})do
    if type(t[name])~='table'or #t[name]~=4 then return false end
    for _,n in ipairs(t[name])do if not integer(n,0,20)then return false end end
  end
  if type(t.pkblToEscapeFactor)~='table'or type(t.flavorCompatibility)~='table'then return false end
  for i=0,4 do
    local row=t.pkblToEscapeFactor[i]
    if type(row)~='table'or #row~=3 then return false end
    for _,n in ipairs(row)do if not integer(n,0,20)then return false end end
  end
  for i=0,124 do if not integer(t.flavorCompatibility[i],-1,1)then return false end end
  return true
end
function M.ballsValid(b)
  if type(b)~='table'or type(b.order)~='table'or #b.order~=12 or b.scale~=10
    or type(b.bonus)~='table'or b.bonus.SAFARI_BALL~=15 or type(b.rule)~='table'then return false end
  local seen={}
  for _,id in ipairs(b.order)do if type(id)~='string'or seen[id]then return false end;seen[id]=true end
  for _,id in ipairs({'NET_BALL','DIVE_BALL','NEST_BALL','REPEAT_BALL','TIMER_BALL'})do
    if type(b.rule[id])~='table'then return false end
  end
  return seen.SAFARI_BALL==true and type(b.statusDouble)=='table'and type(b.statusHalf)=='table'
end
function M.missing(version)
  if not VERSIONS[version]then return{}end
  local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,c=false,nil;if f then ok,c=pcall(f)end
  return (M.valid(ok and type(c)=='table'and c.gen3SafariNative,version)and M.ballsValid(c.gen3Balls))and{}or{'<gba:native-safari>'}
end
return M
