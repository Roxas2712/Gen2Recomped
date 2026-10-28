-- Silent native playback owns its wait even after an earlier device stopped.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
local version='ruby'
package.loaded['src.core.GameVersion']={get=function()return version end}
package.loaded['src.core.Music']={nativeCryStarted=function()end,nativeCryStopped=function()end}
local failure
package.loaded['src.core.M4ASynth']={renderNativeCry=function()
  if failure=='error'then error('owned unavailable synth')end
  if failure=='missing'then return nil end
  return {},{frames=3}
end}
love={audio={newSource=function()
  local s={playing=false,setVolume=function()end}
  function s:play()self.playing=true end
  function s:stop()self.playing=false end
  function s:isPlaying()return self.playing end
  return s
end}}
local Player=require('src.core.NativeCryPlayer')
local function data()
 return {audio={gen3={},gen3Cries={table=0},cries={CHARMANDER={m4a=3}}},
  constants={speciesOrder={[4]='CHARMANDER'}}}
end
local function play(d,opts)return Player.play(d,'CHARMANDER',opts or {},function()error('unexpected legacy owner')end,1,false)end
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 version=edition
 for _,kind in ipairs{'no-pack','missing','error'}do
  failure=nil;Player.stop()
  local previous=assert(play(data()))
  previous:stop()
  T.eq(Player.finished(),true,'the preceding device has already completed')
  local nextData=data()
  if kind=='no-pack'then nextData.audio.gen3=nil else failure=kind end
  local before=Player.snapshot()
  T.eq(play(nextData,{isolated=true}),nil,'an isolated failed playback has no source')
  T.same(Player.snapshot(),before,'isolated failure never changes native wait ownership')
  T.eq(play(nextData),nil,'the new native fallback has no physical output')
  T.eq(Player.finished(),false,'the earlier stopped source cannot complete the new fallback')
  local pending=Player.snapshot()
  T.eq(pending.untilFrame,pending.clock+64,'the existing native fallback retains its duration')
  for _=1,10 do Player.finished()end
  T.same(Player.snapshot(),pending,'completion polling does not tick the fallback')
  for _=1,63 do Player.tick()end
  T.eq(Player.finished(),false,'the fallback owns its full native wait')
  Player.tick()
  T.eq(Player.finished(),true,'the native clock completes its fallback')
  failure=nil
  local current=assert(play(data()))
  T.eq(current:isPlaying(),true,'later valid playback retains its physical source')
  for _=1,3 do Player.tick()end
  T.eq(Player.finished(),true,'later native playback uses its own duration')
 end
end
Player.stop()
T.finish('Native cry fallback ownership after completed device playback')
