-- Native first-battle / Wally exclusions must preserve the RNG stream.
local T=require('tests.harness').suite('Hoenn critical guards')
local V=require('src.core.GameVersion');local C=require('src.battle.Gen3Critical')
local old=V.get();local draws=0
local function draw()draws=draws+1;return true end
for _,v in ipairs({'ruby','sapphire','emerald'})do
 V.set(v)
 for _,b in ipairs({{firstBattle=true,firstBattleKind='birch',oakMsgFlags=1},{wallyTutorial=true},{kinds={tutorial='wally'}}})do
  local before=draws;T.eq(C.roll(b,draw),false,v..' native guard');T.eq(draws,before,v..' no RNG consumption')
 end
 T.eq(C.roll({},draw),true,v..' ordinary critical preserved')
end
V.set('leafgreen')
T.eq(C.roll({firstBattle=true},draw),false,'Oak opening guard')
T.eq(C.roll({firstBattle=true,firstBattleKind='oak',oakMsgFlags=1},draw),true,'Oak permits critical after first damage')
local before=draws;T.eq(C.roll({pokedudeDemo=true},draw),false,'Teachy TV discards critical');T.eq(draws,before+1,'Teachy TV still consumes RNG')
V.set('red');T.eq(C.roll({},draw),true,'Game Boy rules unchanged');V.set(old)
T.finish()
