-- The reference checkout is read-only; only the contract source comes from this fork.
package.path='./?.lua;./?/init.lua;'..package.path
local engine,root=assert(arg[1]),assert(arg[2])
assert(engine=='gen1'or engine=='gen2')
if engine=='gen2'then return dofile(root..'/tests/engine/native_audio_shutdown.lua')end
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local previous=V.get()
local A=require('src.core.game3.audio')
local C=assert(loadfile(root..'/tools/audio-shutdown-contract-check/cases.lua'))()
local function source()
 local s={playing=true,volume=1}
 function s:play()self.playing=true end
 function s:stop()self.playing=false end
 function s:isPlaying()return self.playing end
 function s:setVolume(n)self.volume=n end
 return s
end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 V.set(edition)
 C.run(A,T,function()
  -- Seed this engine's genuine player slots with synthetic device handles;
  -- the shared cases invoke its actual, unmodified public shutdown methods.
  local music,se,cry,outside=source(),source(),source(),source()
  A._bgmSource=music;A._currentSong='BOOT';A._seSources={se}
  A._seMeta[se]={id=1,player=1};A._seByPlayer[1]=se
  A._crySource=cry;A._cryUntil=(A._cryClock or 0)+100;A._fanfareActive=true
  return {music=music,se=se,cry=cry,outside=outside,currentSong=A.currentSong,
   restartCry=function()cry:play();A._crySource=cry;A._cryUntil=(A._cryClock or 0)+100 end,
   afterStop=function()T.eq(A._fanfareActive,false,'old fanfare cannot remain current');A.update(0)end,
   cleanup=function()A.stopAll();A._bgmSource=nil end}
 end)
end
V.set(previous)
T.finish('shared Gen1/Gen2 portable audio stopCry/stopAll observable contract')
