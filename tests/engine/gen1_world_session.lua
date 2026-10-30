package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.features.Gen1WorldSession')
local G=require('src.core.Game3')
local Map=require('src.core.game3.map')
local previous=require('src.core.GameVersion').get()
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 local f=require('tools.map-runtime.fixture').new(edition)
 local w,g=f.world,f.game
 g.save={party={},player={map=f.map.id,x=0,y=0}}
 function g.stack:top()return self.states[#self.states]end
 w.player={cellX=0,cellY=0,facing='down'}
 w.runner={isRunning=function()return false end,run=function(_,rows)g.scriptRows=rows end}
 local loads,prefetches=0,{}
 function w:setMap(id,x,y,dir,opts)
   loads=loads+1
   T.eq(id,f.neighbor.id,'native loader receives physical map id')
   T.eq(g.save.player.map,f.map.id,'adapter does not pre-write save position')
   self.map=f.neighbor;self.player.cellX,self.player.cellY,self.player.facing=x,y,dir
   g.save.player.map,g.save.player.x,g.save.player.y=id,x,y
   self.nativeOptions=opts
 end
 function w:prefetchAssets(id,urgent)prefetches[#prefetches+1]={id,urgent}end
 package.loaded['src.core.Game']=g;Map.release();G.release()
 local session=assert(M.new(g))
 T.eq(session:current().map,f.mapId,'source map id resolves from actual map group')
 T.check(session:enqueueWarm(f.neighborId),'queue native resource work')
 T.check(session:enqueueWarm(f.neighborId),'duplicate request is idempotent')
 T.check(session:stepWarm(),'one prefetch per scheduling step')
 T.eq(session:stepWarm(),false,'queue does not tick native resource clocks')
 T.eq(#prefetches,1,'shared native prefetch owner runs once')
 T.eq(prefetches[1][1],f.neighbor.id,'resource request uses native id')
 g.stack.states[#g.stack.states+1]={}
 T.eq(session:load(f.neighborId,{x=1,y=1}),nil,'covering UI retains input ownership')
 table.remove(g.stack.states)
 T.eq(session:load(f.neighborId,{x=999,y=1}),nil,'out-of-bounds destination rejects before loading')
 T.eq(session:load(f.neighborId,{x=1,y=1,unknown=true}),nil,'unsupported semantic options reject explicitly')
 T.eq(session:load(f.neighborId,{initialLoad=true}),nil,'boot-only initialLoad cannot silently change native semantics')
 T.eq(loads,0,'failed requests cannot modify map or save')
 local result=assert(Map.load(nil,g,f.neighborId,{x=1,y=1,facing='left',keepMusic=true}))
 T.eq(result.world,w,'there is one actual native world')
 T.eq(result.map,f.neighborId,'completed load publishes source identity')
 T.eq(w.nativeOptions.keepMusic,true,'native map options are forwarded deliberately')
 local facade=assert(G.forNative(g));local feature=assert(facade:worldSession())
 T.eq(feature:current().nativeMap,f.neighbor.id,'Game3 constructor shares loaded world')
 T.check(feature:queueScript({{'native-test'}}),'script submission uses existing runner')
 T.eq(g.scriptRows[1][1],'native-test','native runner receives actual submitted rows')
 local active=true
 local optional=require('src.features.Gen1Compatibility').forHost(function()if active then return g end end,g.data)
 local owned=assert(optional.world())
 T.eq(owned:current().world,w,'API3 optional world shares the actual native world')
 active=false
 T.eq(owned:load(f.mapId,{}),nil,'a retired mod cannot retain a writable world handle')
 optional.release();T.eq(optional.world(),nil,'released feature cannot reacquire a native session')
 G.release();T.eq(feature:valid(),false,'Game3 release retires feature sessions')
 g.save={};T.eq(session:valid(),false,'save replacement retires old sessions')
 T.eq(session:load(f.mapId,{}),nil,'retired sessions cannot load another map')
 session:release();f.views:release();Map.release()
end
require('src.core.GameVersion').set(previous)
package.loaded['src.core.Game']=nil
T.finish('Owned Game3 load, script and resource feature contracts')
