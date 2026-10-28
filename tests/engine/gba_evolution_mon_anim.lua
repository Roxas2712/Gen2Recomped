-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.ui.Gen3EvolutionMonAnim')
local Motion,Pictures=require('src.pokemon.MonAnim'),require('src.pokemon.PicAnim')
local newMotion,newPictures=Motion.new,Pictures.new
local started,frames=0,0
Motion.new=function(_,key)
 T.eq(key,'MAGIKARP','native numeric species resolves to stable motion identity')
 return{start=function()started=started+1 end,update=function()frames=frames+1 end,active=function()return frames<2 end}
end
Pictures.new=function(_,key,mon)
 T.eq(key,'MAGIKARP','native numeric species resolves to stable picture identity');T.eq(mon.species,key,'actual mon context retained')
 return nil
end
local raw={species='MAGIKARP'};local game={data={}}
local adapter=M.new(game,function(n)T.eq(n,129,'original controller passes native index');return{id='MAGIKARP'}end,raw)
local sprite=adapter.newSprite(129);T.eq(adapter.run(sprite),sprite,'reference run retains its sprite')
local cries=0
-- Exact five-argument call in pinned evolution_scene.lua:evo_mon_anim.
adapter.doFront(sprite,129,false,0,{cry=function(n)T.eq(n,129);cries=cries+1 end})
T.eq(started,1,'front motion starts once');T.eq(cries,1,'fifth-argument cry callback is not lost as pan')
T.eq(adapter.busy(sprite),true,'original intro waits while motion is active')
adapter.step();adapter.step();T.eq(adapter.busy(sprite),false,'private motion progress releases original intro')
adapter.stop(sprite);T.eq(adapter.busy(sprite),false,'retired motion cannot hold scene');adapter.close()
Motion.new,Pictures.new=newMotion,newPictures
T.finish('native evolution five-argument front animation, cry callback and private motion progress')
