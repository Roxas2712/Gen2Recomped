-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion')
local Pokemon=require('src.pokemon.Pokemon')
local function load(edition,body,api,format)
 Version.set(edition)
 local data=T.fixtures.fresh();data.constants.gen=edition=='crystal'and 2 or 1
 local manifest={id='extension',name='Source effect extension',version='1.0.0',api=api or 2,entry='main.lua',affects_link=true,content_format=format}
 local json=require('src.link.Json')
 return T.sdk.loadMods({'mods/extension'},{data=data,fs=T.sdk.memfs({
  ['mods/extension/manifest.json']=json.encode(manifest),['mods/extension/main.lua']='local mod=...\n'..body,
 })}),data
end
local registration=[[
 mod.content.move_effects:register('ATTACK_DOWN2_EFFECT',{kind='primary',accuracyChecked=true,
   run=function(ctx)return ctx.changeStage(ctx.target,'attack',-2,true)end})
 mod.content.moves:register('LEGACY_CHARM',{id='LEGACY_CHARM',name='CHARM',type='NORMAL',
   power=0,accuracy=100,pp=20,effect='ATTACK_DOWN2_EFFECT'})
]]
for _,edition in ipairs({'red','blue','yellow'})do
 local run,data=load(edition,registration)
 T.eq(#run.errors,0,edition..': old source can provide an effect added by the shared host')
 T.eq(run.loader.content.move_effects.owners.ATTACK_DOWN2_EFFECT,'extension','authored extension owns its actual effect')
 local game={data=data,save=require('src.core.SaveData').newGame(),mods=run.loader,options={}}
 game.save.party={Pokemon.new(data,'FIXMON_A',20)}
 require('src.render.Font').load(data);require('src.battle.TypeChart').load(data)
 local b=require('src.battle.BattleState').newWild(game,'FIXMON_B',15)
 b.queue={};b.phase='menu';b.sendingOut=nil
 b:performMove(b.player,b.enemy,{id='LEGACY_CHARM',pp=20})
 T.eq(b.enemy.stages.attack,-2,'source extension changes the real target Attack stage')
 T.check(#b.queue>0,'native effect messages use the real action queue')
 run.release()
end
for _,case in ipairs({
 {edition='red',api=2,id='ATTACK_DOWN1_EFFECT',why='original Gen1 builtin stays reserved'},
 {edition='crystal',api=2,id='ATTACK_DOWN2_EFFECT',why='native Gen2 registration stays strict'},
 {edition='red',api=2,id='ATTACK_DOWN2_EFFECT',format='unified',why='unified registration stays strict'},
})do
 local run=load(case.edition,("mod.content.move_effects:register('%s',{kind='primary',run=function()end})"):format(case.id),case.api,case.format)
 T.eq(#run.errors,1,case.why);run.release()
end
local run,data=load('red',registration.."\nmod.content.move_effects:register('ATTACK_DOWN2_EFFECT',{kind='primary',run=function()end})")
T.eq(#run.errors,1,'a second authored registration remains a duplicate')
T.eq(run.loader.content.move_effects.owners.ATTACK_DOWN2_EFFECT,'engine','failed source extension rolls back the native owner')
run.release()
run=load('red',"mod.content.move_effects:register('ATTACK_DOWN2_EFFECT',{kind='invalid',run=function()end})")
T.eq(#run.errors,1,'API-2 schema validation is preserved');run.release()
T.finish('Legacy Gen1 effect extension over the native shared host')
