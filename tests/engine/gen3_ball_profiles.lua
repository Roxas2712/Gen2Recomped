package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local X=require('src.import.RomExtractorGen3')
local J=require('src.link.Json')
local C=require('src.battle.Gen3Catching')
local expected={ruby={0x1fad90,0x2b6b0},sapphire={0x1fad20,0x2b6b0},
  firered={0x250892,0x2d54c},leafgreen={0x25086e,0x2d54c},emerald={0x31c48d,0x563f4}}
local ids={'MASTER_BALL','ULTRA_BALL','GREAT_BALL','POKE_BALL','SAFARI_BALL','NET_BALL',
  'DIVE_BALL','NEST_BALL','REPEAT_BALL','TIMER_BALL','LUXURY_BALL','PREMIER_BALL'}
for _,v in ipairs({'ruby','sapphire','firered','leafgreen','emerald'})do
  local f=assert(io.open('tools/rom_manifest_'..v..'.json','r'));local manifest=J.decode(f:read('*a'));f:close()
  local x=X.new('',v,manifest);local at=expected[v]
  local reads={};x.rom={u8=function(_,o)reads[o]=true;return({20,15,10,15})[o-at[1]+1]end,
    pointer=function(_,o)
      T.check(o>=at[2]and o<=at[2]+24 and(o-at[2])%4==0,'native seven-arm ball switch')
      local n=(o-at[2])/4;return at[2]+28+math.min(n,5)*32
    end}
  x._constants={itemOrder=ids,typeOrder={[12]='WATER',[7]='BUG'}};x._items={}
  for _,id in ipairs(ids)do x._items[id]={pocket='BALL'}end
  function x:write()end
  x:extractBalls();local b=x._constants.gen3Balls
  T.check(require('src.import.Gen3SafariAssets').ballsValid(b),'failed import cannot silently select Gen1 catching')
  T.check(reads[at[1]]and reads[at[1]+3],'bonus table belongs to this edition')
  T.eq(b.bonus.SAFARI_BALL,15);T.eq(b.bonus.ULTRA_BALL,20)
  T.eq(C.odds(b,'SAFARI_BALL',{catchRate=38,maxHP=100,hp=100}),19)
  local poison=C.odds(b,'POKE_BALL',{catchRate=100,maxHP=100,hp=100,status='TOX'})
  T.eq(poison,(v=='ruby'or v=='sapphire')and 33 or 49,'RS retains its original missing toxic-poison bonus')
  local n=0;local caught,shakes=C.attempt(b,'SAFARI_BALL',{catchRate=38,maxHP=100,hp=100},function(lo,hi)
    T.eq(lo,0);T.eq(hi,65535);n=n+1;return 65535
  end)
  T.eq(caught,false);T.eq(shakes,0);T.eq(n,1,'GBA shakes use raw 16-bit RNG, never the Gen1 byte roll')
end
X.applyAddressMap({})
T.finish('Five native ball profiles, original Safari bonus, toxic-poison difference and GBA shake RNG')
