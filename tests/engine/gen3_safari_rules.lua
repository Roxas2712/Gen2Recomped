package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness')
local oldLoad=love.filesystem.load;love.filesystem.load=loadfile
local S=require('src.battle.Gen3SafariRules')
local tables={goNearCounterToCatchFactor={1,2,3,0},goNearCounterToEscapeFactor={4,3,2,0},
  pkblToEscapeFactor={[0]={0,0,0},[1]={1,2,0},[2]={2,3,0},[3]={3,4,0},[4]={4,5,0}},
  flavorCompatibility={}}
for i=0,124 do tables.flavorCompatibility[i]=0 end
tables.flavorCompatibility[0]=1;tables.flavorCompatibility[1]=-1
local spec={escapeFactor=3,tables=tables}
for _,version in ipairs({'ruby','sapphire','emerald','firered','leafgreen'})do
  local rse=S.isHoenn(version)
  T.same(S.actions(version),rse and{'ball','pokeblock','go_near','run'}or{'ball','bait','rock','run'})
  for rate=0,255 do
    local sf=S.new(version,rate,rate,17,spec)
    T.eq(sf.balls,17);T.eq(sf.catchFactor,math.floor(rate*100/1275))
    T.eq(S.catchRate(sf),math.floor(math.floor(rate*100/1275)*1275/100))
    local factor=math.floor(rate*100/1275);if factor<=1 then factor=2 end
    T.eq(sf.escapeFactor,rse and 3 or factor)
    T.eq(S.fleePercent(sf),(rse and 3 or factor)*5)
  end
  local sf=S.new(version,45,125,30,spec)
  local calls=0;local function rng()calls=calls+1;return 44 end
  T.eq(S.flees(sf,rng),not rse);T.eq(calls,1,'one raw native draw per flee check')
  T.eq(S.flees(sf,function()return 65535 end),not rse,'flee checks use raw-16-bit modulo 100')
  if not rse then
    S.throwBait(sf,function()calls=calls+1;return 0 end)
    T.eq(calls,2);T.eq(sf.baitCounter,2);T.eq(sf.rockCounter,0);T.eq(sf.catchFactor,3)
    T.eq(S.fleePercent(sf),10);T.eq(S.watchStep(sf),'eating');T.eq(S.watchStep(sf),'watching')
    T.eq(sf.catchFactor,3,'bait expiry retains its working catch factor')
    S.throwRock(sf,function()return 4 end)
    T.eq(sf.rockCounter,6);T.eq(sf.baitCounter,0);T.eq(sf.catchFactor,6);T.eq(S.fleePercent(sf),90)
    for _=1,5 do T.eq(S.watchStep(sf),'angry')end
    T.eq(S.watchStep(sf),'watching');T.eq(sf.catchFactor,3,'rock expiry restores the species factor')
    local before=sf.catchFactor
    T.eq(pcall(S.throwBait,sf,function()return 65536 end),false,'invalid draws never fall back to untracked RNG')
    T.eq(sf.catchFactor,before)
  else
    T.eq(S.goNear(sf,spec),'STRINGID_CREPTCLOSER');T.eq(sf.catchFactor,4);T.eq(sf.escapeFactor,7)
    S.goNear(sf,spec);S.goNear(sf,spec)
    T.eq(sf.catchFactor,9);T.eq(sf.escapeFactor,12);T.eq(sf.goNearCounter,3)
    T.eq(S.goNear(sf,spec),'STRINGID_CANTGETCLOSER');T.eq(sf.goNearCounter,3)
    for _,case in ipairs({{{10,2,0,0,0},1,8,1},{{1,10,0,0,0},2,-9,3},{{8,8,0,0,0},0,0,2}})do
      local block={flavours=case[1],feel=17,colour=1};local fresh=S.new(version,45,125,30,spec)
      local result,gain=S.throwPokeblock(fresh,spec,0,block)
      T.eq(result,case[2]);T.eq(gain,case[3]);T.eq(fresh.escapeFactor,case[4])
      T.eq(fresh.pkblThrowCounter,1);T.eq(fresh.pokeblockThrows,1)
      T.eq(block.feel,17);T.same(block.flavours,case[1],'nature preference never rewrites the chosen block')
    end
    T.eq(pcall(S.throwRock,sf,function()return 0 end),false,'Hoenn never silently uses Kanto rocks')
  end
end
T.eq(pcall(S.new,'gold',45,125,30,spec),false)
love.filesystem.load=oldLoad
T.finish('five-edition native Safari factors, raw RNG draws, nature tastes and independent state')
