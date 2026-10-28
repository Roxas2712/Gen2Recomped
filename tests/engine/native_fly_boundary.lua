-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local G=require('src.core.Game3');local Field=require('src.core.game3.field')
local Actions=require('src.world.WorldActions');local Boundary=require('src.compat.gen1.ScriptBoundary')
local original=Field.flyTo;local admission=Actions.flyTo
local Sound=require('src.core.Sound');local play=Sound.play;local sounds=0
Sound.play=function(_,id)T.eq(id,'Fly');sounds=sounds+1 end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.session-runtime.fixture').new(edition);local game,world=f.game,f.world
 game.data.field={flyOrder={'TEST'},flyWarps={TEST={x=4,y=5}}};f.map.def.regionMapSection=7
 game.save.visited={TEST=true};local clears,surf=0,0
 world.clearBikeFlags=function()clears=clears+1 end
 world.syncSurfingPikachu=function()surf=surf+1 end
 world.hasFlyBird=function()return false end
 local wrappers=0
 Field.flyTo=function(section,mon,info)
  wrappers=wrappers+1;T.eq(section,7);T.eq(info.dest.x,4);T.eq(info.dest.y,5)
  T.eq(Field._game,G.forNative(game));T.eq(Boundary.active('field.flyTo'),true)
  info.dest.x=999
  local a,b,c=original(section,mon,info);local d=original(section,mon,info)
  T.eq(a,nil);T.eq(b,nil);T.eq(c,nil);T.eq(d,nil)
 end
 local start=sounds;world:flyTo('TEST')
 T.eq(wrappers,1);T.eq(sounds,start+1);T.eq(clears,1);T.eq(surf,1)
 T.eq(world.flyDest.x,4,'detached wrapper metadata cannot redirect native destination')
 T.eq(world.flyAnim.frames,48);T.eq(world.player.inputLocked,true)
 T.eq(Boundary.active('field.flyTo'),false)
 Field.flyTo=original;world.flyAnim=nil;world.player.inputLocked=false
 local requests=0
 Actions.flyTo=function(g,w,id)requests=requests+1;T.eq(g,game);T.eq(w,world);T.eq(id,Field.flyDestination(7).map);return false,'native admission refused'end
 local ok,why=Field.flyTo(7);T.eq(ok,false);T.eq(why,'native admission refused');T.eq(requests,1)
 T.eq(Field.flyTo(99),nil);T.eq(requests,1,'unknown section cannot call travel owner')
 Actions.flyTo=admission
 -- A native failure remains once-only even if a wrapper catches and retries it.
 local OW=require('src.world.OverworldController');local body=OW._flyToBody;local attempts=0
 OW._flyToBody=function()attempts=attempts+1;error('native fly failure')end
 Field.flyTo=function(...)pcall(original,...);pcall(original,...)end
 T.raises(function()world:flyTo('TEST')end,'native fly failure');T.eq(attempts,1)
 T.eq(Boundary.active('field.flyTo'),false);OW._flyToBody=body;Field.flyTo=original
 -- Native callers in another generation never enter the source boundary.
 require('src.core.GameVersion').set('crystal');Field.flyTo=function()error('foreign source fly')end
 world:flyTo('TEST');T.eq(clears,2);Field.flyTo=original
 G.release()
end
Sound.play=play;Field.flyTo=original;Actions.flyTo=admission
T.finish('native flight continuation, once-only forwarding and standalone admission')
