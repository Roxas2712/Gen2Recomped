-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Commands=require('src.script.Commands')
local G=require('src.script.Gen3Commands')
local VM=require('src.script.Gen3ScriptVM')
local Menu=require('src.ui.Menu')
for _,version in ipairs{'emerald','firered','leafgreen'}do
 V.set(version)
 local data=T.fixtures.fresh()
 data.constants=data.constants or{}
 data.constants.gen3Multichoice={{'B1F','B2F','B4F','EXIT'}}
 require('src.render.Font').load(data)
 local save={party={{species='PROBE',hp=24}},inventory={LIFT_KEY=1},flags={story=true}}
 local protected=require('src.core.SaveSerializer').encode({save.party,save.inventory,save.flags})
 local button
 local game={data=data,save=save,stack=setmetatable({},{__index=require('src.core.StateStack')}),
  input={wasPressed=function(_,key)return button==key end}}
 game.stack:init();local world={};game.stack:push(world)
 local yielded,resumed=0,0
 local ctx={game=game,save=save,runner={yield=function()yielded=yielded+1 end,resume=function()resumed=resumed+1 end}}
 local function press(key)local s=game.stack:top();button=key;s:update(1/60);button=nil end
 for default=0,3 do
  local lowered={out={}}
  VM.LOWERING.multichoicedefault({'multichoicedefault',0,0,0,default,0},lowered)
  local row=lowered.out[1];Commands[row[1]](ctx,unpack(row,2))
  local menu=game.stack:top();T.eq(getmetatable(menu),Menu)
  T.eq(menu.index,default+1,'actual script default reaches the native generic menu')
  T.eq(yielded,resumed+1)
  press('a');T.eq(G.getVar(save,0x800D),default,'selection returns the original zero-based row')
  T.eq(game.stack:top(),world);T.eq(yielded,resumed,'selection resumes exactly once')
 end
 Commands.g3_multichoice(ctx,0,1,1)
 local menu=game.stack:top();T.eq(menu.index,2)
 local before=resumed;press('b')
 T.eq(game.stack:top(),menu,'ignoreB keeps the actual menu alive')
 T.eq(resumed,before,'ignored B neither answers nor strands its script')
 press('a');T.eq(G.getVar(save,0x800D),1);T.eq(yielded,resumed)
 Commands.g3_multichoice(ctx,0,0,2);press('b')
 T.eq(G.getVar(save,0x800D),127,'ordinary B retains the native cancellation answer')
 T.eq(game.stack:top(),world);T.eq(yielded,resumed)
 T.eq(require('src.core.SaveSerializer').encode({save.party,save.inventory,save.flags}),protected,
      'choice input does not edit party, inventory or story flags')
end
T.finish('Emerald and FRLG multichoice defaults and ignore-B survive actual script UI dispatch')
