-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local F=require('tools.player-runtime.fixture')
local V=require('src.core.GameVersion');local Music=require('src.core.Music')
local Json=require('src.link.Json');local original=V.get();local playMap=Music.playMap
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen','red','crystal'}do
 local f=F.new(edition);local g,w=f.game,f.world
 local hoenn=edition=='ruby'or edition=='sapphire'or edition=='emerald'
 for _,held in ipairs{false,true}do
  for _,scripted in ipairs{false,true}do
   g.save.flags.FLAG_G3_4001=held and true or nil
   g.save.onBike=true;w.player.surfing=true
   local calls={};Music.playMap=function(data,id,bike,surfing)calls[#calls+1]={data,id,bike,surfing}end
   local before=Json.encode(g.save)
   w.pendingSeamMusic=w.map.id;w:finishPlayerStep(false,scripted)
   T.eq(#calls,0,'no completed step must not start a seam cue')
   T.eq(w.pendingSeamMusic,w.map.id,'unfinished seam retains its pending owner')
   w:finishPlayerStep(true,scripted)
   local expected=hoenn and held and 0 or 1
   T.eq(#calls,expected,edition..' native flag holds only Hoenn sailing cues')
   T.eq(w.pendingSeamMusic,nil,'completed seam consumes its pending cue once')
   if expected==1 then
    T.eq(calls[1][1],g.data);T.eq(calls[1][2],w.map.id)
    T.eq(calls[1][3],true,'ordinary bike context is forwarded')
    T.eq(calls[1][4],true,'ordinary surf context is forwarded')
   end
   w:finishPlayerStep(true,scripted);T.eq(#calls,expected,'no duplicate cue on the next step')
   T.eq(Json.encode(g.save),before,'music ownership does not rewrite any save field')
   g.save.flags.FLAG_G3_4001=nil
   w.pendingSeamMusic=w.map.id;w:finishPlayerStep(true,scripted)
   T.eq(#calls,expected+1,'releasing native hold restores the next ordinary map cue')
   w.pendingSeamMusic='OLD_MAP';w:finishPlayerStep(true,scripted)
   T.eq(#calls,expected+1,'stale previous-map cue is discarded')
   T.eq(w.pendingSeamMusic,nil)
  end
 end
end
Music.playMap=playMap;V.set(original)
T.finish('Hoenn sailing music hold, native release, once-only seam ownership and other-edition isolation')
