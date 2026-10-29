package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local W=require('src.core.BuildWorker')
local callbacks,seq={},0
local original={available=W.available,submit=W.submit,cancel=W.cancel}
W.available=function()return true end
W.submit=function(_,key,payload,done,failed)
  seq=seq+1;callbacks[seq]={key=key,payload=payload,done=done,failed=failed};return seq
end
W.cancel=function()return true end
local P=require('src.core.Performance');local M=require('src.render.GbAssetPrefetch')
local released=0
local function pixels(size)return{getSize=function()return size or 256 end,
  release=function()released=released+1 end}end
local function make()return{kind='decode'},'v1',256 end
T.check(M.request('later',make));T.check(M.request('first',make,true))
M.service.step();T.eq(callbacks[1].key,'first','front hints outrank queued background work')
T.check(M.request('first',make));M.service.step();T.eq(seq,2,'in-flight duplicate submits no extra job')
callbacks[1].done(pixels());callbacks[2].done(pixels())
T.eq(M.status().bytes,512);T.eq(M.status().reserved,0)
T.check(M.get('first','v1')~=nil)
T.eq(M.get('first','edited'),nil,'changed source signature cannot publish old pixels')
T.eq(released,1,'rejected owned pixels are released')
local before=released;local owned=M.get('later','v1',true)
M.clear();T.eq(released,before,'taking CPU pixels transfers ownership')
owned:release()
M.request('late',make);M.service.step();local late=callbacks[seq]
M.clear();late.done(pixels())
T.eq(M.status().bytes,0,'late cancelled replies never repopulate a retired cache')
M.request('off',make);P.gbAssetPrefetch=false;M.service.step()
T.eq(M.status().queued,0,'disabling drains queued callbacks')
T.eq(M.request('off',make),false,'rollback cannot submit')
P.gbAssetPrefetch=true
for i=1,M.MAX_QUEUE+10 do M.request('bounded'..i,make)end
T.eq(M.status().queued,M.MAX_QUEUE,'hint queue is bounded')
M.service.step();M.service.step();local n=seq;M.service.step()
T.eq(seq,n,'only two speculative jobs can be in flight')
M.clear()
local World=require('src.world.OverworldController');local Game=require('src.core.Game')
local Assets=require('src.render.Assets');local V=require('src.core.GameVersion')
local oldData,oldVersion,oldHint=Game.data,V.get(),Assets.prefetchImage
-- As in the native warp contract, bind the ordinary boot-owned Game context
-- without materializing an unrelated map/cast merely to test planning.
local gameSlot,previousGame
for i=1,32 do local name,value=debug.getupvalue(World.prefetchAssets,i)
  if not name then break end
  if name=='Game'then gameSlot,previousGame=i,value;debug.setupvalue(World.prefetchAssets,i,Game);break end
end
assert(gameSlot,'native world must retain its boot-owned Game context')
local hints={}
Assets.prefetchImage=function(path,front)hints[#hints+1]={path,front};return true end
V.set('red')
local function map(id,east,west)
  return{id=id,width=10,height=10,tileset=id,connections={
    east=east and{map=east,offset=0}or nil,west=west and{map=west,offset=0}or nil},objects={}}
end
Game.data={maps={HOME=map('HOME','NEAR'),NEAR=map('NEAR','FAR','HOME'),FAR=map('FAR',nil,'NEAR')},
  tilesets={HOME={image='home.png'},NEAR={image='near.png'},FAR={image='far.png'}},sprites={}}
World.prefetchAssets({neighbors={{id='NEAR'}}},'HOME',false)
T.eq(#hints,1,'native world planner queues only the next nonresident ring')
T.eq(hints[1][1],'far.png')
hints={};World.prefetchAssets({},'FAR',true)
T.eq(hints[1][1],'far.png');T.eq(hints[1][2],true,'native warp target precedes neighbour hints')
V.set('emerald');hints={};World.prefetchAssets({},'FAR',true)
T.eq(#hints,0,'GBA retains its existing stream instead of duplicate GB work')
Assets.prefetchImage=oldHint;Game.data=oldData;V.set(oldVersion);M.clear()
debug.setupvalue(World.prefetchAssets,gameSlot,previousGame)
for k,v in pairs(original)do W[k]=v end
T.finish('GB worker admission: priority, duplicates, bounds, signatures and retirement')
