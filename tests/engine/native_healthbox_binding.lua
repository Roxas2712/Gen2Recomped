package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.battle.Gen3NativeHealthbox')
local Loader=require('compat.gen1-rs.Loader')
local Level=require('src.ui.LevelDisplay')
local Care=require('src.pokemon.DayCare')
local Scope=require('src.render.GraphicsScope')
local oldAvailable,oldLoad,oldLevel,oldGender,oldScope=M.available,Loader.new,Level.visible,Care.gender,Scope.call
M.available=function()return{images={playerDoubles='p',opponentDoubles='e'},status={PSN='p'}}end
Care.gender=function()return'female'end
Scope.call=function(fn)return pcall(fn)end
local checked,seen,hidden=0,nil,nil
Level.visible=function(mon,side,game)seen=mon;return mon.level~=100 end
local b={data={pokemon={TEST={index=25,name='PIKACHU'}}},game={}}
function b:isDouble()return true end
function b:statusLabel()return'PSN'end
b.player={mon={species='TEST',level=39,stats={hp=114},hp=44},name='FIRST',position=0}
b.enemy={mon={species='TEST',level=30,stats={hp=80},hp=80},name='FOE',position=1}
local second={mon={species='TEST',level=100,stats={hp=300},hp=200,status='MOD_POISON'},
  name='SECOND',position=2,shownStatus='MOD_POISON'}
function b:battlerAt(id)return id==2 and second or id==0 and b.player or b.enemy end
Loader.new=function(_,bindings)
  return function(name)
    T.eq(name,'src.core.game3.battle.healthbox')
    local compositor={center=function()return{x=171,y=100}end}
    function compositor.draw(id,view,opts)
      checked=checked+1;T.eq(id,2)
      T.eq(view.name,'SECOND');T.eq(view.mon.gender,'F')
      T.eq(view.mon.status,'PSN','reference view uses the native HUD label seam')
      T.check(view.mon~=second.mon,'reference cannot write the authoritative Pokemon')
      local presented=bindings['src.core.game3.battle.anim'].present(id)
      T.eq(presented.displayStatus,'PSN')
      T.eq(bindings['src.mods.Runtime'].wantsHook('pokemon.level_visible'),true)
      hidden=bindings['src.ui.LevelDisplay'].visible(view.mon,'battle.player')
      T.eq(seen,second.mon,'secondary player healthbox passes its own Pokemon to the public hook')
      T.eq(opts.ox,30);T.eq(opts.oy,7,'viewport offsets are applied once')
      if checked==2 then error('intentional native compositor error')end
    end
    return compositor
  end
end
T.eq(M.draw(b,second,169,91,true),true);T.eq(hidden,false)
T.raises(function()M.draw(b,second,169,91,true)end,'intentional native compositor error')
T.eq(second.mon.status,'MOD_POISON');T.eq(second.mon.hp,200)
b.safari=true;T.eq(M.draw(b,second,0,0,true),false,'Safari retains its separate controller')
M.available,Loader.new,Level.visible,Care.gender,Scope.call=oldAvailable,oldLoad,oldLevel,oldGender,oldScope
T.finish('Native healthbox host ownership, double-battler visibility and status bindings')
